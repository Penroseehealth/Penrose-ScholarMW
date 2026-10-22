// Facade over the platform audio engine, mirroring the pattern already used by
// audio_playback.dart in this feature. Web gets a real <audio> element; tests
// and the VM get an inert stub.
import 'vtc_audio_engine.dart';
import 'vtc_audio_stub.dart' if (dart.library.js_interop) 'vtc_audio_web.dart' as impl;

export 'vtc_audio_engine.dart' show AudioLoadResult, AudioShareResult, VtcAudioEngine;

class VtcAudio {
  VtcAudio._();

  static VtcAudioEngine create() => impl.createVtcAudioEngine();
}
