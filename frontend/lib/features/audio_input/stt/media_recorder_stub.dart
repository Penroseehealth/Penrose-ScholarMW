// Non-web fallback: microphone recording is unavailable.
import 'media_recorder_engine.dart';

MediaRecorderEngine createMediaRecorderEngine() => _StubMediaRecorder();

class _StubMediaRecorder implements MediaRecorderEngine {
  @override
  bool get supported => false;

  @override
  bool get recording => false;

  @override
  bool get paused => false;

  @override
  int get elapsedMs => 0;

  @override
  int get level => 0;

  @override
  Future<void> start() async {
    throw StateError('Recording is not supported on this platform.');
  }

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  Future<RecordedAudio> stop() async => const RecordedAudio(bytes: [], mimeType: '');

  @override
  void cancel() {}
}
