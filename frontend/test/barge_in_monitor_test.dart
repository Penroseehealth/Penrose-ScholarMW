import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/features/audio_input/stt/media_recorder.dart';
import 'package:penrose_scholar/voice/barge_in_monitor.dart';
import 'package:penrose_scholar/voice/voice_session_manager.dart';

/// A recorder whose level the test drives directly.
class _FakeRecorder implements MediaRecorderEngine {
  int level = 0;
  bool started = false;
  bool cancelled = false;

  @override
  bool get supported => true;
  @override
  bool get recording => started;
  @override
  bool get paused => false;
  @override
  int get elapsedMs => 0;
  @override
  Future<void> start() async => started = true;
  @override
  void pause() {}
  @override
  void resume() {}
  @override
  Future<RecordedAudio> stop() async => const RecordedAudio(bytes: [], mimeType: '');
  @override
  void cancel() => cancelled = true;
}

/// A recorder that claims to be unsupported, so the monitor must stay inert.
class _UnsupportedRecorder extends _FakeRecorder {
  @override
  bool get supported => false;
}

void main() {
  test('sustained energy while speaking triggers a barge-in interrupt', () async {
    final session = VoiceSessionManager()..createSession();
    final recorder = _FakeRecorder();
    final monitor = BargeInMonitor(
      session: session,
      recorder: recorder,
      threshold: 20,
      requiredHits: 2,
      pollInterval: const Duration(milliseconds: 20),
      armDelay: Duration.zero,
    );

    session.startSpeaking('The assistant is talking.');
    await monitor.start();
    expect(recorder.started, isTrue);

    var interrupted = false;
    session.configure(onInterrupted: () => interrupted = true);

    recorder.level = 50;
    // Two polls are required; give the timer room to fire both.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    monitor.stop();

    expect(interrupted, isTrue, reason: 'sustained energy should interrupt');
    expect(recorder.cancelled, isTrue, reason: 'mic must be released on stop');
  });

  test('a single loud frame does not interrupt', () async {
    final session = VoiceSessionManager()..createSession();
    final recorder = _FakeRecorder();
    final monitor = BargeInMonitor(
      session: session,
      recorder: recorder,
      threshold: 20,
      requiredHits: 3,
      pollInterval: const Duration(milliseconds: 20),
      armDelay: Duration.zero,
    );

    session.startSpeaking('Talking.');
    await monitor.start();

    var interrupted = false;
    session.configure(onInterrupted: () => interrupted = true);

    recorder.level = 90; // one frame, then silence before enough hits
    await Future<void>.delayed(const Duration(milliseconds: 15));
    recorder.level = 0;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    monitor.stop();

    expect(interrupted, isFalse, reason: 'a lone spike must be rejected');
  });

  test('energy below threshold never interrupts', () async {
    final session = VoiceSessionManager()..createSession();
    final recorder = _FakeRecorder();
    final monitor = BargeInMonitor(
      session: session,
      recorder: recorder,
      threshold: 40,
      requiredHits: 1,
      pollInterval: const Duration(milliseconds: 20),
      armDelay: Duration.zero,
    );

    session.startSpeaking('Talking.');
    await monitor.start();

    var interrupted = false;
    session.configure(onInterrupted: () => interrupted = true);

    recorder.level = 10; // background noise
    await Future<void>.delayed(const Duration(milliseconds: 100));
    monitor.stop();

    expect(interrupted, isFalse);
  });

  test('an unsupported recorder leaves the monitor inert', () async {
    final session = VoiceSessionManager()..createSession();
    final recorder = _UnsupportedRecorder();
    final monitor = BargeInMonitor(
      session: session,
      recorder: recorder,
      pollInterval: const Duration(milliseconds: 20),
    );

    session.startSpeaking('Talking.');
    await monitor.start();

    expect(monitor.isRunning, isFalse, reason: 'no mic graph means no barge-in');
  });
}
