import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'tts_audio_player.dart';

TtsAudioPlayer createTtsAudioPlayer() => WebTtsAudioPlayer();

/// Web audio player that uses an HTML5 `Audio` element to play server-sent
/// base64 MP3 data (output device playback).
class WebTtsAudioPlayer implements TtsAudioPlayer {
  JSObject? _audio;
  Completer<void>? _playCompleter;

  @override
  bool get isSupported {
    try {
      return globalContext.hasProperty('Audio'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> playBase64(String base64Data) async {
    if (base64Data.isEmpty) return;
    stop();
    _playCompleter = Completer<void>();
    final completer = _playCompleter!;
    try {
      final ctor = globalContext.getProperty<JSFunction?>('Audio'.toJS);
      if (ctor == null) {
        if (!completer.isCompleted) completer.complete();
        return;
      }
      final audio = ctor.callAsConstructor<JSObject>();
      audio.setProperty('src'.toJS, 'data:audio/mpeg;base64,$base64Data'.toJS);
      // More natural playback
      try {
        audio.setProperty('playbackRate'.toJS, 0.98.toJS);
      } catch (_) {}
      audio.setProperty(
        'onended'.toJS,
        ((JSAny? _) {
          if (!completer.isCompleted) completer.complete();
        }).toJS,
      );
      audio.setProperty(
        'onerror'.toJS,
        ((JSAny? _) {
          if (!completer.isCompleted) completer.complete();
        }).toJS,
      );
      _audio = audio;
      audio.callMethod('play'.toJS);
      return await completer.future;
    } catch (_) {
      if (!completer.isCompleted) completer.complete();
      return;
    }
  }

  @override
  void stop() {
    final audio = _audio;
    if (audio != null) {
      try {
        audio.callMethod('pause'.toJS);
        audio.setProperty('src'.toJS, ''.toJS);
      } catch (_) {}
    }
    _audio = null;
    final completer = _playCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _playCompleter = null;
  }

  @override
  void dispose() {
    stop();
  }
}
