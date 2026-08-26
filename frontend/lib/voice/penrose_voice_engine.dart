import 'package:flutter/foundation.dart';

import 'academic_speech_normalizer.dart';
import 'audio_capture_service.dart';
import 'tts_service.dart';
import 'voice_conversation_manager.dart';
import 'voice_session_manager.dart';

/// Penrose Interactive Voice Engine (PIVE).
///
/// Top-level facade that wires together all voice sub-services:
/// - VoiceSessionManager (state machine)
/// - AudioCaptureService (STT)
/// - PenroseTtsService (TTS)
/// - VoiceConversationManager (orchestration)
/// - ResponseModalityEngine (modality routing)
class PenroseVoiceEngine extends ChangeNotifier {
  late final VoiceSessionManager session;
  late final AudioCaptureService audioCapture;
  late final PenroseTtsService tts;
  late final VoiceConversationManager conversation;

  bool _initialized = false;
  bool _autoRead = true;

  bool get isInitialized => _initialized;
  bool get isListening => session.isListening;
  bool get isSpeaking => session.isSpeaking;
  bool get isProcessing => session.isProcessing;
  bool get isSessionActive => session.isSessionActive;
  bool get autoRead => _autoRead;
  VoiceEngineState get state => session.state;

  /// Initialize the voice engine with all sub-services.
  Future<void> initialize({
    String agentType = 'tutor',
    String subject = '',
    String topic = '',
    String language = 'en',
  }) async {
    if (_initialized) return;

    session = VoiceSessionManager();
    audioCapture = AudioCaptureService(session: session);
    tts = PenroseTtsService(session: session);
    conversation = VoiceConversationManager(session: session);

    // Initialize TTS
    await tts.initialize();

    // Wire up the conversation flow
    conversation.configure(
      agentType: agentType,
      subject: subject,
      topic: topic,
      language: language,
      onUserSpoke: _onUserSpoke,
      onAiResponded: _onAiResponded,
      onError: _onError,
    );

    // Set up session state change listener
    session.addListener(_onSessionStateChanged);

    // Create backend session
    await conversation.createSession();

    _initialized = true;
    notifyListeners();
  }

  /// Start a voice conversation.
  Future<void> startConversation() async {
    if (!_initialized) return;
    audioCapture.startCapture(lang: session.language);
  }

  /// Stop listening.
  void stopListening() {
    audioCapture.stopCapture();
  }

  /// Toggle listening on/off.
  void toggleListening() {
    session.toggleListening();
    if (session.isListening) {
      audioCapture.startCapture(lang: session.language);
    } else {
      audioCapture.stopCapture();
    }
  }

  /// Speak text aloud (manual TTS).
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    final normalized = AcademicSpeechNormalizer.normalize(text);
    await tts.speak(normalized, lang: session.language, speed: session.playbackSpeed);
  }

  /// Stop speaking.
  void stopSpeaking() {
    tts.stop();
  }

  /// Set auto-read mode.
  set autoRead(bool value) {
    _autoRead = value;
    notifyListeners();
  }

  /// End the current voice session.
  Future<void> endSession() async {
    tts.stop();
    audioCapture.dispose();
    await conversation.endSession();
  }

  /// Reconfigure the engine for a new subject/topic.
  void reconfigure({
    String? agentType,
    String? subject,
    String? topic,
    String? language,
  }) {
    conversation.configure(
      agentType: agentType ?? 'tutor',
      subject: subject ?? '',
      topic: topic ?? '',
      language: language ?? 'en',
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Internal flow handlers
  // ──────────────────────────────────────────────────────────────

  void _onSessionStateChanged() {
    notifyListeners();
  }

  void _onUserSpoke(String transcript) {
    debugPrint('PIVE: User spoke: $transcript');
  }

  void _onAiResponded(String aiText, {String modality = 'combined'}) async {
    debugPrint('PIVE: AI responded (${modality.length} chars)');

    if (_autoRead && modality != 'text') {
      await tts.speak(aiText, lang: session.language, speed: session.playbackSpeed);
    }
  }

  void _onError(String error) {
    debugPrint('PIVE error: $error');
  }

  @override
  void dispose() {
    session.removeListener(_onSessionStateChanged);
    session.dispose();
    audioCapture.dispose();
    tts.dispose();
    conversation.dispose();
    super.dispose();
  }
}
