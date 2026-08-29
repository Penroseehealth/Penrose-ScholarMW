import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/web_speech_service.dart';
import 'voice_session_manager.dart';

/// Handles real-time speech recognition with continuous mode support,
/// interim results streaming, and silence detection.
class AudioCaptureService {
  final WebSpeechService _speech;
  final VoiceSessionManager _session;

  AudioCaptureService({
    required VoiceSessionManager session,
    WebSpeechService? speech,
  })  : _session = session,
        _speech = speech ?? WebSpeechService();

  bool get isSupported => _speech.isSupported;
  bool get isListening => _session.isListening;

  /// Start capturing audio via Web Speech API.
  void startCapture({String lang = 'en-US'}) {
    if (!_speech.isSupported) return;

    _session.startListening();

    _speech.startListening(
      lang: lang,
      onResult: (text, isFinal) {
        if (_session.isListening || _session.state == VoiceEngineState.listening) {
          _session.onTranscriptReceived(text, isFinal: isFinal);

          if (_session.mode == VoiceConversationMode.continuous || _session.mode == VoiceConversationMode.handsFree) {
            // Reset silence timer on each interim result — auto-sends on pause
            _session.startSilenceTimer();
          }
        }
      },
      onEnd: () {
        if (_session.isListening) {
          // In hands-free mode, auto-restart after brief pause
          if (_session.mode == VoiceConversationMode.handsFree) {
            Timer(const Duration(milliseconds: 400), () {
              if (_session.isIdle || _session.state == VoiceEngineState.idle) {
                startCapture(lang: lang);
              }
            });
          }
        }
      },
      onError: (error) {
        debugPrint('AudioCapture error: $error');
        _session.onError(error);
      },
    );
  }

  /// Stop capturing audio.
  void stopCapture() {
    _speech.stopListening();
    _session.stopListening();
  }

  /// Stop the speech recognition engine.
  void dispose() {
    _speech.stopListening();
  }
}
