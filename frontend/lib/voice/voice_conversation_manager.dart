import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/streaming_chat_service.dart';
import 'voice_session_manager.dart';

/// Orchestrates the full voice conversation loop:
/// User speech â†’ AI processing â†’ AI response â†’ TTS â†’ repeat.
class VoiceConversationManager extends ChangeNotifier {
  final VoiceSessionManager _session;
  final ApiService _api;
  final StreamingChatService _streaming;

  String _currentTranscript = '';
  String _currentAiText = '';
  bool _isProcessing = false;
  String? _sessionId;
  String _agentType = 'tutor';
  String _subject = '';
  String _topic = '';
  String _language = 'en';

  /// Text already handed to speech synthesis, so only new sentences are spoken.
  int _spokenUpTo = 0;

  // Callbacks
  void Function(String transcript)? _onUserSpoke;
  void Function(String aiText, {String modality})? _onAiResponded;
  void Function(String error)? _onError;
  void Function(String sentence)? _onSentenceReady;

  VoiceConversationManager({
    required VoiceSessionManager session,
    ApiService? api,
    StreamingChatService? streaming,
  })  : _session = session,
        _api = api ?? ApiService(),
        _streaming = streaming ?? StreamingChatService();

  // Getters
  String get currentTranscript => _currentTranscript;
  String get currentAiText => _currentAiText;
  bool get isProcessing => _isProcessing;
  String? get sessionId => _sessionId;

  /// Configure callbacks and session parameters.
  void configure({
    String agentType = 'tutor',
    String subject = '',
    String topic = '',
    String language = 'en',
    void Function(String transcript)? onUserSpoke,
    void Function(String aiText, {String modality})? onAiResponded,
    void Function(String error)? onError,
    void Function(String sentence)? onSentenceReady,
  }) {
    _agentType = agentType;
    _subject = subject;
    _topic = topic;
    _language = language;
    _onUserSpoke = onUserSpoke;
    _onAiResponded = onAiResponded;
    _onError = onError;
    _onSentenceReady = onSentenceReady;

    _session.configure(
      onTranscriptReady: (transcript) {
        processTranscript(transcript);
      },
      onAiResponse: (aiText) {
        _session.startSpeaking(aiText);
      },
    );
  }

  /// Create a voice session on the backend.
  Future<void> createSession() async {
    try {
      final response = await _api.post('/voice/session', body: {
        'subject': _subject,
        'topic': _topic,
        'agent_type': _agentType,
        'language': _language,
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _sessionId = data['session_id'] as String?;
        _session.createSession(sessionId: _sessionId);
      } else {
        // Fallback: create local session
        _session.createSession();
      }
    } catch (_) {
      _session.createSession();
    }
  }

  /// Process a user transcript and get AI response.
  ///
  /// Called by AudioCaptureService when a final transcript is ready.
  Future<void> processTranscript(String transcript) async {
    if (transcript.trim().isEmpty || _isProcessing) return;

    _currentTranscript = transcript;
    _onUserSpoke?.call(transcript);

    // Start AI processing
    _isProcessing = true;
    _session.onAiThinking();
    notifyListeners();

    try {
      // Use streaming for real-time response
      _currentAiText = '';
      _spokenUpTo = 0;
      await for (final chunk in _streaming.streamChat(
        message: transcript,
        sessionId: null,
        agentType: _agentType,
      )) {
        // If the user barged in while the assistant was still generating, stop
        // consuming the stream immediately (F5): cancel it and abandon the turn.
        if (_session.state == VoiceEngineState.interrupted) {
          _streaming.cancelCurrentStream();
          break;
        }
        if (chunk.type == 'chunk') {
          _currentAiText += chunk.content;
          _session.onAiGenerating(_currentAiText);
          _flushSpokenSentences();
          notifyListeners();
        } else if (chunk.type == 'done') {
          // Speak whatever tail never completed a sentence.
          _flushSpokenSentences(flushTail: true);
          _session.onAiComplete(_currentAiText);
        } else if (chunk.type == 'error') {
          if (chunk.content == 'auth') {
            _currentAiText = 'Session expired. Please log in again.';
            _session.onAiComplete(_currentAiText);
            _onError?.call('auth');
            _isProcessing = false;
            notifyListeners();
            return;
          }
          throw Exception(chunk.content);
        }
      }

      if (_currentAiText.isEmpty) {
        throw Exception('Empty response from AI');
      }

      _onAiResponded?.call(_currentAiText);
    } catch (e) {
      debugPrint('Voice conversation error: $e');
      const errorMsg = 'Sorry, I encountered an error. Please try again.';
      _currentAiText = errorMsg;
      _session.onAiComplete(errorMsg);
      _onError?.call(e.toString());
    } finally {
      _isProcessing = false;
      _currentTranscript = '';
      notifyListeners();
    }
  }

  /// Hand any newly-completed sentences to speech synthesis (F1/F3).
  ///
  /// Only whole sentences are spoken, so the assistant starts talking as soon as
  /// the first sentence of the stream is complete instead of waiting for the
  /// whole answer. With [final] true, a trailing fragment with no terminal
  /// punctuation is spoken too, so the last words are never dropped.
  void _flushSpokenSentences({bool flushTail = false}) {
    final listener = _onSentenceReady;
    if (listener == null) return;
    var boundary = -1;
    for (var i = _spokenUpTo; i < _currentAiText.length - 1; i++) {
      final char = _currentAiText[i];
      final next = _currentAiText[i + 1];
      if ((char == '.' || char == '!' || char == '?') && (next == ' ' || next == '\n')) {
        boundary = i + 1;
      }
    }
    if (boundary > _spokenUpTo) {
      final sentence = _currentAiText.substring(_spokenUpTo, boundary).trim();
      _spokenUpTo = boundary;
      if (sentence.isNotEmpty) listener(sentence);
      // Emit any further complete sentences in the same burst.
      _flushSpokenSentences(flushTail: flushTail);
      return;
    }
    if (flushTail) {
      final tail = _currentAiText.substring(_spokenUpTo).trim();
      _spokenUpTo = _currentAiText.length;
      if (tail.isNotEmpty) listener(tail);
    }
  }

  /// End the voice session.
  Future<void> endSession() async {
    if (_sessionId != null) {
      try {
        await _api.delete('/voice/session/$_sessionId');
      } catch (_) {}
    }
    _sessionId = null;
    _currentTranscript = '';
    _currentAiText = '';
    _isProcessing = false;
    _session.endSession();
    notifyListeners();
  }

  @override
  void dispose() {
    endSession();
    super.dispose();
  }
}
