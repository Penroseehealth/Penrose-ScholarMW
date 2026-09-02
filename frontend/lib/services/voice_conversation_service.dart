import 'dart:async';

import 'package:flutter/foundation.dart';

import 'web_speech_service.dart';

/// Conversation mode for voice interaction.
enum VoiceConversationMode {
  pushToTalk,
  handsFree,
  continuous,
}

/// State of the voice conversation.
enum VoiceConversationState {
  idle,
  listening,
  processing,
  speaking,
  interrupted,
}

/// Callbacks for voice conversation events.
typedef OnTranscript = void Function(String text, bool isFinal);
typedef OnStateChanged = void Function(VoiceConversationState state);

/// Real-time voice conversation service.
///
/// Supports:
/// - Push-to-talk
/// - Hands-free (auto-detect speech start/end)
/// - Continuous conversation mode
/// - Interruptible AI responses
/// - Pause/resume
/// - Voice commands
class VoiceConversationService extends ChangeNotifier {
  final WebSpeechService _speech;

  VoiceConversationMode _mode = VoiceConversationMode.pushToTalk;
  VoiceConversationState _state = VoiceConversationState.idle;
  double _playbackSpeed = 1.0;
  bool _autoRead = true;
  String _language = 'en-US';

  // Callbacks
  OnTranscript? _onTranscript;
  OnStateChanged? _onStateChanged;

  // For continuous mode
  Timer? _silenceTimer;

  VoiceConversationService({
    WebSpeechService? speech,
  }) : _speech = speech ?? WebSpeechService();

  // Getters
  VoiceConversationMode get mode => _mode;
  VoiceConversationState get state => _state;
  double get playbackSpeed => _playbackSpeed;
  bool get getAutoRead => _autoRead;
  String get language => _language;
  bool get isListening => _state == VoiceConversationState.listening;
  bool get isSpeaking => _state == VoiceConversationState.speaking;
  bool get isAvailable => _speech.isSupported;

  // Setters
  set playbackSpeed(double speed) {
    _playbackSpeed = speed.clamp(0.5, 3.0);
    notifyListeners();
  }

  set autoRead(bool value) {
    _autoRead = value;
    notifyListeners();
  }

  set language(String lang) {
    _language = lang;
    notifyListeners();
  }

  /// Configure callbacks for conversation events.
  void configure({
    OnTranscript? onTranscript,
    OnStateChanged? onStateChanged,
  }) {
    _onTranscript = onTranscript;
    _onStateChanged = onStateChanged;
  }

  /// Switch conversation mode.
  void setMode(VoiceConversationMode mode) {
    if (_mode == mode) return;
    _stopListening();
    _mode = mode;
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Listening
  // -----------------------------------------------------------------------

  /// Start listening (push-to-talk or hands-free).
  void startListening() {
    if (!isAvailable) return;
    if (_state == VoiceConversationState.speaking) {
      // Interrupt AI speech
      _interruptAi();
    }

    _setState(VoiceConversationState.listening);

    _speech.startListening(
      lang: _language,
      onResult: (transcript, isFinal) {
        _onTranscript?.call(transcript, isFinal);

        if (isFinal && transcript.trim().isNotEmpty) {
          _onTranscriptReady(transcript.trim());
        }
      },
      onEnd: () {
        if (_mode == VoiceConversationMode.continuous && _state == VoiceConversationState.listening) {
          // Auto-restart in continuous mode
          _silenceTimer = Timer(const Duration(milliseconds: 500), () {
            if (_state == VoiceConversationState.listening) {
              startListening();
            }
          });
        } else {
          if (_state == VoiceConversationState.listening) {
            _setState(VoiceConversationState.idle);
          }
        }
      },
      onError: (error) {
        debugPrint('STT error: $error');
        _setState(VoiceConversationState.idle);
      },
    );
  }

  /// Stop listening (push-to-talk release).
  void stopListening() {
    _stopListening();
  }

  void _stopListening() {
    _silenceTimer?.cancel();
    _speech.stopListening();
    if (_state == VoiceConversationState.listening) {
      _setState(VoiceConversationState.idle);
    }
  }

  // -----------------------------------------------------------------------
  // Speaking / TTS
  // -----------------------------------------------------------------------

  /// Speak text aloud.
  void speak(String text) {
    if (!isAvailable || text.isEmpty) return;
    _setState(VoiceConversationState.speaking);

    _speech.speak(
      text,
      lang: _language,
    );
  }

  /// Stop speaking.
  void stopSpeaking() {
    _speech.cancelSpeech();
    if (_state == VoiceConversationState.speaking) {
      _setState(VoiceConversationState.idle);
    }
  }

  /// Pause speaking.
  void pauseSpeaking() {
    _speech.cancelSpeech();
  }

  // -----------------------------------------------------------------------
  // Interrupt
  // -----------------------------------------------------------------------

  /// Interrupt the AI while it's speaking — user started talking.
  void _interruptAi() {
    stopSpeaking();
    _setState(VoiceConversationState.interrupted);
    // Brief delay then start listening
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_state == VoiceConversationState.interrupted) {
        startListening();
      }
    });
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  void _onTranscriptReady(String text) {
    _stopListening();
  }

  void _setState(VoiceConversationState newState) {
    if (_state == newState) return;
    _state = newState;
    _onStateChanged?.call(newState);
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  /// Toggle listening on/off (for push-to-talk button).
  void toggleListening() {
    if (isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  /// Send a voice command (recognized from speech).
  void sendVoiceCommand(String command) {
    // This is called by the screen when a final transcript arrives
    // The screen handles the actual AI chat flow
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _speech.dispose();
    super.dispose();
  }
}
