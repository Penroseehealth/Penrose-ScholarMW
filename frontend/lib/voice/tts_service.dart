import 'dart:async';
import 'dart:convert';

import '../services/api_service.dart';
import '../services/web_speech_service.dart';
import 'tts_audio_player.dart';
import 'voice_session_manager.dart';

/// Text-to-Speech service with sentence-level streaming support.
///
/// Uses the backend TTS engine (ElevenLabs / OpenAI) when available, falling
/// back to browser WebSpeechSynthesis when server TTS is unavailable.
class PenroseTtsService {
  final VoiceSessionManager _session;
  final WebSpeechService _speech;
  final ApiService _api;
  final TtsAudioPlayer _audioPlayer;

  bool _serverTtsAvailable = false;
  bool _isSpeaking = false;
  bool _speakingActive = false;
  List<String> _segments = [];
  int _currentSegmentIndex = 0;

  // ── Resumable speech stack ────────────────────────────────────────────────
  // When the user barges in mid-answer, the answer is not discarded: the
  // remaining segments are kept so the assistant can pick up where it left off.
  // The stack is deliberately bounded and time-limited so a stale resume cannot
  // replay an answer from an earlier turn.
  final List<_ResumableSpeech> _resumeStack = [];
  static const int _maxResumeDepth = 3;
  static const Duration _resumeExpiry = Duration(minutes: 2);
  int _resumeSeq = 0;
  List<String> get _segmentsView => List<String>.unmodifiable(_segments);

  PenroseTtsService({
    required VoiceSessionManager session,
    WebSpeechService? speech,
    ApiService? api,
    TtsAudioPlayer? audioPlayer,
  })  : _session = session,
        _speech = speech ?? WebSpeechService(),
        _api = api ?? ApiService(),
        _audioPlayer = audioPlayer ?? TtsAudioPlayer();

  bool get isSpeaking => _isSpeaking;
  bool get isAvailable => _speech.isSupported || _audioPlayer.isSupported;

  /// Catalog voice id (accent + gender) requested from the server engine.
  String? voiceId;

  /// Initialize and check server TTS availability.
  Future<void> initialize() async {
    try {
      final response = await _api.get('/voice/health');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _serverTtsAvailable = data['tts_available'] == true;
      }
    } catch (_) {
      _serverTtsAvailable = false;
    }
  }

  /// Speak text with sentence-level streaming.
  ///
  /// Segments the text into sentences and speaks each one individually
  /// to minimize latency. Supports interruption via VoiceSessionManager.
  Future<void> speak(String text, {String lang = 'en-US', double speed = 1.0}) async {
    if (text.isEmpty || !isAvailable) return;

    stop();
    _segments = _segmentText(text);
    _currentSegmentIndex = 0;
    _isSpeaking = true;
    _speakingActive = true;

    _session.startSpeaking(_segments.isNotEmpty ? _segments[0] : text);

    await _speakSegments(lang: lang, speed: speed);
  }

  /// Speak an explicit list of segments (used for resume), tracking position so
  /// a further interruption stays resumable.
  Future<void> _speakExplicitSegments(
    List<String> segments, {
    required String lang,
    required double speed,
  }) async {
    if (segments.isEmpty) return;
    _segments = List<String>.of(segments);
    _currentSegmentIndex = 0;
    _isSpeaking = true;
    _speakingActive = true;
    _session.startSpeaking(_segments[0]);
    await _speakSegments(lang: lang, speed: speed);
  }

  /// Synthesize a single segment using the server TTS engine and play it.
  ///
  /// Returns `true` when the server produced playable audio, `false` when it
  /// was unavailable so the caller can fall back to browser speech.
  Future<bool> _speakServerSegment(String text, {required double speed}) async {
    if (!_serverTtsAvailable || !_audioPlayer.isSupported) return false;
    try {
      final response = await _api.post(
        '/voice/tts',
        body: {'text': text, 'speed': speed, if (voiceId != null) 'voice_id': voiceId},
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final audioBase64 = data['audio_base64'] as String?;
      if (audioBase64 == null || audioBase64.isEmpty) return false;
      await _audioPlayer.playBase64(audioBase64);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Speak a streaming chunk (called as AI generates text).
  ///
  /// Chunks arrive as soon as each sentence of the stream is complete, so they
  /// are queued and played strictly in order - playing them concurrently would
  /// overlap audio. The queue is abandoned when the session is interrupted or a
  /// new utterance starts.
  Future<void> speakChunk(String chunk, {String lang = 'en-US', double speed = 1.0}) async {
    if (chunk.isEmpty) return;
    if (_shouldStop()) return;
    _isSpeaking = true;
    _session.startSpeaking(chunk);
    _enqueueChunk(chunk, lang: lang, speed: speed);
  }

  final List<String> _chunkQueue = [];
  bool _drainingChunks = false;

  void _enqueueChunk(String chunk, {required String lang, required double speed}) {
    _chunkQueue.add(chunk);
    if (!_drainingChunks) {
      unawaited(_drainChunkQueue(lang: lang, speed: speed));
    }
  }

  Future<void> _drainChunkQueue({required String lang, required double speed}) async {
    _drainingChunks = true;
    try {
      while (_chunkQueue.isNotEmpty) {
        if (_shouldStop()) {
          _chunkQueue.clear();
          break;
        }
        final next = _chunkQueue.removeAt(0);
        final playedViaServer = await _speakServerSegment(next, speed: speed);
        if (!playedViaServer && _speech.isSupported) {
          await _speech.speak(next, lang: lang);
        }
      }
    } finally {
      _drainingChunks = false;
      if (_chunkQueue.isEmpty && !_shouldStop()) {
        _isSpeaking = false;
        _session.onSpeakingComplete();
      }
    }
  }

  /// Speak one complete utterance and wait for playback to finish.
  ///
  /// Used by the visual maths tutor, which narrates one solution step at a
  /// time and must know when a step has finished before moving to the next.
  /// Returns `true` when the server produced the audio, `false` when browser
  /// speech was used instead.
  Future<bool> speakOnce(String text, {String lang = 'en-US', double speed = 1.0}) async {
    if (text.isEmpty || !isAvailable) return false;
    stop();
    _isSpeaking = true;
    final playedViaServer = await _speakServerSegment(text, speed: speed);
    if (!playedViaServer && _speech.isSupported) {
      await _speech.speak(text, lang: lang);
    }
    _isSpeaking = false;
    return playedViaServer;
  }

  /// Stop speaking.
  ///
  /// This is a hard stop: the answer is abandoned and any pending resume is
  /// dropped. Use [interrupt] when the stop is a barge-in that should be
  /// resumable.
  void stop() {
    _speech.cancelSpeech();
    _audioPlayer.stop();
    _isSpeaking = false;
    _chunkQueue.clear();
    _segments = [];
    _currentSegmentIndex = 0;
  }

  /// Stop because the user spoke over the assistant, keeping the unsaid part of
  /// the answer so it can be resumed later.
  void interrupt() {
    _pushResumableFromCurrentIndex();
    stop();
  }

  /// Whether there is an un-expired answer part that can be resumed.
  bool get canResume {
    _pruneResumeStack();
    return _resumeStack.isNotEmpty;
  }

  /// Resume the most recently interrupted answer from its unspoken boundary.
  ///
  /// Re-speaks from the start of the sentence that was playing when the user
  /// cut in, so the listener hears a complete thought rather than a fragment.
  Future<void> resume({String lang = 'en-US', double speed = 1.0}) async {
    _pruneResumeStack();
    if (_resumeStack.isEmpty) return;
    final entry = _resumeStack.removeLast();
    final remaining = entry.segments.sublist(
      entry.index.clamp(0, entry.segments.length),
    );
    if (remaining.isEmpty) return;
    _speakExplicitSegments(remaining, lang: lang, speed: speed);
  }

  /// Forget any pending resumable answer.
  void clearResume() => _resumeStack.clear();

  void _pushResumableFromCurrentIndex() {
    // Only retain when an utterance was actually in flight: calling interrupt()
    // after the answer already finished must not resurrect a stale resume.
    if (!_speakingActive) return;
    if (_segments.isEmpty || _currentSegmentIndex >= _segments.length) return;
    _resumeStack.add(
      _ResumableSpeech(
        segments: _segmentsView,
        index: _currentSegmentIndex,
        seq: _resumeSeq++,
      ),
    );
    // Bounded: keep only the newest few.
    while (_resumeStack.length > _maxResumeDepth) {
      _resumeStack.removeAt(0);
    }
  }

  void _pruneResumeStack() {
    final cutoff = DateTime.now().subtract(_resumeExpiry);
    _resumeStack.removeWhere((e) => e.createdAt.isBefore(cutoff));
  }

  /// Pause speaking.
  void pause() {
    _speech.cancelSpeech();
  }

  /// Check if the session wants us to stop (user interrupted).
  bool _shouldStop() => _session.state == VoiceEngineState.interrupted || _session.state == VoiceEngineState.listening;

  /// Segment text into sentences for streaming TTS.
  List<String> _segmentText(String text) {
    final segments = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (_isSentenceBoundary(text, i) && buffer.isNotEmpty) {
        segments.add(buffer.toString().trim());
        buffer.clear();
      }
    }
    if (buffer.isNotEmpty) {
      final remaining = buffer.toString().trim();
      if (remaining.isNotEmpty) segments.add(remaining);
    }
    return segments.isNotEmpty ? segments : [text];
  }

  bool _isSentenceBoundary(String text, int index) {
    if (index >= text.length - 1) return false;
    final char = text[index];
    final next = text[index + 1];
    return (char == '.' || char == '!' || char == '?') && (next == ' ' || next == '\n' || index == text.length - 1);
  }

  /// Speak segments sequentially, checking for interruption.
  Future<void> _speakSegments({required String lang, required double speed}) async {
    for (var i = _currentSegmentIndex; i < _segments.length; i++) {
      if (_shouldStop()) break;

      _currentSegmentIndex = i;
      _session.updateSpeakingText(_segments[i]);

      final playedViaServer = await _speakServerSegment(_segments[i], speed: speed);
      if (!playedViaServer && _speech.isSupported) {
        await _speech.speak(_segments[i], lang: lang);
      }

      // Brief pause between sentences for natural rhythm
      if (i < _segments.length - 1 && !_shouldStop()) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    if (!_shouldStop()) {
      _isSpeaking = false;
      _speakingActive = false;
      _session.onSpeakingComplete();
    }
  }

  void dispose() {
    stop();
    _resumeStack.clear();
    _audioPlayer.dispose();
  }
}

/// A partially-spoken answer retained so it can be resumed after a barge-in.
class _ResumableSpeech {
  _ResumableSpeech({
    required this.segments,
    required this.index,
    required this.seq,
  }) : createdAt = DateTime.now();

  /// All segments of the answer, in order.
  final List<String> segments;

  /// Index of the segment that was playing when the user interrupted.
  final int index;

  /// Monotonic sequence, so recency can be compared even within one millisecond.
  final int seq;

  /// When this entry was captured, for expiry.
  final DateTime createdAt;
}
