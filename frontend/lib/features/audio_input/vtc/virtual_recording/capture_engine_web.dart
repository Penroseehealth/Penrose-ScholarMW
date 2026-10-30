// Web implementation of the virtual capture engine.
//
// Everything reported here is read back from the browser: sources come from
// getUserMedia/getDisplayMedia, levels from real AnalyserNodes, the container
// from MediaRecorder.isTypeSupported/MediaRecorder.mimeType, and a capture is
// only handed back after the browser can decode its own bytes.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'capture_engine_types.dart';

const List<MediaFormat> _audioCandidates = <MediaFormat>[
  MediaFormat(mimeType: 'audio/webm;codecs=opus', extension: 'webm', label: 'WebM (Opus)', video: false),
  MediaFormat(mimeType: 'audio/webm', extension: 'webm', label: 'WebM', video: false),
  MediaFormat(mimeType: 'audio/ogg;codecs=opus', extension: 'ogg', label: 'Ogg (Opus)', video: false),
  MediaFormat(mimeType: 'audio/mp4', extension: 'm4a', label: 'MP4 (AAC)', video: false),
  MediaFormat(mimeType: 'audio/mpeg', extension: 'mp3', label: 'MP3', video: false),
];

const List<MediaFormat> _videoCandidates = <MediaFormat>[
  MediaFormat(mimeType: 'video/webm;codecs=vp9,opus', extension: 'webm', label: 'WebM (VP9)', video: true),
  MediaFormat(mimeType: 'video/webm;codecs=vp8,opus', extension: 'webm', label: 'WebM (VP8)', video: true),
  MediaFormat(mimeType: 'video/webm', extension: 'webm', label: 'WebM', video: true),
  MediaFormat(mimeType: 'video/mp4;codecs=avc1.42E01E,mp4a.40.2', extension: 'mp4', label: 'MP4 (H.264)', video: true),
  MediaFormat(mimeType: 'video/mp4', extension: 'mp4', label: 'MP4', video: true),
  MediaFormat(mimeType: 'video/quicktime', extension: 'mov', label: 'QuickTime', video: true),
];

int _engineSequence = 0;

class _WebVirtualCaptureEngine implements VirtualCaptureEngine {
  _WebVirtualCaptureEngine() {
    final int id = _engineSequence++;
    _screenViewType = 'vtc-virtual-screen-$id';
    _cameraViewType = 'vtc-virtual-camera-$id';
    ui_web.platformViewRegistry.registerViewFactory(_screenViewType, (int viewId) {
      final element = _newPreviewElement();
      _screenViews[viewId] = element;
      _applyStream(element, _screenStream);
      return element;
    });
    ui_web.platformViewRegistry.registerViewFactory(_cameraViewType, (int viewId) {
      final element = _newPreviewElement();
      _cameraViews[viewId] = element;
      _applyStream(element, _cameraStream);
      return element;
    });
  }

  final Map<int, web.HTMLVideoElement> _screenViews = <int, web.HTMLVideoElement>{};
  final Map<int, web.HTMLVideoElement> _cameraViews = <int, web.HTMLVideoElement>{};

  late final String _screenViewType;
  late final String _cameraViewType;

  web.MediaStream? _micStream;
  web.MediaStream? _cameraStream;
  web.MediaStream? _screenStream;

  web.AudioContext? _context;
  web.MediaStreamAudioDestinationNode? _mix;
  web.AnalyserNode? _micAnalyser;
  web.AnalyserNode? _systemAnalyser;
  web.MediaStreamAudioSourceNode? _micNode;
  web.MediaStreamAudioSourceNode? _systemNode;
  JSFloat32Array? _micBuffer;
  JSFloat32Array? _systemBuffer;

  web.MediaRecorder? _recorder;
  web.MediaRecorder? _speechRecorder;
  List<web.Blob> _chunks = <web.Blob>[];
  List<web.Blob> _speechChunks = <web.Blob>[];

  bool _micEnabled = false;
  bool _micLive = false;
  bool _micMuted = false;
  bool _cameraEnabled = false;
  bool _cameraLive = false;
  bool _screenActive = false;
  bool _screenLive = false;
  bool _screenHasAudio = false;
  String? _screenLabel;
  int _screenWidth = 0;
  int _screenHeight = 0;

  bool _recording = false;
  bool _paused = false;
  bool _recordingHasVideo = false;
  int _bytes = 0;
  MediaFormat? _activeFormat;
  MediaFormat? _speechFormat;
  String? _recorderError;

  void Function()? _screenEndedCallback;

  // -- capabilities ---------------------------------------------------------

  bool get _hasMediaDevices {
    try {
      return web.window.navigator.has('mediaDevices') && !web.window.navigator.mediaDevices.isUndefinedOrNull;
    } catch (_) {
      return false;
    }
  }

  bool get _hasRecorder {
    try {
      return web.window.has('MediaRecorder');
    } catch (_) {
      return false;
    }
  }

  bool _hasMethod(String name) {
    if (!_hasMediaDevices) return false;
    try {
      return web.window.navigator.mediaDevices.has(name);
    } catch (_) {
      return false;
    }
  }

  bool _supportedType(String mime) {
    try {
      return web.MediaRecorder.isTypeSupported(mime);
    } catch (_) {
      return false;
    }
  }

  @override
  bool get supported => _hasMediaDevices && _hasRecorder;

  @override
  CaptureCapabilities get capabilities {
    if (!supported) return const CaptureCapabilities.unsupported();
    return CaptureCapabilities(
      supported: true,
      screen: _hasMethod('getDisplayMedia'),
      microphone: _hasMethod('getUserMedia'),
      camera: _hasMethod('getUserMedia'),
      audioFormats: _audioCandidates
          .where((MediaFormat format) => _supportedType(format.mimeType))
          .map((MediaFormat format) => format.mimeType)
          .toList(growable: false),
      videoFormats: _videoCandidates
          .where((MediaFormat format) => _supportedType(format.mimeType))
          .map((MediaFormat format) => format.mimeType)
          .toList(growable: false),
    );
  }

  // -- source state ---------------------------------------------------------

  @override
  bool get microphoneEnabled => _micEnabled;

  @override
  bool get microphoneLive => _micLive;

  @override
  bool get microphoneMuted => _micMuted;

  @override
  bool get cameraEnabled => _cameraEnabled;

  @override
  bool get cameraLive => _cameraLive;

  @override
  bool get screenActive => _screenActive;

  @override
  bool get screenLive => _screenLive;

  @override
  bool get screenHasAudio => _screenHasAudio;

  @override
  String? get screenLabel => _screenLabel;

  @override
  int get screenWidth => _screenWidth;

  @override
  int get screenHeight => _screenHeight;

  @override
  bool get recording => _recording;

  @override
  bool get paused => _paused;

  @override
  int get bytesRecorded => _bytes;

  @override
  MediaFormat? get activeFormat => _activeFormat;

  // -- devices --------------------------------------------------------------

  @override
  Future<List<CaptureDevice>> microphones() => _devices('audioinput', 'Microphone');

  @override
  Future<List<CaptureDevice>> cameras() => _devices('videoinput', 'Camera');

  Future<List<CaptureDevice>> _devices(String kind, String fallback) async {
    if (!supported) return const <CaptureDevice>[];
    try {
      final JSArray<web.MediaDeviceInfo> raw = await web.window.navigator.mediaDevices.enumerateDevices().toDart;
      final List<CaptureDevice> result = <CaptureDevice>[];
      var index = 1;
      for (final web.MediaDeviceInfo device in raw.toDart) {
        if (device.kind != kind) continue;
        final String label = device.label.trim();
        result.add(
          CaptureDevice(
            id: device.deviceId,
            label: label.isEmpty ? '$fallback $index' : label,
          ),
        );
        index++;
      }
      return result;
    } catch (_) {
      return const <CaptureDevice>[];
    }
  }

  // -- microphone -----------------------------------------------------------

  @override
  Future<void> startMicrophone({String? deviceId}) async {
    if (!_hasMethod('getUserMedia')) {
      throw const CaptureFailure('This browser cannot use a microphone.', unsupported: true);
    }
    await stopMicrophone();
    final Map<String, Object?> audio = <String, Object?>{
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    };
    if (deviceId != null && deviceId.isNotEmpty) {
      audio['deviceId'] = <String, Object?>{'exact': deviceId};
    }
    final web.MediaStream stream;
    try {
      stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: audio.jsify() as JSAny,
              video: false.toJS,
            ),
          )
          .toDart;
    } catch (error) {
      throw _failure(error, 'Using the microphone');
    }
    final List<web.MediaStreamTrack> tracks = stream.getAudioTracks().toDart;
    if (tracks.isEmpty) {
      _stopStream(stream);
      throw const CaptureFailure('The microphone returned no audio track.', deviceLost: true);
    }
    _micStream = stream;
    _micEnabled = true;
    _micLive = true;
    _micMuted = false;
    for (final web.MediaStreamTrack track in tracks) {
      track.onended = ((web.Event event) => _handleMicrophoneEnded()).toJS;
    }
    await _ensureAudioGraph();
    _attachMicrophoneAudio();
  }

  @override
  Future<void> stopMicrophone() async {
    _micEnabled = false;
    _micLive = false;
    _micMuted = false;
    _detachMicrophoneAudio();
    final web.MediaStream? stream = _micStream;
    _micStream = null;
    if (stream != null) _stopStream(stream);
  }

  @override
  void setMicrophoneMuted(bool muted) {
    _micMuted = muted;
    final web.MediaStream? stream = _micStream;
    if (stream == null) return;
    for (final web.MediaStreamTrack track in stream.getAudioTracks().toDart) {
      try {
        track.enabled = !muted;
      } catch (_) {
        // A track that already ended stays disabled.
      }
    }
  }

  void _handleMicrophoneEnded() {
    if (!_micLive) return;
    _micLive = false;
    _micEnabled = false;
    _detachMicrophoneAudio();
    final web.MediaStream? stream = _micStream;
    _micStream = null;
    if (stream != null) _stopStream(stream);
  }

  // -- camera ---------------------------------------------------------------

  @override
  Future<void> startCamera({String? deviceId}) async {
    if (!_hasMethod('getUserMedia')) {
      throw const CaptureFailure('This browser cannot use a camera.', unsupported: true);
    }
    await stopCamera();
    final Map<String, Object?> video = <String, Object?>{
      'width': <String, int>{'ideal': 1280},
      'height': <String, int>{'ideal': 720},
      'frameRate': <String, int>{'ideal': 30},
    };
    if (deviceId != null && deviceId.isNotEmpty) {
      video['deviceId'] = <String, Object?>{'exact': deviceId};
    }
    final web.MediaStream stream;
    try {
      stream = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: video.jsify() as JSAny,
              audio: false.toJS,
            ),
          )
          .toDart;
    } catch (error) {
      throw _failure(error, 'Using the camera');
    }
    if (stream.getVideoTracks().toDart.isEmpty) {
      _stopStream(stream);
      throw const CaptureFailure('The camera returned no video track.', deviceLost: true);
    }
    _cameraStream = stream;
    _cameraEnabled = true;
    _cameraLive = true;
    for (final web.MediaStreamTrack track in stream.getTracks().toDart) {
      track.onended = ((web.Event event) => _handleCameraEnded()).toJS;
    }
    _applyStreams(_cameraViews, stream);
  }

  @override
  Future<void> stopCamera() async {
    _cameraEnabled = false;
    _cameraLive = false;
    final web.MediaStream? stream = _cameraStream;
    _cameraStream = null;
    if (stream != null) _stopStream(stream);
    _applyStreams(_cameraViews, null);
  }

  void _handleCameraEnded() {
    if (!_cameraLive) return;
    _cameraLive = false;
    _cameraEnabled = false;
    final web.MediaStream? stream = _cameraStream;
    _cameraStream = null;
    if (stream != null) _stopStream(stream);
    _applyStreams(_cameraViews, null);
  }

  // -- screen share ---------------------------------------------------------

  @override
  Future<ScreenShareInfo> startScreenShare() async {
    if (!_hasMethod('getDisplayMedia')) {
      throw const CaptureFailure('This browser cannot share a screen or tab.', unsupported: true);
    }
    await stopScreenShare();
    final web.MediaStream stream;
    try {
      stream = await web.window.navigator.mediaDevices
          .getDisplayMedia(
            web.DisplayMediaStreamOptions(
              video: true.toJS,
              audio: true.toJS,
              selfBrowserSurface: 'exclude',
              systemAudio: 'include',
            ),
          )
          .toDart;
    } catch (error) {
      throw _failure(error, 'Sharing the screen');
    }
    final List<web.MediaStreamTrack> videoTracks = stream.getVideoTracks().toDart;
    if (videoTracks.isEmpty) {
      _stopStream(stream);
      throw const CaptureFailure('The picker returned no video track.', deviceLost: true);
    }
    final web.MediaStreamTrack track = videoTracks.first;
    _screenStream = stream;
    _screenActive = true;
    _screenLive = true;
    _screenHasAudio = stream.getAudioTracks().toDart.isNotEmpty;
    final String label = track.label.trim();
    _screenLabel = label.isEmpty ? 'Shared screen' : label;
    _screenWidth = _trackInt(track, 'width');
    _screenHeight = _trackInt(track, 'height');
    _applyStreams(_screenViews, stream);
    await _ensureAudioGraph();
    _attachSystemAudio(stream);
    try {
      track.onended = ((web.Event event) => _handleScreenEnded()).toJS;
    } catch (_) {
      // Some browsers do not expose onended on display tracks.
    }
    return ScreenShareInfo(
      label: _screenLabel ?? 'Shared screen',
      hasAudio: _screenHasAudio,
      width: _screenWidth,
      height: _screenHeight,
    );
  }

  @override
  Future<void> stopScreenShare() async {
    _screenActive = false;
    _screenLive = false;
    _screenHasAudio = false;
    _detachSystemAudio();
    final web.MediaStream? stream = _screenStream;
    _screenStream = null;
    if (stream != null) _stopStream(stream);
    _applyStreams(_screenViews, null);
  }

  void _handleScreenEnded() {
    if (!_screenActive) return;
    _screenActive = false;
    _screenLive = false;
    _screenHasAudio = false;
    _detachSystemAudio();
    final web.MediaStream? stream = _screenStream;
    _screenStream = null;
    if (stream != null) _stopStream(stream);
    _applyStreams(_screenViews, null);
    _screenEndedCallback?.call();
  }

  int _trackInt(web.MediaStreamTrack track, String key) {
    try {
      final web.MediaTrackSettings settings = track.getSettings();
      if (!settings.has(key)) return 0;
      final JSAny? value = settings.getProperty<JSAny?>(key.toJS);
      if (value == null) return 0;
      final Object? plain = value.dartify();
      return plain is num ? plain.toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  // -- preview --------------------------------------------------------------

  web.HTMLVideoElement _newPreviewElement() => web.HTMLVideoElement()
    ..autoplay = true
    ..muted = true
    ..playsInline = true
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'contain'
    ..style.backgroundColor = '#050B20';

  void _applyStream(web.HTMLVideoElement element, web.MediaStream? stream) {
    try {
      element.srcObject = stream;
      if (stream == null) {
        element.pause();
      } else {
        element.play().toDart.catchError((Object _) => null);
      }
    } catch (_) {
      // A preview element that was already removed cannot be updated.
    }
  }

  void _applyStreams(Map<int, web.HTMLVideoElement> views, web.MediaStream? stream) {
    for (final web.HTMLVideoElement element in views.values) {
      _applyStream(element, stream);
    }
  }

  @override
  Widget preview(CapturePreview kind) => HtmlElementView(
        viewType: kind == CapturePreview.screen ? _screenViewType : _cameraViewType,
      );

  // -- metering -------------------------------------------------------------

  Future<void> _ensureAudioGraph() async {
    if (!supported) return;
    if (_context == null) {
      final web.AudioContext context = web.AudioContext();
      _context = context;
      final web.MediaStreamAudioDestinationNode mix = context.createMediaStreamDestination();
      _mix = mix;
      final web.AnalyserNode mic = _configuredAnalyser(context);
      mic.connect(mix);
      _micAnalyser = mic;
      final web.AnalyserNode system = _configuredAnalyser(context);
      system.connect(mix);
      _systemAnalyser = system;
      _micBuffer = JSFloat32Array.withLength(mic.fftSize);
      _systemBuffer = JSFloat32Array.withLength(system.fftSize);
    }
    try {
      if (_context?.state == 'suspended') {
        await _context?.resume().toDart;
      }
    } catch (_) {
      // Metering still works from the analyser once the graph is running.
    }
  }

  web.AnalyserNode _configuredAnalyser(web.AudioContext context) {
    final web.AnalyserNode analyser = context.createAnalyser();
    analyser.fftSize = 1024;
    analyser.smoothingTimeConstant = 0.7;
    return analyser;
  }

  void _attachMicrophoneAudio() {
    final web.AudioContext? context = _context;
    final web.AnalyserNode? analyser = _micAnalyser;
    final web.MediaStream? stream = _micStream;
    if (context == null || analyser == null || stream == null) return;
    try {
      _micNode?.disconnect();
    } catch (_) {
      // Already disconnected.
    }
    try {
      final web.MediaStreamAudioSourceNode node = context.createMediaStreamSource(stream);
      node.connect(analyser);
      _micNode = node;
    } catch (_) {
      _micNode = null;
    }
  }

  void _detachMicrophoneAudio() {
    try {
      _micNode?.disconnect();
    } catch (_) {
      // Already disconnected.
    }
    _micNode = null;
  }

  void _attachSystemAudio(web.MediaStream stream) {
    final web.AudioContext? context = _context;
    final web.AnalyserNode? analyser = _systemAnalyser;
    if (context == null || analyser == null) return;
    if (stream.getAudioTracks().toDart.isEmpty) return;
    try {
      _systemNode?.disconnect();
    } catch (_) {
      // Already disconnected.
    }
    try {
      final web.MediaStreamAudioSourceNode node = context.createMediaStreamSource(stream);
      node.connect(analyser);
      _systemNode = node;
    } catch (_) {
      _systemNode = null;
    }
  }

  void _detachSystemAudio() {
    try {
      _systemNode?.disconnect();
    } catch (_) {
      // Already disconnected.
    }
    _systemNode = null;
  }

  @override
  double readMicrophoneLevel() => _level(_micAnalyser, _micBuffer);

  @override
  double readSystemLevel() => _level(_systemAnalyser, _systemBuffer);

  double _level(web.AnalyserNode? analyser, JSFloat32Array? buffer) {
    if (analyser == null || buffer == null) return 0;
    try {
      analyser.getFloatTimeDomainData(buffer);
      final Float32List samples = buffer.toDart;
      if (samples.isEmpty) return 0;
      var sum = 0.0;
      for (final double sample in samples) {
        sum += sample * sample;
      }
      final double rms = math.sqrt(sum / samples.length);
      return (rms * 4).clamp(0.0, 1.0);
    } catch (_) {
      return 0;
    }
  }

  // -- recording ------------------------------------------------------------

  MediaFormat _pickFormat({required bool video}) {
    for (final MediaFormat format in video ? _videoCandidates : _audioCandidates) {
      if (_supportedType(format.mimeType)) return format;
    }
    throw CaptureFailure(
      video ? 'This browser cannot record video.' : 'This browser cannot record audio.',
      unsupported: true,
    );
  }

  MediaFormat? _pickSpeechFormat() {
    for (final MediaFormat format in _audioCandidates) {
      if (_supportedType(format.mimeType)) return format;
    }
    return null;
  }

  @override
  Future<void> startRecording({required bool includeVideo}) async {
    if (_recording) {
      throw const CaptureFailure('A recording is already running.');
    }
    final MediaFormat format = _pickFormat(video: includeVideo);
    web.MediaStreamTrack? videoTrack;
    if (includeVideo) {
      videoTrack = _screenStream?.getVideoTracks().toDart.firstOrNull;
      videoTrack ??= _cameraStream?.getVideoTracks().toDart.firstOrNull;
      if (videoTrack == null) {
        throw const CaptureFailure('Turn on the screen or camera before recording video.');
      }
    }
    final bool hasAudio = _micLive || (_screenStream?.getAudioTracks().toDart.isNotEmpty ?? false);
    JSAny? audioTrack;
    if (hasAudio) {
      await _ensureAudioGraph();
      audioTrack = _mix?.stream.getAudioTracks().toDart.firstOrNull;
    }
    final List<JSAny> tracks = <JSAny>[
      if (videoTrack != null) videoTrack,
      if (audioTrack != null) audioTrack,
    ];
    if (tracks.isEmpty) {
      throw const CaptureFailure('Choose a microphone, screen or camera before recording.');
    }
    final web.MediaStream stream = web.MediaStream(tracks.toJS);
    final web.MediaRecorder recorder;
    try {
      recorder = web.MediaRecorder(
        stream,
        web.MediaRecorderOptions(
          mimeType: format.mimeType,
          audioBitsPerSecond: hasAudio ? 128000 : 0,
          videoBitsPerSecond: includeVideo ? 2500000 : 0,
        ),
      );
    } catch (error) {
      throw CaptureFailure('The browser refused to start recording: $error');
    }
    _chunks = <web.Blob>[];
    _speechChunks = <web.Blob>[];
    _bytes = 0;
    _recorderError = null;
    _recordingHasVideo = includeVideo;
    recorder.ondataavailable = ((web.BlobEvent event) {
      if (event.data.size <= 0) return;
      _chunks.add(event.data);
      _bytes += event.data.size;
    }).toJS;
    recorder.onerror = ((web.Event event) {
      _recorderError = 'The browser reported a recording error: ${event.type}';
    }).toJS;
    recorder.start(1000);
    _recorder = recorder;

    _speechFormat = includeVideo ? _pickSpeechFormat() : null;
    final MediaFormat? speechFormat = _speechFormat;
    final web.MediaStreamAudioDestinationNode? mix = _mix;
    if (includeVideo && hasAudio && speechFormat != null && mix != null) {
      try {
        final web.MediaRecorder speech = web.MediaRecorder(
          mix.stream,
          web.MediaRecorderOptions(
            mimeType: speechFormat.mimeType,
            audioBitsPerSecond: 128000,
          ),
        );
        speech.ondataavailable = ((web.BlobEvent event) {
          if (event.data.size <= 0) return;
          _speechChunks.add(event.data);
        }).toJS;
        speech.start(1000);
        _speechRecorder = speech;
      } catch (_) {
        _speechRecorder = null;
      }
    }

    final String actual = recorder.mimeType.trim();
    _activeFormat = actual.isEmpty
        ? format
        : MediaFormat(
            mimeType: actual,
            extension: _extensionFor(actual),
            label: format.label,
            video: includeVideo,
          );
    _recording = true;
    _paused = false;
  }

  @override
  void pauseRecording() {
    if (!_recording || _paused) return;
    try {
      _recorder?.pause();
      _speechRecorder?.pause();
    } catch (_) {
      return;
    }
    _paused = true;
  }

  @override
  void resumeRecording() {
    if (!_recording || !_paused) return;
    try {
      _recorder?.resume();
      _speechRecorder?.resume();
    } catch (_) {
      return;
    }
    _paused = false;
  }

  @override
  Future<RecordedCapture> stopRecording() async {
    final web.MediaRecorder? recorder = _recorder;
    if (recorder == null) {
      throw const CaptureFailure('There is no recording to stop.');
    }
    final web.MediaRecorder? speech = _speechRecorder;
    _recording = false;
    _paused = false;
    await Future.wait(<Future<void>>[
      _stopRecorder(recorder),
      if (speech != null) _stopRecorder(speech),
    ]);
    final String? error = _recorderError;
    if (error != null) {
      _discardBuffers();
      throw CaptureFailure(error);
    }
    final MediaFormat? format = _activeFormat;
    final String mime = format?.mimeType ?? 'audio/webm';
    final Uint8List bytes = await _collect(_chunks, mime);
    Uint8List? audioBytes;
    final MediaFormat? speechFormat = _speechFormat;
    if (_speechChunks.isNotEmpty) {
      audioBytes = await _collect(_speechChunks, speechFormat?.mimeType ?? 'audio/webm');
    }
    final bool hasVideo = _recordingHasVideo;
    await _verifyPlayable(bytes, mime, expectVideo: hasVideo);
    if (audioBytes != null) {
      await _verifyPlayable(audioBytes, speechFormat?.mimeType ?? 'audio/webm', expectVideo: false);
    }
    _recorder = null;
    _speechRecorder = null;
    _discardBuffers();
    return RecordedCapture(
      bytes: bytes,
      mimeType: mime,
      hasVideo: hasVideo,
      duration: Duration.zero,
      audioBytes: audioBytes,
      audioMimeType: audioBytes == null ? null : (speechFormat?.mimeType ?? 'audio/webm'),
    );
  }

  Future<void> _stopRecorder(web.MediaRecorder recorder) {
    final Completer<void> completer = Completer<void>();
    recorder.onstop = ((web.Event event) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    try {
      if (recorder.state == 'inactive') {
        if (!completer.isCompleted) completer.complete();
      } else {
        recorder.stop();
      }
    } catch (error) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        throw const CaptureFailure('The browser did not finish writing the recording.');
      },
    );
  }

  Future<Uint8List> _collect(List<web.Blob> chunks, String mime) async {
    if (chunks.isEmpty) {
      throw const CaptureFailure('The browser produced no data for this recording.');
    }
    final web.Blob blob = web.Blob(
      <JSAny>[...chunks].toJS,
      web.BlobPropertyBag(type: mime),
    );
    final JSArrayBuffer buffer = await blob.arrayBuffer().toDart;
    return Uint8List.fromList(buffer.toDart.asUint8List());
  }

  Future<void> _verifyPlayable(
    Uint8List bytes,
    String mime, {
    required bool expectVideo,
  }) async {
    if (bytes.length < 256) {
      throw const CaptureFailure('The browser produced an empty recording.');
    }
    web.HTMLVideoElement? element;
    String? url;
    try {
      final web.Blob blob = web.Blob(
        <JSAny>[bytes.toJS].toJS,
        web.BlobPropertyBag(type: mime),
      );
      url = web.URL.createObjectURL(blob);
      element = web.HTMLVideoElement()
        ..preload = 'metadata'
        ..muted = true
        ..style.display = 'none';
      web.document.body?.appendChild(element);
      final Completer<void> probe = Completer<void>();
      void done() {
        if (!probe.isCompleted) probe.complete();
      }

      element.onloadedmetadata = ((web.Event event) => done()).toJS;
      element.onloadeddata = ((web.Event event) => done()).toJS;
      element.oncanplay = ((web.Event event) => done()).toJS;
      element.onerror = ((web.Event event) {
        if (!probe.isCompleted) {
          probe.completeError(const CaptureFailure('The browser could not decode the recorded file.'));
        }
      }).toJS;
      element.src = url;
      element.load();
      await probe.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw const CaptureFailure('The recorded file did not load in time.');
        },
      );
      if (expectVideo && element.videoWidth <= 0) {
        throw const CaptureFailure('The recorded video has no picture. Check the shared source and try again.');
      }
      if (!expectVideo && element.readyState < 1) {
        throw const CaptureFailure('The recorded audio could not be decoded.');
      }
    } on CaptureFailure {
      rethrow;
    } catch (error) {
      throw CaptureFailure('The recorded file could not be verified: $error');
    } finally {
      try {
        element?.pause();
        element?.removeAttribute('src');
        element?.load();
        element?.remove();
      } catch (_) {
        // Best effort teardown.
      }
      if (url != null) {
        try {
          web.URL.revokeObjectURL(url);
        } catch (_) {
          // Nothing else to release.
        }
      }
    }
  }

  @override
  Future<void> discardRecording() async {
    _recording = false;
    _paused = false;
    _recorderError = null;
    for (final web.MediaRecorder? recorder in <web.MediaRecorder?>[_recorder, _speechRecorder]) {
      if (recorder == null) continue;
      try {
        if (recorder.state != 'inactive') recorder.stop();
      } catch (_) {
        // Already stopped.
      }
    }
    _recorder = null;
    _speechRecorder = null;
    _discardBuffers();
  }

  void _discardBuffers() {
    _chunks = <web.Blob>[];
    _speechChunks = <web.Blob>[];
    _bytes = 0;
    _activeFormat = null;
    _speechFormat = null;
    _recordingHasVideo = false;
  }

  @override
  void setScreenShareEndedCallback(void Function()? callback) {
    _screenEndedCallback = callback;
  }

  // -- teardown -------------------------------------------------------------

  void _stopStream(web.MediaStream stream) {
    for (final web.MediaStreamTrack track in stream.getTracks().toDart) {
      try {
        track.onended = null;
        track.stop();
      } catch (_) {
        // Track already stopped.
      }
    }
  }

  String _extensionFor(String mime) {
    final String base = mime.split(';').first.trim().toLowerCase();
    switch (base) {
      case 'audio/webm':
      case 'video/webm':
        return 'webm';
      case 'audio/ogg':
        return 'ogg';
      case 'video/ogg':
        return 'ogv';
      case 'audio/mp4':
        return 'm4a';
      case 'video/mp4':
        return 'mp4';
      case 'audio/mpeg':
        return 'mp3';
      case 'audio/wav':
        return 'wav';
      case 'video/quicktime':
        return 'mov';
    }
    return 'webm';
  }

  CaptureFailure _failure(Object error, String action) {
    final String text = error.toString();
    if (text.contains('NotAllowedError') || text.contains('SecurityError') || text.contains('PermissionDeniedError')) {
      return CaptureFailure(
        '$action was blocked. Allow this site to use it and try again.',
        permissionDenied: true,
      );
    }
    if (text.contains('NotFoundError') || text.contains('DevicesNotFoundError')) {
      return CaptureFailure('No device was found for $action.', deviceLost: true);
    }
    if (text.contains('NotReadableError') || text.contains('TrackStartError')) {
      return CaptureFailure('$action is already in use by another application.', deviceLost: true);
    }
    if (text.contains('NotSupportedError')) {
      return CaptureFailure('This browser cannot $action.', unsupported: true);
    }
    if (text.contains('AbortError')) {
      return CaptureFailure('$action was cancelled.', permissionDenied: true);
    }
    return CaptureFailure('$action failed: $text');
  }

  @override
  void dispose() {
    _screenEndedCallback = null;
    _recording = false;
    _paused = false;
    for (final web.MediaRecorder? recorder in <web.MediaRecorder?>[_recorder, _speechRecorder]) {
      if (recorder == null) continue;
      try {
        if (recorder.state != 'inactive') recorder.stop();
      } catch (_) {
        // Already stopped.
      }
    }
    _recorder = null;
    _speechRecorder = null;
    _discardBuffers();

    _screenActive = false;
    _screenLive = false;
    _screenHasAudio = false;
    _screenLabel = null;
    _micEnabled = false;
    _micLive = false;
    _micMuted = false;
    _cameraEnabled = false;
    _cameraLive = false;

    _detachMicrophoneAudio();
    _detachSystemAudio();
    final List<web.MediaStream?> streams = <web.MediaStream?>[_micStream, _cameraStream, _screenStream];
    _micStream = null;
    _cameraStream = null;
    _screenStream = null;
    for (final web.MediaStream? stream in streams) {
      if (stream != null) _stopStream(stream);
    }
    _applyStreams(_screenViews, null);
    _applyStreams(_cameraViews, null);
    _screenViews.clear();
    _cameraViews.clear();

    final web.AudioContext? context = _context;
    _context = null;
    _mix = null;
    _micAnalyser = null;
    _systemAnalyser = null;
    _micBuffer = null;
    _systemBuffer = null;
    if (context != null) {
      try {
        context.close().toDart.catchError((Object _) => null);
      } catch (_) {
        // Already closed.
      }
    }
  }
}

VirtualCaptureEngine createVirtualCaptureEngine() => _WebVirtualCaptureEngine();
