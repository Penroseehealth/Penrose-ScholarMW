import 'tts_audio_player_stub.dart' if (dart.library.js_interop) 'tts_audio_player_web.dart' as platform;

/// Plays base64-encoded audio returned by the server TTS engine.
///
/// On web this uses an HTML5 `Audio` element so MP3 bytes synthesized by the
/// backend can be played through the default output device. On non-web
/// platforms it is a no-op (browser speech synthesis handles output there).
abstract class TtsAudioPlayer {
  bool get isSupported;

  /// Play base64-encoded audio (e.g. `data:audio/mpeg;base64,...` payload).
  ///
  /// Interrupts any currently playing audio and resolves when playback ends
  /// or is interrupted.
  Future<void> playBase64(String base64Data);

  /// Stop any currently playing audio.
  void stop();

  void dispose();

  factory TtsAudioPlayer() => platform.createTtsAudioPlayer();
}
