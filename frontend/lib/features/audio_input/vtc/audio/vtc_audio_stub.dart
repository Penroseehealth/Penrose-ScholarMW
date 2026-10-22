// Non-web (VM/test) implementation: reports unsupported so the UI can say so
// instead of pretending an audio file is playing.
import 'vtc_audio_engine.dart';

class _StubVtcAudioEngine implements VtcAudioEngine {
  double _volume = 1.0;
  bool _seeking = false;

  @override
  bool get supported => false;

  @override
  AudioLoadResult load(String base64, String mime) =>
      const AudioLoadResult(false, error: 'Audio playback needs a browser.');

  @override
  void play() {}

  @override
  void pause() {}

  @override
  void stop() {}

  @override
  void seek(double seconds) {}

  @override
  void setVolume(double value) => _volume = value.clamp(0.0, 1.0);

  @override
  double get volume => _volume;

  @override
  double get position => 0;

  @override
  double get duration => 0;

  @override
  bool get playing => false;

  @override
  bool get ready => false;

  @override
  bool get seeking => _seeking;

  @override
  void setSeeking(bool value) => _seeking = value;

  @override
  Future<AudioShareResult> download(String filename) async =>
      const AudioShareResult(false, message: 'Downloads need a browser.');

  @override
  Future<AudioShareResult> share(String filename) async =>
      const AudioShareResult(false, message: 'Sharing needs a browser.');

  @override
  void dispose() {}
}

VtcAudioEngine createVtcAudioEngine() => _StubVtcAudioEngine();
