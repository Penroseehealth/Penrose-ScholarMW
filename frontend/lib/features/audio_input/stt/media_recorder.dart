// Microphone recording facade. Web builds use the MediaRecorder API; other
// targets get a stub that reports "unsupported" so pages degrade gracefully.
import 'media_recorder_engine.dart';
import 'media_recorder_stub.dart' if (dart.library.js_interop) 'media_recorder_web.dart' as impl;

export 'media_recorder_engine.dart' show ChunkedRecorderEngine, MediaRecorderEngine, RecordedAudio;

class MediaRecorderInput {
  MediaRecorderInput._();

  /// Creates the platform recorder.
  static MediaRecorderEngine create() => impl.createMediaRecorderEngine();
}
