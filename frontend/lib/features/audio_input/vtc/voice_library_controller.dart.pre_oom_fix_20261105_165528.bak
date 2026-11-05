import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/networking/api_client.dart';
import 'clone_controller.dart';
import 'voice_catalog.dart';
import 'widgets/vtc_audio_player.dart';

/// One entry in the user's voice library, as returned by `/speech/voices`.
///
/// [voiceKey] is a real engine voice id, never a trained profile: the
/// configured TTS provider has no cloning endpoint, so an entry selects a voice
/// the engine can really produce and carries the user's naming/accent notes.
class VoiceEntry {
  const VoiceEntry({
    required this.id,
    required this.voiceKey,
    required this.displayName,
    this.accentLabel = '',
    this.styleNote = '',
    this.language = '',
    this.isDefault = false,
    this.isArchived = false,
  });

  final int id;
  final String voiceKey;
  final String displayName;
  final String accentLabel;
  final String styleNote;
  final String language;
  final bool isDefault;
  final bool isArchived;

  factory VoiceEntry.fromJson(Map<String, dynamic> json) => VoiceEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        voiceKey: '${json['voice_key'] ?? ''}',
        displayName: '${json['display_name'] ?? json['voice_key'] ?? ''}',
        accentLabel: '${json['accent_label'] ?? ''}',
        styleNote: '${json['style_note'] ?? ''}',
        language: '${json['language'] ?? ''}',
        isDefault: json['is_default'] == true,
        isArchived: json['is_archived'] == true,
      );
}

/// Lifecycle of the library request in flight, so the UI can show a real state
/// rather than an optimistic one.
enum LibraryState { idle, loading, ready, failed }

/// Owns MY VOICES state and every backend call behind it.
///
/// The library is a *selection* layer over the voices the existing TTS engine
/// already provides. It deliberately has no training job, no progress percentage
/// and no fidelity score, because the provider exposes no cloning or
/// fine-tuning capability to report one honestly.
class VoiceLibraryController extends ChangeNotifier {
  VoiceLibraryController({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  LibraryState _state = LibraryState.idle;
  List<VoiceEntry> _entries = const [];
  String? _loadError;

  /// Engine voices reported by `/speech/status`, minus the ones already added.
  List<VoiceOption> _engineVoices = const [];
  String _defaultVoice = '';
  bool _ttsConfigured = false;

  /// Cloning capability, kept separate from [ttsConfigured]: a working narrator
  /// does not imply the ability to train a voice, and vice versa.
  bool _cloneAvailable = false;
  String _cloneProvider = '';
  bool _cloneSynthesisIsSlow = false;

  final Map<int, GeneratedSpeech> _previews = {};
  final Set<int> _previewing = {};
  String? _previewError;
  final Set<int> _busy = {};

  /// The last failed mutation, surfaced with a retry affordance rather than
  /// swallowed.
  String? _actionError;

  LibraryState get state => _state;
  List<VoiceEntry> get entries => _entries;
  String? get loadError => _loadError;
  List<VoiceOption> get engineVoices => _engineVoices;
  bool get ttsConfigured => _ttsConfigured;

  /// The voice Penrose speaks with when a request does not name one.
  String get defaultVoice => _defaultVoice;
  VoiceEntry? get defaultEntry {
    for (final entry in _entries) {
      if (entry.isDefault) return entry;
    }
    return null;
  }

  bool get isEmpty => _entries.isEmpty;
  bool isBusy(int id) => _busy.contains(id);

  /// True while any mutation is in flight. Used by UI that is not bound to a
  /// single row, such as the "add a voice" form before a row exists.
  bool get mutating => _busy.isNotEmpty;
  bool isPreviewing(int id) => _previewing.contains(id);
  GeneratedSpeech? previewFor(int id) => _previews[id];
  String? get previewError => _previewError;

  /// The voice cloning/training capability, read from `/speech/clone/status`
  /// rather than assumed. False for a provider with no cloning endpoint (or a
  /// local sidecar that is not running), and the UI must say so instead of
  /// implying a trained profile exists.
  bool get cloningAvailable => _cloneAvailable;
  String get cloneProvider => _cloneProvider;
  bool get cloneSynthesisIsSlow => _cloneSynthesisIsSlow;

  /// Loads the library and the engine's advertised voices together, because the
  /// "add a voice" picker can only offer what `/speech/status` reports.
  Future<void> load() async {
    _state = LibraryState.loading;
    _loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        // Archived rows are requested too: the page owns the "show archived"
        // filter, so it needs the full set to count and toggle it honestly.
        _api.get('/speech/voices?include_archived=true'),
        _api.get('/speech/status'),
      ]);
      _entries = _readEntries(results[0]);
      final status = results[1];
      _ttsConfigured = status['tts_configured'] == true;
      _defaultVoice = '${status['default_voice'] ?? ''}';
      final raw = (status['tts_voices'] as List?) ?? const [];
      final all = VoiceCatalog.resolve(
        raw.map((e) => '$e').toList(growable: false),
        defaultVoice: _defaultVoice.isEmpty ? 'hannah' : _defaultVoice,
      );
      final taken = _entries.map((e) => e.voiceKey).toSet();
      _engineVoices = all.where((option) => !taken.contains(option.id)).toList(growable: false);
      _state = LibraryState.ready;
    } on ApiException catch (e) {
      _state = LibraryState.failed;
      _loadError =
          e.status == 503 ? 'Voice library is unavailable: ${e.message}' : 'Unable to load voices: ${e.message}';
    } catch (e) {
      _state = LibraryState.failed;
      _loadError = 'Unable to load voices: $e';
    }
    await _loadCloneCapability();
    notifyListeners();
  }

  /// Reads the cloning capability on its own so a backend without the endpoint
  /// still loads the voice library, and a down sidecar is reported as
  /// "unavailable" instead of "broken".
  Future<void> _loadCloneCapability() async {
    try {
      final clone = CloneCapability.fromJson(await _api.get('/speech/clone/status'));
      _cloneAvailable = clone.available;
      _cloneProvider = clone.provider;
      _cloneSynthesisIsSlow = clone.synthesisIsSlow;
    } on ApiException {
      _cloneAvailable = false;
      _cloneProvider = '';
      _cloneSynthesisIsSlow = false;
    } catch (_) {
      _cloneAvailable = false;
      _cloneProvider = '';
      _cloneSynthesisIsSlow = false;
    }
  }

  /// Retry after a failure. Also used by the page's error state.
  Future<void> retry() => load();

  Future<bool> add(
    String voiceKey, {
    String? displayName,
    String accentLabel = '',
    String styleNote = '',
    bool makeDefault = false,
  }) =>
      _mutate(
        voiceKey,
        () => _api.post(
          '/speech/voices',
          body: {
            'voice_key': voiceKey,
            if (displayName != null) 'display_name': displayName,
            if (accentLabel.isNotEmpty) 'accent_label': accentLabel,
            if (styleNote.isNotEmpty) 'style_note': styleNote,
            'make_default': makeDefault,
          },
        ),
      );
  Future<bool> rename(int id, String displayName) =>
      _mutate(voiceKeyOf(id), () => _api.patch('/speech/voices/$id', body: {'display_name': displayName}));

  /// Promotes one entry to the application's default voice. This is what makes
  /// every existing TTS caller speak with it: `/speech/synthesize` resolves the
  /// library default whenever a request does not name a voice.
  Future<bool> setDefault(int id) =>
      _mutate(voiceKeyOf(id), () => _api.patch('/speech/voices/$id', body: {'is_default': true}));

  Future<bool> setArchived(int id, bool archived) =>
      _mutate(voiceKeyOf(id), () => _api.patch('/speech/voices/$id', body: {'is_archived': archived}));

  Future<bool> remove(int id) => _mutate(voiceKeyOf(id), () => _api.delete('/speech/voices/$id'));

  Future<bool> updateNotes(int id, {String? accentLabel, String? styleNote}) => _mutate(
        voiceKeyOf(id),
        () => _api.patch(
          '/speech/voices/$id',
          body: {
            if (accentLabel != null) 'accent_label': accentLabel,
            if (styleNote != null) 'style_note': styleNote,
          },
        ),
      );

  /// Renders a short real sample in the entry's own voice.
  ///
  /// The returned [GeneratedSpeech] is handed straight to `VtcAudioPlayer`,
  /// which owns playback. This controller only fetches and caches the audio.
  Future<void> preview(int id) async {
    if (_previewing.contains(id)) return;
    _previewing.add(id);
    _previewError = null;
    notifyListeners();
    try {
      final res = await _api.post('/speech/voices/$id/preview');
      final base64 = (res['audio_base64'] as String?) ?? '';
      if (base64.isEmpty) {
        _previewError = 'The engine returned no audio for this voice. Try again or pick another.';
      } else {
        _previews[id] = GeneratedSpeech(
          base64: base64,
          mime: (res['mime'] as String?) ?? 'audio/wav',
          voice: (res['voice'] as String?) ?? voiceKeyOf(id),
          provider: (res['provider'] as String?) ?? 'groq',
          model: (res['model'] as String?) ?? '',
        );
      }
    } on ApiException catch (e) {
      _previewError = e.status == 503
          ? 'Voice synthesis is not configured on the backend: ${e.message}'
          : 'Voice synthesis failed: ${e.message}';
    } catch (e) {
      _previewError = 'Voice synthesis failed: $e';
    }
    _previewing.remove(id);
    notifyListeners();
  }

  void clearPreviewError() {
    _previewError = null;
    notifyListeners();
  }

  String? get actionError => _actionError;

  void clearActionError() {
    _actionError = null;
    notifyListeners();
  }

  String voiceKeyOf(int id) {
    for (final entry in _entries) {
      if (entry.id == id) return entry.voiceKey;
    }
    return '';
  }

  List<VoiceEntry> _readEntries(Map<String, dynamic> body) {
    final raw = (body['items'] as List?) ?? const [];
    return raw.whereType<Map<String, dynamic>>().map(VoiceEntry.fromJson).toList(growable: false);
  }

  /// Runs one library mutation, then refreshes from the server so the UI shows
  /// the real post-write state (including the single-default invariant) instead
  /// of a locally guessed one.
  Future<bool> _mutate(String voiceKey, Future<Map<String, dynamic>> Function() call) async {
    if (voiceKey.isEmpty) return false;
    _actionError = null;
    _busy.add(_idFor(voiceKey));
    notifyListeners();
    try {
      await call();
      await load();
      return true;
    } on ApiException catch (e) {
      _actionError =
          e.status == 503 ? 'Voice library is unavailable: ${e.message}' : 'Could not update that voice: ${e.message}';
      return false;
    } catch (e) {
      _actionError = 'Could not update that voice: $e';
      return false;
    } finally {
      _busy.remove(_idFor(voiceKey));
      notifyListeners();
    }
  }

  int _idFor(String voiceKey) {
    for (final entry in _entries) {
      if (entry.voiceKey == voiceKey) return entry.id;
    }
    // A create has no row yet, so it gets a stable negative marker that can
    // never collide with a real database id.
    return -voiceKey.hashCode.abs() % 100000;
  }
}
