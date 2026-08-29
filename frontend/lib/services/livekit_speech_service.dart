import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'livekit_service.dart';
import 'web_speech_service.dart';

/// Self-hosted speech-to-text via the backend LiveKit STT relay.
///
/// The browser publishes microphone audio to a ``scholar-stt-*`` room, the
/// backend agent (vosk + LiveKit) transcribes it and relays final transcripts
/// back over the LiveKit data channel (topic ``scholar.stt``). This avoids the
/// browser's cloud-backed Web Speech API entirely.
///
/// If LiveKit is not reachable (e.g. backend token request fails), callers may
/// supply a [fallback] (browser Web Speech) implementation so voice still works.
class LiveKitSpeechService implements WebSpeechService {
  final LiveKitService _liveKit;
  final WebSpeechService? _fallback;

  lk.Room? _room;
  lk.CancelListenFunc? _dataCancel;
  lk.CancelListenFunc? _disconnectCancel;
  bool _listening = false;
  bool _manualStop = false;
  bool _activeUsingLiveKit = false;

  void Function(String text, bool isFinal)? _onResult;
  void Function()? _onEnd;

  LiveKitSpeechService({
    LiveKitService? liveKit,
    WebSpeechService? fallback,
  })  : _liveKit = liveKit ?? LiveKitService(),
        _fallback = fallback;

  @override
  bool get isSupported => true;

  @override
  bool get isListening => _listening;

  @override
  void startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onEnd,
    required void Function(String error) onError,
    String lang = 'en-US',
  }) {
    if (_listening) return;
    _onResult = onResult;
    _onEnd = onEnd;
    _manualStop = false;
    _activeUsingLiveKit = false;

    unawaited(_connectViaLiveKit(onError));
  }

  Future<void> _connectViaLiveKit(
    void Function(String error) onError,
  ) async {
    try {
      final token = await _liveKit.requestToken(
        roomName: 'scholar-stt-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (token == null || token.token.isEmpty) {
        _fallbackToBrowser(onError);
        return;
      }

      final room = lk.Room();
      await room.connect(token.url, token.token);

      _dataCancel = room.events.on<lk.DataReceivedEvent>((event) {
        _handleData(event);
      });
      _disconnectCancel = room.events.on<lk.RoomDisconnectedEvent>((_) {
        if (!_manualStop) {
          _listening = false;
          _teardownRoom();
          _onEnd?.call();
        }
      });

      await room.localParticipant!.setMicrophoneEnabled(true);

      _room = room;
      _activeUsingLiveKit = true;
      _listening = true;
      debugPrint(
        'LiveKit STT connected: ${token.roomName} @ ${token.url}',
      );
    } catch (e) {
      debugPrint('LiveKit STT connect error: $e');
      _fallbackToBrowser(onError);
    }
  }

  void _fallbackToBrowser(void Function(String error) onError) {
    final fallback = _fallback;
    if (fallback == null) {
      onError('Self-hosted speech service unreachable');
      _onEnd?.call();
      return;
    }
    debugPrint('LiveKit STT unavailable; falling back to browser speech');
    fallback.startListening(
      onResult: _onResult ?? (_, __) {},
      onEnd: _onEnd ?? () {},
      onError: onError,
    );
  }

  void _handleData(lk.DataReceivedEvent event) {
    if (event.topic != 'scholar.stt') return;
    try {
      final payload = utf8.decode(event.data);
      final json = jsonDecode(payload) as Map<String, dynamic>;
      if (json['type'] != 'stt') return;
      final text = (json['text'] as String?)?.trim();
      if (text == null || text.isEmpty) return;
      _onResult?.call(text, true);
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  @override
  void stopListening() {
    final fallback = _fallback;
    if (fallback != null && !_activeUsingLiveKit) {
      fallback.stopListening();
      return;
    }
    _manualStop = true;
    _listening = false;
    _teardownRoom();
  }

  void _teardownRoom() {
    _dataCancel?.call();
    _dataCancel = null;
    _disconnectCancel?.call();
    _disconnectCancel = null;
    final room = _room;
    _room = null;
    _activeUsingLiveKit = false;
    if (room != null) {
      unawaited(room.disconnect());
    }
  }

  @override
  Future<void> speak(String text, {String lang = 'en-US'}) async {
    // This service is STT-only; TTS is handled by the dedicated TTS layer.
  }

  @override
  void cancelSpeech() {}

  @override
  void dispose() {
    stopListening();
  }
}
