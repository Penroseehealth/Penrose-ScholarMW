import 'dart:async';
import 'dart:convert';

import '../services/api_service.dart';
import '../services/web_speech_service.dart';
import 'voice_session_manager.dart';

/// Text-to-Speech service with sentence-level streaming support.
///
/// Falls back to browser WebSpeechSynthesis when server TTS is unavailable.
class PenroseTtsService {
  final VoiceSessionManager _session;
  final WebSpeechService _speech;
  final ApiService _api;

  bool _serverTtsAvailable = false;
  bool _isSpeaking = false;
  List<String> _segments = [];
  int _currentSegmentIndex = 0;

  PenroseTtsService({
    required VoiceSessionManager session,
    WebSpeechService? speech,
    ApiService? api,
  })  : _session = session,
        _speech = speech ?? WebSpeechService(),
        _api = api ?? ApiService();

  bool get isSpeaking => _isSpeaking;
  bool get isAvailable => _speech.isSupported;

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
    if (text.isEmpty || !_speech.isSupported) return;

    stop();
    _segments = _segmentText(text);
    _currentSegmentIndex = 0;
    _isSpeaking = true;

    _session.startSpeaking(_segments.isNotEmpty ? _segments[0] : text);

    await _speakSegments(lang: lang, speed: speed);
  }

  /// Speak a streaming chunk (called as AI generates text).
  Future<void> speakChunk(String chunk, {String lang = 'en-US'}) async {
    if (chunk.isEmpty) return;
    // Use browser TTS for immediate feedback on streaming chunks
    _session.startSpeaking(chunk);
    await _speech.speak(chunk, lang: lang);
  }

  /// Stop speaking.
  void stop() {
    _speech.cancelSpeech();
    _isSpeaking = false;
    _segments = [];
    _currentSegmentIndex = 0;
  }

  /// Pause speaking.
  void pause() {
    _speech.cancelSpeech();
  }

  /// Check if the session wants us to stop (user interrupted).
  bool _shouldStop() {
    return _session.state == VoiceEngineState.interrupted || _session.state == VoiceEngineState.listening;
  }

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

      await _speech.speak(_segments[i], lang: lang);

      // Brief pause between sentences for natural rhythm
      if (i < _segments.length - 1 && !_shouldStop()) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    if (!_shouldStop()) {
      _isSpeaking = false;
      _session.onSpeakingComplete();
    }
  }

  void dispose() {
    stop();
  }
}
