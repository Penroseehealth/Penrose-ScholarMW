import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/networking/api_client.dart';
import 'audio/vtc_audio.dart';
import 'clone_controller.dart';
import '../stt/media_recorder.dart';
import '../stt/speech_transcriber.dart';
import 'voice_catalog.dart';
import 'widgets/vtc_audio_player.dart';

/// What the workspace is doing. Every state below is driven by a real backend
/// response or a real browser event — nothing is optimistically faked.
enum SynthesisState { idle, working, ready, failed }

/// The real voice-sample pipeline. Note the wording: this app transcribes and
/// analyses a sample, it does not train a cloned voice profile.
enum SampleStage { empty, recording, captured, transcribing, ready, failed }

/// Real, measured facts about a captured or uploaded sample.
class AudioSampleFacts {
  const AudioSampleFacts({required this.bytes, required this.mimeType, required this.source, this.durationSeconds = 0});

  final int bytes;
  final String mimeType;

  /// "Microphone" or "Upload".
  final String source;

  /// Read back from the browser's audio element; 0 when unknown.
  final double durationSeconds;

  String get sizeLabel {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formatLabel {
    final subtype = mimeType.split('/').last;
    return subtype.isEmpty ? 'audio' : subtype.toUpperCase();
  }
}

/// A captured or uploaded voice sample plus its real transcript.
class VoiceSample {
  const VoiceSample({
    required this.facts,
    required this.bytes,
    this.transcript,
    this.transcriptProvider,
    this.transcriptModel,
  });

  final AudioSampleFacts facts;
  final List<int> bytes;
  final String? transcript;
  final String? transcriptProvider;
  final String? transcriptModel;

  VoiceSample copyWith({String? transcript, String? provider, String? model, AudioSampleFacts? facts}) => VoiceSample(
        facts: facts ?? this.facts,
        bytes: bytes,
        transcript: transcript ?? this.transcript,
        transcriptProvider: provider ?? transcriptProvider,
        transcriptModel: model ?? transcriptModel,
      );
}

/// Owns every piece of live state for the Voice Training Center and performs
/// all backend calls. Kept free of widgets so it can be unit tested.
class VtcController extends ChangeNotifier {
  VtcController({required ApiClient apiClient, VtcAudioEngine? audio, MediaRecorderEngine? recorder})
      : _api = apiClient,
        _audio = audio ?? VtcAudio.create(),
        _injectedRecorder = recorder;

  final ApiClient _api;
  final VtcAudioEngine _audio;

  /// Injected in tests; production creates its own on first use.
  final MediaRecorderEngine? _injectedRecorder;

  // -- engine capability (real, from /speech/status) -----------------------
  bool _statusLoaded = false;
  bool _ttsConfigured = false;
  bool _sttConfigured = false;
  // ignore: prefer_final_fields
  String _ttsProvider = '';
  String _sttProvider = '';
  String _ttsModel = '';
  String _sttModel = '';

  /// The engine's own voices, from `/speech/status`.
  List<VoiceOption> _engineVoices = const [];

  /// The user's trained voices, from `/speech/clones`. Kept apart from
  /// [_engineVoices] so a clone load failure cannot wipe the engine list.
  List<VoiceOption> _trainedOptions = const [];

  /// The picker list actually shown: trained voices first, then engine voices.
  List<VoiceOption> _voices = const [];
  VoiceOption? _selected;
  String? _statusError;

  /// What `/speech/clone/status` reports, so the page can offer training when
  /// the backend really has a provider and explain itself when it does not.
  CloneCapability _cloneCapability = const CloneCapability();

  /// Public read-only aliases, so callers never touch the mutable fields.
  String get ttsProviderValue => _ttsProvider;
  String get sttProviderValue => _sttProvider;
  String get ttsModelValue => _ttsModel;
  String get sttModelValue => _sttModel;

  // -- synthesis -------------------------------------------------------------
  SynthesisState _synthesis = SynthesisState.idle;
  GeneratedSpeech? _speech;
  String? _synthesisError;

  // -- sample ----------------------------------------------------------------
  SampleStage _stage = SampleStage.empty;
  VoiceSample? _sample;
  String? _sampleError;
  bool _recording = false;
  String _recordError = '';

  // -- misc ------------------------------------------------------------------
  String? _notice;

  MediaRecorderEngine? _recorder;
  bool _sampleLoaded = false;

  // -- getters ---------------------------------------------------------------

  bool get statusLoaded => _statusLoaded;
  bool get ttsConfigured => _ttsConfigured;
  bool get sttConfigured => _sttConfigured;
  String get ttsProvider => _ttsProvider;
  String get sttProvider => _sttProvider;
  String get ttsModel => _ttsModel;
  String get sttModel => _sttModel;
  List<VoiceOption> get voices => _voices;

  /// Just the user's trained voices, so a caller can tell whether the picker is
  /// offering a clone without filtering [voices] again.
  List<VoiceOption> get trainedVoices => _trainedOptions;
  VoiceOption? get selectedVoice => _selected;
  String? get statusError => _statusError;

  SynthesisState get synthesis => _synthesis;
  GeneratedSpeech? get speech => _speech;
  String? get synthesisError => _synthesisError;
  bool get synthesizing => _synthesis == SynthesisState.working;

  SampleStage get stage => _stage;
  VoiceSample? get sample => _sample;
  String? get sampleError => _sampleError;
  bool get recording => _recording;
  String get recordError => _recordError;
  String? get notice => _notice;

  bool get hasSample => _sample != null;
  bool get recorderSupported => _recorder?.supported ?? false;

  /// True when the backend can really produce a cloned voice profile, read
  /// from `/speech/clone/status` rather than assumed. Groq has no cloning
  /// endpoint, so this stays false for it and the UI must say so instead of
  /// implying a trained voice exists.
  bool get voiceCloningAvailable => _cloneCapability.available;

  /// The full capability, so the page can show the provider, the sample length
  /// the engine accepts, and the consent text the backend will store.
  CloneCapability get cloneCapability => _cloneCapability;

  /// The default voice id the backend advertised, used to preselect.
  String _defaultVoiceId = 'hannah';

  // -- lifecycle -------------------------------------------------------------

  Future<void> loadStatus() async {
    try {
      final res = await _api.get('/speech/status');
      _ttsConfigured = res['tts_configured'] == true;
      _sttConfigured = res['stt_configured'] == true;
      _sttProvider = (res['stt_provider'] as String?) ?? '';
      _defaultVoiceId = (res['default_voice'] as String?) ?? _defaultVoiceId;

      final ttsModels = (res['tts_models'] as List?) ?? const [];
      _ttsModel = ttsModels.isEmpty ? '' : '${ttsModels.first}';
      final sttModels = (res['stt_models'] as List?) ?? const [];
      _sttModel = sttModels.isEmpty ? '' : '${sttModels.last}';

      final rawVoices = (res['tts_voices'] as List?) ?? const [];
      _engineVoices = VoiceCatalog.resolve(
        rawVoices.map((e) => '$e').toList(growable: false),
        defaultVoice: _defaultVoiceId,
      );
      _statusError = null;
    } on ApiException catch (e) {
      _statusError = 'Could not read speech capability: ${e.message}';
    } catch (e) {
      _statusError = 'Could not read speech capability: $e';
    }
    await _loadCloneCapability();
    // Trained voices join the same picker the engine voices use, so a clone
    // made in the Voice Library is selectable here without a second control.
    await loadTrainedVoices();
    _statusLoaded = true;
    notifyListeners();
  }

  /// Loads the user's trained voices and folds them into the picker.
  ///
  /// Only ready, unarchived clones are offered: a clone still training, or one
  /// that failed, has no synthesizable version, and listing it would let the
  /// user pick a voice the backend would then refuse.
  Future<void> loadTrainedVoices() async {
    try {
      final res = await _api.get('/speech/clones');
      _trainedOptions = ((res['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CloneVoice.fromJson)
          .where((c) => c.ready && !c.isArchived)
          .map(
            (c) => VoiceCatalog.trained(
              cloneId: c.id,
              displayName: c.displayName,
              language: c.language,
              accent: c.accentLabel,
            ),
          )
          .toList(growable: false);
    } on ApiException {
      // A backend without cloning still narrates from the engine voices, so a
      // failure here clears only the trained section, never the whole picker.
      _trainedOptions = const [];
    } catch (_) {
      _trainedOptions = const [];
    }
    _rebuildVoices();
    notifyListeners();
  }

  /// Rebuilds [voices] from its two sources, keeping the current selection when
  /// that voice still exists so a background refresh never yanks the choice.
  void _rebuildVoices() {
    final previous = _selected?.id;
    _voices = [..._trainedOptions, ..._engineVoices];
    _selected = _voiceById(previous) ?? _voiceById(_defaultVoiceId) ?? (_voices.isEmpty ? null : _voices.first);
  }

  VoiceOption? _voiceById(String? id) {
    if (id == null) return null;
    for (final option in _voices) {
      if (option.id == id) return option;
    }
    return null;
  }

  /// Reads the cloning capability separately from the main status. A backend
  /// without this endpoint still narrates fine, so its absence must not take
  /// the whole capability panel down with it.
  Future<void> _loadCloneCapability() async {
    try {
      _cloneCapability = CloneCapability.fromJson(await _api.get('/speech/clone/status'));
    } on ApiException {
      _cloneCapability = const CloneCapability();
    } catch (_) {
      _cloneCapability = const CloneCapability();
    }
  }

  void selectVoice(VoiceOption option) {
    _selected = option;
    notifyListeners();
  }

  // -- synthesis -------------------------------------------------------------

  Future<void> synthesize(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _synthesisError = 'Enter some text to synthesise first.';
      _synthesis = SynthesisState.failed;
      notifyListeners();
      return;
    }
    if (_synthesis == SynthesisState.working) return;

    _synthesis = SynthesisState.working;
    _synthesisError = null;
    notifyListeners();

    try {
      final selected = _selected;
      final res = await _api.post(
        '/speech/synthesize',
        body: {
          'text': trimmed,
          // A trained voice is addressed by its own id; only an engine voice
          // goes through `voice`. Sending the selector key `clone:<id>` as
          // `voice` would name a voice the engine does not have.
          if (selected != null && selected.isTrained) 'voice_id': selected.cloneId,
          if (selected != null && !selected.isTrained) 'voice': selected.id,
        },
      );
      final base64 = (res['audio_base64'] as String?) ?? '';
      if (base64.isEmpty) {
        // The backend returned no audio: report failure, never a fake success.
        _synthesis = SynthesisState.failed;
        _synthesisError = 'The engine returned no audio for this request. Try again or pick another voice.';
        notifyListeners();
        return;
      }
      _speech = GeneratedSpeech(
        base64: base64,
        mime: (res['mime'] as String?) ?? 'audio/mpeg',
        voice: _spokenVoiceLabel(res, selected),
        provider: (res['provider'] as String?) ?? ttsProviderValue,
        model: (res['model'] as String?) ?? ttsModelValue,
      );
      _synthesis = SynthesisState.ready;
    } on ApiException catch (e) {
      _synthesis = SynthesisState.failed;
      _synthesisError = e.status == 503
          ? 'Speech synthesis is not configured on the backend: ${e.message}'
          : 'Synthesis failed: ${e.message}';
    } catch (e) {
      _synthesis = SynthesisState.failed;
      _synthesisError = 'Synthesis failed: $e';
    }
    notifyListeners();
  }

  /// The human name to show for audio just produced: the backend's
  /// `display_name` when it spoke with a clone, else the engine voice id it
  /// echoed, else the picker label for the selection.
  String _spokenVoiceLabel(Map<String, dynamic> res, VoiceOption? selected) {
    final display = (res['display_name'] as String?)?.trim() ?? '';
    if (display.isNotEmpty) return display;
    final echoed = (res['voice'] as String?)?.trim() ?? '';
    if (echoed.isNotEmpty) return echoed;
    return selected?.label ?? _defaultVoiceId;
  }

  /// Real playback of the captured/uploaded clip. Backed by the same engine the
  /// result player uses, so duration and play state are measured, not invented.
  void toggleSamplePreview() {
    final sample = _sample;
    if (sample == null) return;
    if (!_sampleLoaded) {
      final result = _audio.load(base64Encode(sample.bytes), sample.facts.mimeType);
      if (!result.ok) {
        _sampleError = result.error;
        notifyListeners();
        return;
      }
      _sampleLoaded = true;
    }
    if (_audio.playing) {
      _audio.pause();
    } else {
      _audio.play();
    }
    notifyListeners();
  }

  bool get samplePreviewPlaying => _audio.playing;

  /// Duration the browser reported for the clip, 0 while unknown.
  double get sampleDuration => _audio.duration;

  /// Folds the measured clip duration back into the sample facts. Called on a
  /// timer by the page while a clip is loaded, so the UI only ever shows a
  /// number the audio element actually reported.
  void syncSampleDuration() {
    final sample = _sample;
    if (sample == null) return;
    final measured = _audio.duration;
    if (measured <= 0 || (sample.facts.durationSeconds - measured).abs() < 0.05) {
      return;
    }
    _sample = sample.copyWith(
      facts: AudioSampleFacts(
        bytes: sample.facts.bytes,
        mimeType: sample.facts.mimeType,
        source: sample.facts.source,
        durationSeconds: measured,
      ),
    );
    notifyListeners();
  }

  Future<void> startRecording() async {
    _recorder ??= _injectedRecorder ?? MediaRecorderInput.create();
    if (!_recorder!.supported) {
      _recordError = 'Recording needs a browser with microphone support. You can upload a file instead.';
      notifyListeners();
      return;
    }
    try {
      await _recorder!.start();
      _recordError = '';
      _recording = true;
      _stage = SampleStage.recording;
      notifyListeners();
    } catch (e) {
      _recordError = 'Microphone unavailable or permission denied. You can upload a recording instead.';
      _recording = false;
      _stage = SampleStage.empty;
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    final recorder = _recorder;
    if (recorder == null || !_recording) return;
    try {
      final captured = await recorder.stop();
      _recording = false;
      final bytes = captured.bytes;
      if (bytes.isEmpty) {
        _stage = SampleStage.empty;
        _recordError = 'That recording was empty. Try again.';
        notifyListeners();
        return;
      }
      _sample = VoiceSample(
        facts: AudioSampleFacts(
          bytes: bytes.length,
          mimeType: captured.mimeType,
          source: 'Microphone',
          // The recorder's own elapsed time. This is the only trustworthy
          // length for a browser WebM/Opus recording, because the backend
          // cannot decode that container and would otherwise see a duration of
          // zero and reject a perfectly good sample as "too short".
          durationSeconds: captured.durationMs / 1000,
        ),
        bytes: bytes,
      );
      _stage = SampleStage.captured;
      notifyListeners();
      await transcribeSample();
    } catch (e) {
      _recording = false;
      _stage = SampleStage.failed;
      _sampleError = 'Could not finish the recording: $e';
      notifyListeners();
    }
  }

  void cancelRecording() {
    _recorder?.cancel();
    _recording = false;
    _stage = SampleStage.empty;
    notifyListeners();
  }

  /// Adopts an uploaded file as the sample (does not transcribe yet).
  Future<void> adoptUpload(String filename, Uint8List bytes) async {
    if (bytes.isEmpty) {
      _sampleError = 'That file was empty.';
      _stage = SampleStage.failed;
      notifyListeners();
      return;
    }
    _sample = VoiceSample(
      facts: AudioSampleFacts(
        bytes: bytes.length,
        mimeType: SpeechTranscriber.mimeForFilename(filename),
        source: 'Upload',
      ),
      bytes: bytes,
    );
    _stage = SampleStage.captured;
    _sampleError = null;
    notifyListeners();
    await transcribeSample();
  }

  /// Sends the sample to the real STT endpoint and records what came back.
  Future<void> transcribeSample() async {
    final sample = _sample;
    if (sample == null) return;
    _stage = SampleStage.transcribing;
    _sampleError = null;
    notifyListeners();
    try {
      final result = await SpeechTranscriber(_api).transcribe(
        bytes: sample.bytes,
        mimeType: sample.facts.mimeType,
        filename: 'voice-sample.${SpeechTranscriber.extensionFor(sample.facts.mimeType)}',
      );
      _sample = sample.copyWith(
        transcript: result.transcript,
        provider: result.provider ?? sttProviderValue,
        model: result.model ?? sttModelValue,
      );
      _stage = SampleStage.ready;
    } on TranscriptionNotConfigured catch (e) {
      _stage = SampleStage.failed;
      _sampleError = e.message;
    } on ApiException catch (e) {
      _stage = SampleStage.failed;
      _sampleError = 'Transcription failed: ${e.message}';
    } catch (e) {
      _stage = SampleStage.failed;
      _sampleError = 'Transcription failed: $e';
    }
    notifyListeners();
  }

  /// Deletes the sample and any transcript held in memory. This is the only
  /// retention the app performs — nothing is written to disk.
  void deleteSample() {
    _audio.stop();
    _sampleLoaded = false;
    _sample = null;
    _sampleError = null;
    _stage = SampleStage.empty;
    notifyListeners();
  }

  void setNotice(String message) {
    _notice = message;
    notifyListeners();
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder?.cancel();
    _audio.dispose();
    super.dispose();
  }
}
