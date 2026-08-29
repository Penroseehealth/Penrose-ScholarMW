import 'dart:async';

import 'package:flutter/foundation.dart';

/// Penrose Interactive Voice Engine — Session State Machine.
///
/// States: IDLE → LISTENING → TRANSCRIBING → THINKING → GENERATING → SPEAKING
/// Supports interruption, pause, resume, and continuous conversation mode.
enum VoiceEngineState {
  idle,
  listening,
  transcribing,
  thinking,
  generating,
  speaking,
  interrupted,
}

enum VoiceConversationMode {
  pushToTalk,
  handsFree,
  continuous,
}

/// Central state machine for the PIVE voice engine.
///
/// Manages the full lifecycle of a voice conversation session,
/// including STT, AI processing, TTS, and interruption handling.
class VoiceSessionManager extends ChangeNotifier {
  VoiceEngineState _state = VoiceEngineState.idle;
  VoiceConversationMode _mode = VoiceConversationMode.handsFree;
  String? _sessionId;
  String _currentTranscript = '';
  String _currentAiText = '';
  String _currentSpeakerText = '';
  bool _autoRead = true;
  double _playbackSpeed = 1.0;
  String _language = 'en-US';
  DateTime? _sessionStarted;
  int _turnCount = 0;

  // Callbacks
  VoidCallback? _onSessionCreated;
  void Function(String transcript)? _onTranscriptReady;
  void Function(String aiText)? _onAiResponse;
  void Function(VoiceEngineState from, VoiceEngineState to)? _onStateChanged;
  VoidCallback? _onInterrupted;

  // Timers
  Timer? _silenceTimer;
  Timer? _thinkingTimeoutTimer;

  static const Duration _silenceTimeout = Duration(milliseconds: 1500);
  static const Duration _thinkingTimeout = Duration(seconds: 30);

  // Getters
  VoiceEngineState get state => _state;
  VoiceConversationMode get mode => _mode;
  String? get sessionId => _sessionId;
  String get currentTranscript => _currentTranscript;
  String get currentAiText => _currentAiText;
  String get currentSpeakerText => _currentSpeakerText;
  bool get autoRead => _autoRead;
  double get playbackSpeed => _playbackSpeed;
  String get language => _language;
  bool get isListening => _state == VoiceEngineState.listening;
  bool get isSpeaking => _state == VoiceEngineState.speaking;
  bool get isProcessing => _state == VoiceEngineState.thinking || _state == VoiceEngineState.generating;
  bool get isIdle => _state == VoiceEngineState.idle;
  bool get isSessionActive => _sessionId != null;
  DateTime? get sessionStarted => _sessionStarted;
  int get turnCount => _turnCount;

  // Setters
  set autoRead(bool value) {
    _autoRead = value;
    notifyListeners();
  }

  set playbackSpeed(double speed) {
    _playbackSpeed = speed.clamp(0.5, 3.0);
    notifyListeners();
  }

  set language(String lang) {
    _language = lang;
    notifyListeners();
  }

  /// Configure event callbacks.
  void configure({
    VoidCallback? onSessionCreated,
    void Function(String transcript)? onTranscriptReady,
    void Function(String aiText)? onAiResponse,
    void Function(VoiceEngineState from, VoiceEngineState to)? onStateChanged,
    VoidCallback? onInterrupted,
  }) {
    _onSessionCreated = onSessionCreated;
    _onTranscriptReady = onTranscriptReady;
    _onAiResponse = onAiResponse;
    _onStateChanged = onStateChanged;
    _onInterrupted = onInterrupted;
  }

  /// Create a new voice session.
  void createSession({String? sessionId}) {
    _sessionId = sessionId ?? 'local-${DateTime.now().millisecondsSinceEpoch}';
    _sessionStarted = DateTime.now();
    _turnCount = 0;
    _transitionTo(VoiceEngineState.idle);
    _onSessionCreated?.call();
    notifyListeners();
  }

  /// Switch conversation mode.
  void setMode(VoiceConversationMode mode) {
    if (_mode == mode) return;
    if (isListening) stopListening();
    _mode = mode;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────
  // Listening
  // ──────────────────────────────────────────────────────────────

  /// User starts speaking.
  void startListening() {
    if (_state == VoiceEngineState.speaking) {
      interrupt();
    }
    if (_state == VoiceEngineState.thinking || _state == VoiceEngineState.generating) {
      return; // Don't listen while AI is processing
    }

    _silenceTimer?.cancel();
    _transitionTo(VoiceEngineState.listening);
  }

  /// User finished speaking — transition to transcribing.
  void onTranscriptReceived(String transcript, {bool isFinal = true}) {
    _currentTranscript = transcript;
    if (isFinal && transcript.trim().isNotEmpty) {
      _transitionTo(VoiceEngineState.transcribing);
      _onTranscriptReady?.call(transcript.trim());
    }
    notifyListeners();
  }

  /// User stops listening manually.
  void stopListening() {
    _silenceTimer?.cancel();
    if (_state == VoiceEngineState.listening) {
      _transitionTo(VoiceEngineState.idle);
    }
  }

  /// Handle an error (e.g. Web Speech API failure).
  void onError(String error) {
    _silenceTimer?.cancel();
    _currentAiText = error;
    if (_state == VoiceEngineState.listening || _state == VoiceEngineState.transcribing) {
      _transitionTo(VoiceEngineState.idle);
    }
    notifyListeners();
  }

  /// Start silence timer for hands-free mode.
  void startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      if (_state == VoiceEngineState.listening && _currentTranscript.trim().isNotEmpty) {
        onTranscriptReceived(_currentTranscript);
      }
    });
  }

  // ──────────────────────────────────────────────────────────────
  // AI Processing
  // ──────────────────────────────────────────────────────────────

  /// AI is thinking about the user's input.
  void onAiThinking() {
    _transitionTo(VoiceEngineState.thinking);
    _thinkingTimeoutTimer?.cancel();
    _thinkingTimeoutTimer = Timer(_thinkingTimeout, () {
      if (_state == VoiceEngineState.thinking) {
        _transitionTo(VoiceEngineState.idle);
      }
    });
  }

  /// AI response is being generated (streaming).
  void onAiGenerating(String partialText) {
    _thinkingTimeoutTimer?.cancel();
    _currentAiText = partialText;
    if (_state != VoiceEngineState.generating) {
      _transitionTo(VoiceEngineState.generating);
    }
    notifyListeners();
  }

  /// AI response is complete.
  void onAiComplete(String fullText) {
    _thinkingTimeoutTimer?.cancel();
    _currentAiText = fullText;
    _turnCount++;
    _onAiResponse?.call(fullText);
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────
  // Speaking / TTS
  // ──────────────────────────────────────────────────────────────

  /// Start speaking the AI's response.
  void startSpeaking(String text) {
    _currentSpeakerText = text;
    _transitionTo(VoiceEngineState.speaking);
  }

  /// Update the text being spoken (for streaming TTS).
  void updateSpeakingText(String text) {
    _currentSpeakerText = text;
    notifyListeners();
  }

  /// AI finished speaking.
  void onSpeakingComplete() {
    _currentSpeakerText = '';
    if (_state == VoiceEngineState.speaking) {
      if (_mode == VoiceConversationMode.continuous || _mode == VoiceConversationMode.handsFree) {
        _transitionTo(VoiceEngineState.idle);
        Timer(const Duration(milliseconds: 300), () {
          if (_mode == VoiceConversationMode.continuous || _mode == VoiceConversationMode.handsFree) {
            startListening();
          }
        });
      } else {
        _transitionTo(VoiceEngineState.idle);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Interruption / Barge-in
  // ──────────────────────────────────────────────────────────────

  /// User interrupted the AI (started speaking while AI was speaking).
  void interrupt() {
    if (_state == VoiceEngineState.speaking) {
      _transitionTo(VoiceEngineState.interrupted);
      _currentSpeakerText = '';
      _onInterrupted?.call();

      // Brief pause then start listening
      Timer(const Duration(milliseconds: 200), () {
        if (_state == VoiceEngineState.interrupted) {
          startListening();
        }
      });
    }
  }

  /// Stop the current speaking and transition to idle.
  void stopSpeaking() {
    if (_state == VoiceEngineState.speaking) {
      _currentSpeakerText = '';
      _transitionTo(VoiceEngineState.idle);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────

  /// Toggle listening on/off (for push-to-talk button).
  void toggleListening() {
    if (isListening) {
      stopListening();
    } else {
      startListening();
    }
  }

  /// End the current voice session.
  void endSession() {
    _silenceTimer?.cancel();
    _thinkingTimeoutTimer?.cancel();
    _sessionId = null;
    _currentTranscript = '';
    _currentAiText = '';
    _currentSpeakerText = '';
    _turnCount = 0;
    _sessionStarted = null;
    _transitionTo(VoiceEngineState.idle);
  }

  // ──────────────────────────────────────────────────────────────
  // Internal
  // ──────────────────────────────────────────────────────────────

  void _transitionTo(VoiceEngineState newState) {
    if (_state == newState) return;
    final old = _state;
    _state = newState;
    _onStateChanged?.call(old, newState);
    notifyListeners();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _thinkingTimeoutTimer?.cancel();
    super.dispose();
  }
}
