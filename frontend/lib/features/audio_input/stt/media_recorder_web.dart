// Web implementation of microphone recording via the native MediaRecorder
// API (no platform plugin). Uses package:web's typed MediaRecorder, Blob and
// Stream interop; the captured audio is returned as bytes ready for the Groq
// STT endpoint. Recording can be paused/resumed and reports elapsed time plus a
// coarse amplitude envelope for the composer's waveform.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'media_recorder_engine.dart';
import 'pcm_wav.dart';

MediaRecorderEngine createMediaRecorderEngine() => _WebMediaRecorder();

/// Decode the capture to mono PCM at this rate. 24 kHz is generous for speech
/// transcription and voice cloning, and keeps the WAV upload small.
const int _pcmSampleRate = 24000;

/// How much speech each streamed segment covers. Long enough that the recogniser
/// has real context, short enough that a partial transcript appears while the
/// user is still talking.
const int _chunkIntervalMs = 2500;

/// Peak amplitude below which a captured segment is treated as silence and
/// never sent, so an open microphone does not keep posting empty audio.
const double _chunkSilenceFloor = 0.012;

/// Name the worklet module is registered under. Must match the
/// `registerProcessor` call in the worklet source.
const String _workletProcessorName = 'pcm-tap';

/// Asset path of the worklet module. It is declared in `pubspec.yaml` so the
/// file is copied verbatim into the web build root, where the browser can fetch
/// it over HTTP. The cache-busting query is deliberate: a stale cached module
/// after a deploy would silently keep the old processor registered.
const String _workletUrl = 'assets/worklets/pcm_tap_worklet.js?v=1';

class _WebMediaRecorder implements ChunkedRecorderEngine {
  _WebMediaRecorder();

  web.MediaStream? _stream;
  web.MediaRecorder? _recorder;
  final List<web.Blob> _chunks = [];
  final List<int> _levels = <int>[];
  Completer<RecordedAudio>? _done;
  String _mimeType = 'audio/webm';
  bool _recording = false;
  bool _paused = false;
  int _capturedMs = 0;
  DateTime? _segmentStart;
  Timer? _clock;
  web.AudioContext? _audio;
  web.AudioNode? _source;
  web.AnalyserNode? _analyser;
  int _level = 0;

  void Function(RecordedAudio chunk)? _onChunk;
  final List<Float32List> _pcm = <Float32List>[];
  int _pcmSamples = 0;
  web.AudioWorkletNode? _tap;
  web.AudioNode? _tapSource;
  web.GainNode? _tapSink;
  JSFunction? _tapMessageHandler;

  @override
  set onChunk(void Function(RecordedAudio chunk)? listener) => _onChunk = listener;

  @override
  int get chunkIntervalMs => _chunkIntervalMs;

  @override
  bool get supported => web.window.getProperty<JSAny?>('MediaRecorder'.toJS) != null;

  @override
  bool get recording => _recording;

  @override
  bool get paused => _paused;

  @override
  int get elapsedMs => _capturedMs + _currentSegmentMs;

  @override
  int get level => _level;

  int get _currentSegmentMs {
    final start = _segmentStart;
    return start == null ? 0 : DateTime.now().difference(start).inMilliseconds;
  }

  @override
  Future<void> start() async {
    final stream = await _getMicStream();
    if (stream == null) {
      _recording = false;
      throw StateError('Microphone access was denied or unavailable.');
    }
    final recorder = _createRecorder(stream);
    if (recorder == null) {
      _stopTracks(stream);
      _recording = false;
      throw StateError('MediaRecorder is not supported in this browser.');
    }
    _stream = stream;
    _recorder = recorder;
    _chunks.clear();
    _levels.clear();
    _pcm.clear();
    _pcmSamples = 0;
    _capturedMs = 0;
    _level = 0;
    _paused = false;
    _segmentStart = DateTime.now();
    _startMeter(stream);
    _clock = Timer.periodic(const Duration(milliseconds: 120), (_) => _sampleLevel());
    _recording = true;
  }

  @override
  void pause() {
    if (!_recording || _paused) return;
    _paused = true;
    _capturedMs += _currentSegmentMs;
    _segmentStart = null;
    // Both the PCM tap and the browser's own recorder are held, so the stream
    // stays open (and its level metering keeps flowing for barge-in) while the
    // time base excludes the span. [stop] still flushes whatever was captured.
    _setRecorderPaused(true);
  }

  @override
  void resume() {
    if (!_recording || !_paused) return;
    _paused = false;
    _segmentStart = DateTime.now();
    _setRecorderPaused(false);
  }

  void _setRecorderPaused(bool value) {
    final recorder = _recorder;
    if (recorder == null) return;
    try {
      if (value) {
        recorder.pause();
      } else {
        recorder.resume();
      }
    } catch (_) {
      // Some browsers lack pause(); the time base above still excludes it.
    }
  }

  @override
  Future<RecordedAudio> stop() async {
    final recorder = _recorder;
    _recording = false;
    _stopClock();
    if (!_paused) {
      _capturedMs += _currentSegmentMs;
    }
    _segmentStart = null;
    // Hand over the tail of the utterance too, so the live caption covers
    // everything the user actually said before the authoritative pass runs.
    _flushChunk();
    if (recorder == null) {
      return _emptyAudio();
    }
    final done = Completer<RecordedAudio>();
    _done = done;
    try {
      if (_paused && recorder.state == 'paused') {
        recorder.resume();
      }
      recorder.stop();
    } catch (_) {
      done.complete(_emptyAudio());
    }
    final audio = await done.future;
    _teardown();
    return audio;
  }

  @override
  void cancel() {
    final recorder = _recorder;
    _recorder = null;
    final done = _done;
    _done = null;
    _recording = false;
    _paused = false;
    _stopClock();
    _dropChunkBuffer();
    if (done != null && !done.isCompleted) {
      done.complete(const RecordedAudio(bytes: [], mimeType: ''));
    }
    try {
      recorder?.stop();
    } catch (_) {
      // Best effort.
    }
    _stopTracks(_stream);
    _stream = null;
  }

  void _teardown() {
    _stopClock();
    _stopMeter();
    _dropChunkBuffer();
    final stream = _stream;
    _stream = null;
    _recorder = null;
    _done = null;
    _paused = false;
    if (stream != null) {
      _stopTracks(stream);
    }
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  /// Releases the live-partial tap and forgets any audio not yet handed over.
  void _dropChunkBuffer() {
    _stopChunkTap();
    _pcm.clear();
    _pcmSamples = 0;
  }

  RecordedAudio _emptyAudio() => RecordedAudio(bytes: const <int>[], mimeType: _mimeType);

  // --------------------------------------------------------- level metering

  void _startMeter(web.MediaStream stream) {
    try {
      final context = web.AudioContext(web.AudioContextOptions(sampleRate: _pcmSampleRate));
      final source = context.createMediaStreamSource(stream);
      final analyser = context.createAnalyser();
      analyser.fftSize = 256;
      source.connect(analyser);
      _audio = context;
      _source = source;
      _analyser = analyser;
      // A context created outside the user gesture can start suspended, and a
      // suspended context produces no levels at all - the VAD would then never
      // see speech even though the recorder is running. Resuming here is safe
      // because every capture starts from a user tap.
      unawaited(context.resume().toDart);
      // Registering the worklet module is asynchronous (a network fetch), and
      // `start()` must not block on it: the recorder and the level meter are
      // already live, and a slow module load would otherwise delay the first
      // syllable. Missing it only costs live partials, not the finished clip.
      unawaited(_startChunkTap(context, stream));
    } catch (_) {
      // Level metering is a nicety; recording works without it.
      _audio = null;
      _analyser = null;
    }
  }

  /// Taps decoded PCM so audio can be handed over *while* the user is still
  /// speaking.
  ///
  /// MediaRecorder only produces self-contained WebM once the take ends, so it
  /// cannot drive incremental transcription. The tap is an `AudioWorkletNode`:
  /// the worklet runs on the audio rendering thread and posts each block to the
  /// UI, which is what the deprecation of `ScriptProcessorNode` (main-thread, and
  /// not reliably pulled by the graph) requires.
  ///
  /// The module is loaded once per process and the promise is reused, because
  /// `addModule` is a network fetch and re-fetching it per recording would add
  /// latency to the first syllable of every take. It is wired through a muted
  /// gain node because the graph is only pulled while a node reaches the
  /// destination, and a microphone must never reach the speakers.
  Future<void> _startChunkTap(web.AudioContext context, web.MediaStream stream) async {
    try {
      await _ensureWorkletLoaded(context);
      final tap = web.AudioWorkletNode(context, _workletProcessorName);
      final sink = context.createGain();
      sink.gain.value = 0;
      final source = context.createMediaStreamSource(stream);
      source.connect(tap);
      tap.connect(sink);
      sink.connect(context.destination);

      final port = tap.port;
      final handler = ((web.MessageEvent event) {
        final data = event.data;
        if (data != null && data.isA<JSFloat32Array>()) {
          _handleAudioBlock((data as JSFloat32Array).toDart);
        }
      }).toJS;
      _tapMessageHandler = handler;
      port.addEventListener('message', handler);

      _tap = tap;
      _tapSource = source;
      _tapSink = sink;
    } catch (_) {
      // Live partials are an enhancement; the finished clip still works.
      _tap = null;
      _tapSource = null;
      _tapSink = null;
    }
  }

  /// Registers the worklet module once, reusing the promise across recordings.
  static Future<void>? _workletLoad;

  static Future<void> _ensureWorkletLoaded(web.AudioContext context) {
    return _workletLoad ??= context.audioWorklet.addModule(_workletUrl).toDart.then((JSAny? _) {}).catchError((
      Object _,
    ) {
      // A failed load must not poison the cached promise, or every later
      // recording would inherit the failure without retrying.
      _workletLoad = null;
    });
  }

  int get _chunkSampleBudget => _pcmSampleRate * _chunkIntervalMs ~/ 1000;

  /// Receives one mono PCM block from the worklet.
  ///
  /// Blocks are 128 frames and arrive every ~2.7 ms at 48 kHz, so they are
  /// accumulated until a full speech segment is worth sending. Worklet blocks
  /// arrive on the UI thread already detached from the audio thread, so unlike
  /// the old `onaudioprocess` view they do not need copying again.
  void _handleAudioBlock(Float32List block) {
    if (!_recording || _paused || _onChunk == null || block.isEmpty) {
      return;
    }
    _pcm.add(block);
    _pcmSamples += block.length;
    if (_pcmSamples >= _chunkSampleBudget) {
      _flushChunk();
    }
  }

  /// Emits everything captured so far as one segment, keeping any remainder for
  /// the next one. Silent stretches are dropped rather than sent, so an open
  /// microphone does not keep posting empty audio.
  void _flushChunk() {
    final listener = _onChunk;
    if (listener == null || _pcm.isEmpty) {
      return;
    }
    final mono = downmixToMono(List<Float32List>.of(_pcm));
    if (mono.isEmpty) {
      _pcm.clear();
      _pcmSamples = 0;
      return;
    }
    _pcm
      ..clear()
      ..add(mono);
    _pcmSamples = mono.length;
    if (_peak(mono) < _chunkSilenceFloor) {
      return;
    }
    listener(
      RecordedAudio(
        bytes: encodePcm16Wav(PcmAudio(samples: mono, sampleRate: _pcmSampleRate)),
        mimeType: 'audio/wav',
        durationMs: PcmAudio(samples: mono, sampleRate: _pcmSampleRate).durationMs,
      ),
    );
  }

  static double _peak(Float32List samples) {
    var peak = 0.0;
    for (final value in samples) {
      final magnitude = value.abs();
      if (magnitude > peak) {
        peak = magnitude;
      }
    }
    return peak;
  }

  void _stopChunkTap() {
    final tap = _tap;
    final handler = _tapMessageHandler;
    if (tap != null) {
      try {
        // Drop the listener before disconnecting so a block that is already in
        // flight cannot append samples to a buffer nobody will read.
        if (handler != null) {
          tap.port.removeEventListener('message', handler);
        }
        // Ask the processor to stop returning true from process(); without
        // this the node keeps rendering silence on the audio thread for as long
        // as it stays connected.
        tap.port.postMessage('stop'.toJS);
        tap.disconnect();
      } catch (_) {
        // Best effort.
      }
    }
    try {
      _tapSource?.disconnect();
      _tapSink?.disconnect();
    } catch (_) {
      // Best effort.
    }
    _tap = null;
    _tapMessageHandler = null;
    _tapSource = null;
    _tapSink = null;
  }

  void _sampleLevel() {
    final analyser = _analyser;
    if (analyser == null) return;
    try {
      final buffer = Float32List(analyser.fftSize);
      analyser.getFloatTimeDomainData(buffer.toJS);
      var sumSquares = 0.0;
      for (final value in buffer) {
        sumSquares += value * value;
      }
      final rms = math.sqrt(sumSquares / buffer.length);
      // Map the root-mean-square *amplitude* of the waveform to 0..100 on a
      // dBFS scale (see [meterLevelForRms]). `getFloatFrequencyData` returns
      // values that are already in dB and negative, so averaging their
      // magnitudes and taking another logarithm clamps to a constant and pins
      // the meter at 100 - which makes the voice-activity detector believe the
      // user is permanently speaking, so no turn ever ends. Reading the time
      // domain avoids that entirely.
      final scaled = meterLevelForRms(rms);
      _level = scaled;
      if (!_paused) {
        _levels.add(scaled);
      }
    } catch (_) {
      // Ignore metering failures; the elapsed timer is authoritative.
    }
  }

  void _stopMeter() {
    try {
      _stopChunkTap();
      _source?.disconnect();
      _audio?.close();
    } catch (_) {
      // Best effort.
    }
    _source = null;
    _analyser = null;
    _audio = null;
    _level = 0;
  }

  void _stopTracks(web.MediaStream? stream) {
    final tracks = stream?.getTracks();
    if (tracks == null) {
      return;
    }
    for (var i = 0; i < tracks.length; i++) {
      tracks[i].stop();
    }
  }

  /// Constraints requested for the microphone.
  ///
  /// These are not cosmetic. A hands-free conversation plays the assistant's own
  /// audio while the microphone is open, so without echo cancellation the
  /// assistant transcribes itself as the user; without noise suppression and
  /// automatic gain control, room noise is loud enough to trip the voice-activity
  /// detector and send silence to speech-to-text.
  /// The `audio` half of the constraints requested for the microphone.
  JSAny get _micConstraints => (<String, Object>{
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'channelCount': 1,
      }.jsify() as JSAny);

  Future<web.MediaStream?> _getMicStream() async {
    if (!supported) {
      return null;
    }
    try {
      return await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: _micConstraints, video: false.toJS))
          .toDart;
    } catch (_) {
      return null;
    }
  }

  web.MediaRecorder? _createRecorder(web.MediaStream stream) {
    if (!supported) {
      return null;
    }
    try {
      final recorder = web.MediaRecorder(stream, web.MediaRecorderOptions(mimeType: 'audio/webm'));
      final requested = recorder.mimeType;
      if (requested.isNotEmpty) {
        _mimeType = requested;
      }
      recorder.ondataavailable = _handleData.toJS;
      recorder.onstop = _handleStop.toJS;
      recorder.onerror = _handleError.toJS;
      recorder.start(500);
      return recorder;
    } catch (_) {
      return null;
    }
  }

  void _handleData(JSAny? event) {
    final data = (event as web.BlobEvent?)?.data;
    if (data != null && data.size > 0) {
      _chunks.add(data);
    }
  }

  void _handleError(JSAny? event) {
    final error = _errorName(event);
    final done = _done;
    if (done != null && !done.isCompleted) {
      done.completeError(StateError('Recorder failed: $error'));
    }
  }

  void _handleStop(JSAny? _) async {
    final done = _done;
    if (done == null || done.isCompleted) {
      return;
    }
    try {
      final bytes = <int>[];
      for (final chunk in _chunks) {
        final buffer = (await chunk.arrayBuffer().toDart).toDart;
        bytes.addAll(buffer.asUint8List());
      }
      done.complete(await _toTrainableAudio(bytes));
    } catch (_) {
      done.complete(_emptyAudio());
    }
  }

  /// Re-wraps a MediaRecorder capture as WAV.
  ///
  /// MediaRecorder can only emit WebM/Opus, which the training path cannot
  /// decode, so such a sample has no measurable length and OpenVoice rejects it.
  /// The browser's own decoder is the only one available here, so the capture is
  /// decoded to PCM and re-wrapped; that also makes [RecordedAudio.durationMs]
  /// describe the decoded audio exactly. Falls back to the raw bytes when the
  /// platform cannot decode them, so transcription still has something to send.
  Future<RecordedAudio> _toTrainableAudio(List<int> raw) async {
    final encoded = Uint8List.fromList(raw);
    final waveform = buildWaveformBars(_levels);
    final fallback = RecordedAudio(bytes: encoded, mimeType: _mimeType, durationMs: _capturedMs, waveform: waveform);
    if (raw.isEmpty) {
      return fallback;
    }
    web.AudioContext? context;
    try {
      context = web.AudioContext(web.AudioContextOptions(sampleRate: _pcmSampleRate));
      final buffer = await context.decodeAudioData(encoded.buffer.toJS).toDart;
      final channels = <Float32List>[for (var c = 0; c < buffer.numberOfChannels; c++) buffer.getChannelData(c).toDart];
      final mono = downmixToMono(channels);
      if (mono.isEmpty) {
        return fallback;
      }
      final pcm = PcmAudio(samples: mono, sampleRate: buffer.sampleRate.toInt());
      return RecordedAudio(
        bytes: encodePcm16Wav(pcm),
        mimeType: 'audio/wav',
        durationMs: pcm.durationMs,
        waveform: waveform,
      );
    } catch (_) {
      return fallback;
    } finally {
      _closeQuietly(context);
    }
  }

  void _closeQuietly(web.AudioContext? context) {
    try {
      final state = context?.state;
      // A running context holds a hardware output stream; only a suspended or
      // closed one can be released, and only closing is needed here.
      if (state != null && state != 'closed' && state != 'running') {
        context?.close();
      }
    } catch (_) {
      // Best effort.
    }
  }

  String _errorName(JSAny? event) {
    if (event == null) {
      return 'unknown';
    }
    final error = (event as JSObject)['error'] as JSObject?;
    if (error == null) {
      return 'unknown';
    }
    return (error['name'] as JSString?)?.toDart ?? 'unknown';
  }
}
