import 'tts_audio_player.dart';

TtsAudioPlayer createTtsAudioPlayer() => TtsAudioPlayerStub();

class TtsAudioPlayerStub implements TtsAudioPlayer {
  @override
  bool get isSupported => false;

  @override
  Future<void> playBase64(String base64Data) async {}

  @override
  void stop() {}

  @override
  void dispose() {}
}
