import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/networking/api_client.dart';
import '../stt/speech_transcriber.dart';
import 'widgets/vtc_audio_player.dart';

/// Reads a JSON list of strings defensively. The backend types these fields,
/// but a null or a stray value should not crash the voice list.
List<String> _strings(Object? raw) => ((raw as List?) ?? const []).map((e) => '$e').toList(growable: false);

/// Measured facts about a training sample, as analysed by the backend.
///
/// Every field here comes back from `quality.py`; nothing is estimated on the
/// client. [measured] is false when the sample could not be analysed at all
/// (an undecodable container, say), and then the numbers are absent rather than
/// zero-guessed.
class SampleQuality {
  const SampleQuality({
    this.measured = false,
    this.reason = '',
    this.durationMs = 0,
    this.speechMs = 0,
    this.snrDb,
    this.silenceRatio,
    this.peakDbfs,
    this.words = 0,
    this.wordsPerMinute,
    this.intelligibility = '',
    this.backgroundSpeech = '',
    this.warnings = const [],
    this.blockers = const [],
  });

  final bool measured;
  final String reason;
  final int durationMs;
  final int speechMs;
  final double? snrDb;
  final double? silenceRatio;
  final double? peakDbfs;
  final int words;
  final double? wordsPerMinute;
  final String intelligibility;
  final String backgroundSpeech;
  final List<String> warnings;
  final List<String> blockers;

  factory SampleQuality.fromJson(Map<String, dynamic> json) {
    double? num_(String key) {
      final raw = json[key];
      return raw is num ? raw.toDouble() : null;
    }

    return SampleQuality(
      measured: json['measured'] == true,
      reason: '${json['reason'] ?? ''}',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      speechMs: (json['speech_ms'] as num?)?.toInt() ?? 0,
      snrDb: num_('snr_db'),
      silenceRatio: num_('silence_ratio'),
      peakDbfs: num_('peak_dbfs'),
      words: (json['words'] as num?)?.toInt() ?? 0,
      wordsPerMinute: num_('words_per_minute'),
      intelligibility: '${json['intelligibility'] ?? ''}',
      backgroundSpeech: '${json['background_speech'] ?? ''}',
      warnings: _strings(json['warnings']),
      blockers: _strings(json['blockers']),
    );
  }

  /// A short human summary of what was measured, for the training card.
  String get summary {
    if (!measured) return reason.isEmpty ? 'Not analysed' : reason;
    final parts = <String>[];
    if (snrDb != null) parts.add('SNR ${snrDb!.toStringAsFixed(0)} dB');
    if (words > 0) {
      parts.add(wordsPerMinute == null ? '$words words' : '$words words @ ${wordsPerMinute!.toStringAsFixed(0)}/min');
    }
    if (intelligibility.isNotEmpty) parts.add(intelligibility);
    return parts.isEmpty ? 'Measured' : parts.join(' · ');
  }

  /// True when the sample is good enough to be worth training from. A blocker
  /// is the backend's own verdict, not a client guess.
  bool get usable => measured && blockers.isEmpty;
}

/// One training run. A voice can have several, and only one is current.
class CloneVersion {
  const CloneVersion({
    required this.id,
    required this.version,
    this.status = 'queued',
    this.modelVersion = '',
    this.errorMessage = '',
    this.similarityLabel = '',
    this.sampleDurationMs = 0,
    this.quality = const SampleQuality(),
  });

  final int id;
  final int version;
  final String status;
  final String modelVersion;
  final String errorMessage;
  final String similarityLabel;
  final int sampleDurationMs;
  final SampleQuality quality;

  bool get ready => status == 'ready';

  factory CloneVersion.fromJson(Map<String, dynamic> json) => CloneVersion(
        id: (json['id'] as num?)?.toInt() ?? 0,
        version: (json['version'] as num?)?.toInt() ?? 0,
        status: '${json['status'] ?? 'queued'}',
        modelVersion: '${json['model_version'] ?? ''}',
        errorMessage: '${json['error_message'] ?? ''}',
        similarityLabel: '${json['similarity_label'] ?? ''}',
        sampleDurationMs: (json['sample_duration_ms'] as num?)?.toInt() ?? 0,
        quality: SampleQuality.fromJson((json['quality'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

/// A voice the user trained, as returned by `/speech/clones`.
class CloneVoice {
  const CloneVoice({
    required this.id,
    required this.displayName,
    this.provider = '',
    this.status = 'queued',
    this.similarityLabel = '',
    this.consentGiven = false,
    this.consentText = '',
    this.isDefault = false,
    this.isArchived = false,
    this.accentLabel = '',
    this.language = '',
    this.currentVersionId,
    this.versions = const [],
  });

  final int id;
  final String displayName;
  final String provider;
  final String status;
  final String similarityLabel;
  final bool consentGiven;
  final String consentText;
  final bool isDefault;
  final bool isArchived;
  final String accentLabel;
  final String language;
  final int? currentVersionId;
  final List<CloneVersion> versions;

  bool get ready => status == 'ready';
  bool get failed => status == 'failed';

  /// The version the backend marks current, falling back to the newest one.
  CloneVersion? get currentVersion {
    if (versions.isEmpty) return null;
    for (final v in versions) {
      if (v.id == currentVersionId) return v;
    }
    return versions.first;
  }

  CloneVersion? get newestVersion =>
      versions.isEmpty ? null : versions.reduce((a, b) => a.version >= b.version ? a : b);

  /// Why a failed run failed, for a row that should stay visible rather than
  /// quietly disappearing.
  String get failureReason {
    for (final v in versions) {
      if (v.errorMessage.isNotEmpty) return v.errorMessage;
    }
    return '';
  }

  factory CloneVoice.fromJson(Map<String, dynamic> json) => CloneVoice(
        id: (json['id'] as num?)?.toInt() ?? 0,
        displayName: '${json['display_name'] ?? ''}',
        provider: '${json['provider'] ?? ''}',
        status: '${json['status'] ?? 'queued'}',
        similarityLabel: '${json['similarity_label'] ?? ''}',
        consentGiven: json['consent_given'] == true,
        consentText: '${json['consent_text'] ?? ''}',
        isDefault: json['is_default'] == true,
        isArchived: json['is_archived'] == true,
        accentLabel: '${json['accent_label'] ?? ''}',
        language: '${json['language'] ?? ''}',
        currentVersionId: (json['current_version_id'] as num?)?.toInt(),
        versions: ((json['versions'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CloneVersion.fromJson)
            .toList(growable: false),
      );
}

/// What `/speech/clone/status` reports about the configured provider.
class CloneCapability {
  const CloneCapability({
    this.available = false,
    this.sidecarReachable = true,
    this.provider = '',
    this.models = const [],
    this.speakingStyles = const [],
    this.minSampleMs = 0,
    this.maxSampleMs = 0,
    this.consentText = '',
    this.defaultCloneVoiceId,
    this.synthesisIsSlow = false,
    this.baseSpeakersAvailable = const [],
  });

  final bool available;

  /// Whether the configured provider is answering, as opposed to merely being
  /// configured.
  ///
  /// Defaults to true so a backend predating the field keeps offering training
  /// rather than going quiet; attempting it and reporting why it failed is
  /// still better than refusing to start.
  final bool sidecarReachable;

  final String provider;

  /// The provider's real options: engine models for ElevenLabs, or the base
  /// speaker accents for OpenVoice.
  final List<String> models;

  /// Empty for OpenVoice, which has no style control. Kept as returned so the
  /// UI never offers a dial the engine ignores.
  final List<String> speakingStyles;
  final int minSampleMs;
  final int maxSampleMs;
  final String consentText;
  final int? defaultCloneVoiceId;

  /// True when a reply takes minutes rather than seconds, so the UI can say so
  /// before the user waits rather than appearing to hang.
  final bool synthesisIsSlow;

  bool get isLocal => provider == 'openvoice';

  /// The subset of [models] the engine can genuinely produce.
  ///
  /// OpenVoice accepts five base speakers but ships a reference embedding for
  /// only two; the rest are spoken with en-us. Listing those three would put an
  /// accent picker in front of the user where three of the five choices cannot
  /// happen, which is worse than offering no picker at all. Empty means "every
  /// model is available" or "not applicable", so an older backend that omits the
  /// field keeps working instead of blanking the control.
  final List<String> baseSpeakersAvailable;

  /// [models] filtered down to what can actually be spoken.
  List<String> get selectableModels =>
      baseSpeakersAvailable.isEmpty ? models : models.where(baseSpeakersAvailable.contains).toList(growable: false);

  /// True when some accepted model cannot be produced, so the UI can explain why
  /// fewer accents are offered than the API accepts.
  bool get hasUnavailableModels => baseSpeakersAvailable.isNotEmpty && baseSpeakersAvailable.length < models.length;

  factory CloneCapability.fromJson(Map<String, dynamic> json) => CloneCapability(
        available: json['clone_available'] == true,
        sidecarReachable: json['clone_reachable'] != false,
        provider: '${json['clone_provider'] ?? ''}',
        models: _strings(json['clone_models']),
        speakingStyles: _strings(json['speaking_styles']),
        minSampleMs: (json['min_sample_ms'] as num?)?.toInt() ?? 0,
        maxSampleMs: (json['max_sample_ms'] as num?)?.toInt() ?? 0,
        consentText: '${json['consent_text'] ?? ''}',
        defaultCloneVoiceId: (json['default_clone_voice_id'] as num?)?.toInt(),
        synthesisIsSlow: json['synthesis_is_slow'] == true,
        baseSpeakersAvailable: _strings(json['base_speakers_available']),
      );
}

enum CloneLoadState { idle, loading, ready, failed }

/// Owns the cloned-voice state and every `/speech/clone*` call.
///
/// Split from [VoiceLibraryController] because the two are different things: the
/// library selects among voices the engine already has, while this owns voices
/// that had to be trained first. Merging them would make "unavailable because no
/// provider is configured" indistinguishable from "you have not trained one".
class CloneController extends ChangeNotifier {
  CloneController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  CloneLoadState _state = CloneLoadState.idle;
  CloneCapability _capability = const CloneCapability();
  List<CloneVoice> _voices = const [];
  String? _loadError;

  /// Set while a training run is in flight. Training is slow and irreversible in
  /// the user's time, so it gets explicit state rather than a generic spinner.
  final Set<int> _training = {};
  final Set<int> _previews = {};
  final Map<int, GeneratedSpeech> _previewAudio = {};

  /// The side-by-side comparison from `/test`: the same paragraph in the clone
  /// and in an engine voice.
  final Map<int, VoiceComparison> _comparisons = {};
  final Set<int> _comparing = {};

  String? _trainError;
  String? _actionError;
  String? _previewError;

  CloneLoadState get state => _state;
  CloneCapability get capability => _capability;
  List<CloneVoice> get voices => _voices;
  String? get loadError => _loadError;
  String? get trainError => _trainError;
  String? get actionError => _actionError;
  String? get previewError => _previewError;

  bool get available => _capability.available;

  /// Whether training can actually be attempted: configured *and* answering.
  /// A configured provider that is not answering is its own state, so the UI
  /// can say what to start instead of recording a sample and failing later.
  bool get reachable => _capability.sidecarReachable;
  bool get isEmpty => _voices.isEmpty;
  bool isTraining(int id) => _training.contains(id);
  bool isPreviewing(int id) => _previews.contains(id);
  bool isComparing(int id) => _comparing.contains(id);
  GeneratedSpeech? previewFor(int id) => _previewAudio[id];
  VoiceComparison? comparisonFor(int id) => _comparisons[id];

  /// True while any training run is in flight anywhere.
  bool get training => _training.isNotEmpty;

  /// Clones that can actually be spoken with, which is not all of them: a
  /// failed run is listed so it stays visible, but it is not selectable.
  List<CloneVoice> get usable => _voices.where((v) => v.ready && !v.isArchived).toList(growable: false);

  Future<void> load() async {
    _state = CloneLoadState.loading;
    _loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([_api.get('/speech/clone/status'), _api.get('/speech/clones')]);
      _capability = CloneCapability.fromJson(results[0]);
      // `/speech/clones` returns a bare JSON array, which ApiClient normalises
      // to `{'items': [...]}` like every other list endpoint.
      _voices = _readClones(results[1]);
      _state = CloneLoadState.ready;
    } on ApiException catch (e) {
      _state = CloneLoadState.failed;
      _loadError = _describe(e, 'Voice cloning');
    } catch (e) {
      _state = CloneLoadState.failed;
      _loadError = 'Unable to load cloned voices: $e';
    }
    notifyListeners();
  }

  Future<void> retry() => load();

  /// Reads the clone list, tolerating a null `items` so a backend that answers
  /// `{}` reads as "no clones" rather than as a load failure.
  static List<CloneVoice> _readClones(Map<String, dynamic> body) => ((body['items'] as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(CloneVoice.fromJson)
      .toList(growable: false);

  /// Trains a new voice from a recorded or uploaded sample.
  ///
  /// [consent] must be true; the caller is responsible for having collected it
  /// in the UI, and this refuses rather than sending someone's voice anywhere
  /// on a stray call.
  Future<bool> train({
    required String displayName,
    required List<int> bytes,
    required String mimeType,
    required bool consent,
    int durationMs = 0,
    String language = '',
    String accentLabel = '',
    bool makeDefault = false,
  }) async {
    if (displayName.trim().isEmpty) {
      _trainError = 'Give the voice a name first.';
      notifyListeners();
      return false;
    }
    if (!consent) {
      _trainError = 'You need to confirm you own this voice before it can be trained.';
      notifyListeners();
      return false;
    }
    if (bytes.isEmpty) {
      _trainError = 'Record or upload a sample first.';
      notifyListeners();
      return false;
    }
    if (_capability.minSampleMs > 0 && durationMs > 0 && durationMs < _capability.minSampleMs) {
      _trainError = 'That sample is ${(durationMs / 1000).toStringAsFixed(1)}s long. '
          'Record at least ${(_capability.minSampleMs / 1000).round()} seconds of speech.';
      notifyListeners();
      return false;
    }

    _trainError = null;
    final marker = -1;
    _training.add(marker);
    notifyListeners();
    try {
      await _api.postMultipart(
        '/speech/clones',
        fields: {
          'display_name': displayName.trim(),
          'consent': 'true',
          // Omitted when unknown rather than sent as 0. The backend reads a
          // declared 0 as "zero seconds long" and rejects the sample, which is
          // a false claim about a recording we simply could not measure.
          if (durationMs > 0) 'duration_ms': '$durationMs',
          if (language.isNotEmpty) 'language': language,
          if (accentLabel.isNotEmpty) 'accent_label': accentLabel,
          'make_default': '$makeDefault',
        },
        files: [
          MultipartFilePart(
            name: 'file',
            filename: 'sample.${SpeechTranscriber.extensionFor(mimeType)}',
            bytes: bytes,
            contentType: mimeType,
          ),
        ],
      );
      await load();
      return true;
    } on ApiException catch (e) {
      _trainError = _describe(e, 'Training');
      return false;
    } catch (e) {
      _trainError = 'Training failed: $e';
      return false;
    } finally {
      _training.remove(marker);
      notifyListeners();
    }
  }

  /// Re-runs training from a fresh sample, keeping the working version.
  Future<bool> retrain(int id) => _runOn(id, () => _api.post('/speech/clones/$id/retrain'));

  /// Promotes a specific version back to current after a bad retrain.
  Future<bool> promote(int voiceId, int versionId) =>
      _runOn(voiceId, () => _api.post('/speech/clones/$voiceId/versions/$versionId/promote'));

  Future<bool> remove(int id) => _runOn(id, () => _api.delete('/speech/clones/$id'));

  /// Renders a real new sentence in the clone. Slow on CPU providers, which is
  /// why the capability flag exists and the UI states the wait up front.
  Future<void> preview(int id) async {
    if (_previews.contains(id)) return;
    _previews.add(id);
    _previewError = null;
    notifyListeners();
    try {
      final res = await _api.post('/speech/clones/$id/preview');
      final base64 = (res['audio_base64'] as String?) ?? '';
      if (base64.isEmpty) {
        _previewError = 'The engine returned no audio for this voice.';
      } else {
        _previewAudio[id] = GeneratedSpeech(
          base64: base64,
          mime: (res['mime'] as String?) ?? 'audio/wav',
          voice: (res['voice'] as String?) ?? '$id',
          provider: (res['provider'] as String?) ?? _capability.provider,
          model: (res['model'] as String?) ?? '',
        );
      }
    } on ApiException catch (e) {
      _previewError = _describe(e, 'Preview');
    } catch (e) {
      _previewError = 'Preview failed: $e';
    }
    _previews.remove(id);
    notifyListeners();
  }

  /// The same paragraph in the clone and in an engine voice, so the user can
  /// judge the clone against the narrator they already know.
  Future<void> compare(int id) async {
    if (_comparing.contains(id)) return;
    _comparing.add(id);
    _actionError = null;
    notifyListeners();
    try {
      final res = await _api.post('/speech/clones/$id/test');
      final clone = (res['clone'] as Map?)?.cast<String, dynamic>();
      final original = (res['original'] as Map?)?.cast<String, dynamic>();
      if (clone == null || original == null) {
        _actionError = 'The comparison came back incomplete.';
      } else {
        _comparisons[id] = VoiceComparison(
          voiceId: id,
          displayName: '${res['display_name'] ?? ''}',
          text: '${res['text'] ?? ''}',
          similarityLabel: '${res['similarity_label'] ?? 'Unknown'}',
          clone: _speechOf(clone),
          original: _speechOf(original),
        );
      }
    } on ApiException catch (e) {
      _actionError = _describe(e, 'Comparison');
    } catch (e) {
      _actionError = 'Comparison failed: $e';
    }
    _comparing.remove(id);
    notifyListeners();
  }

  void clearTrainError() {
    _trainError = null;
    notifyListeners();
  }

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  void clearPreviewError() {
    _previewError = null;
    notifyListeners();
  }

  /// Shared shape for every per-voice mutation: mark it busy, call, then
  /// re-read the list so the UI shows the server's real post-write state.
  Future<bool> _runOn(int id, Future<Map<String, dynamic>> Function() call) async {
    if (_training.contains(id)) return false;
    _actionError = null;
    _training.add(id);
    notifyListeners();
    try {
      await call();
      await load();
      return true;
    } on ApiException catch (e) {
      _actionError = _describe(e, 'That action');
      return false;
    } catch (e) {
      _actionError = 'That action failed: $e';
      return false;
    } finally {
      _training.remove(id);
      notifyListeners();
    }
  }

  GeneratedSpeech _speechOf(Map<String, dynamic> json) => GeneratedSpeech(
        base64: '${json['audio_base64'] ?? ''}',
        mime: (json['mime'] as String?) ?? 'audio/wav',
        voice: '${json['voice'] ?? ''}',
        provider: (json['provider'] as String?) ?? _capability.provider,
        model: (json['model'] as String?) ?? '',
      );

  /// A 503 means the provider is not configured or the local sidecar is down.
  /// That is a different problem from a bad request, and saying so is the
  /// difference between a user restarting the sidecar and a user giving up.
  String _describe(ApiException e, String what) {
    if (e.status == 503) {
      return _isSidecarFailure(e)
          ? '$what is unavailable: the local voice service is not answering. '
              'Start the OpenVoice sidecar and try again.'
          : '$what is unavailable: ${e.message}';
    }
    if (e.status == 422) return '$what was rejected: ${e.message}';
    return '$what failed: ${e.message}';
  }

  /// Whether [e] came from the local sidecar rather than from the provider
  /// being unconfigured.
  ///
  /// The capability record is normally enough, but it is fetched once on load
  /// and can still be empty when training is attempted, or stale after the
  /// backend was reconfigured. In that state the raw `WinError 10061` text was
  /// reaching the user verbatim — a message naming an OS error code and no
  /// action, when the only fix is starting the sidecar. The error's own code
  /// and message are checked as well, so the actionable wording survives either
  /// path: the backend reports `clone_provider_unreachable` directly when it
  /// fails the call, and carries it in `details.root_code` when the failure is
  /// rewrapped as a generic training failure.
  bool _isSidecarFailure(ApiException e) {
    if (_capability.isLocal) return true;
    final rootCode = '${e.details?['root_code'] ?? ''}';
    if (e.code == 'clone_provider_unreachable' || rootCode == 'clone_provider_unreachable') {
      return true;
    }
    final haystack = '${e.message} $rootCode'.toLowerCase();
    return haystack.contains('sidecar') || haystack.contains('local voice service');
  }
}

/// The paired rendering returned by `/test`, for a side-by-side A/B.
class VoiceComparison {
  const VoiceComparison({
    required this.voiceId,
    required this.displayName,
    required this.text,
    required this.similarityLabel,
    required this.clone,
    required this.original,
  });

  final int voiceId;
  final String displayName;
  final String text;

  /// "Unknown" for providers that measure no similarity. Rendered as such rather
  /// than as a score, because a clone that was not measured is not a bad clone.
  final String similarityLabel;
  final GeneratedSpeech clone;
  final GeneratedSpeech original;

  bool get similarityUnknown => similarityLabel.toLowerCase() == 'unknown';
}
