import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/services/api_service.dart';
import 'package:penrose_scholar/services/web_speech_service.dart';
import 'package:penrose_scholar/voice/tts_audio_player.dart';
import 'package:penrose_scholar/voice/tts_service.dart';
import 'package:penrose_scholar/voice/voice_session_manager.dart';

/// Records what was spoken instead of touching real audio.
class _FakeSpeech implements WebSpeechService {
  final List<String> spoken = <String>[];
  bool cancelled = false;

  @override
  bool get isSupported => true;
  @override
  bool get isListening => false;
  @override
  void startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onEnd,
    required void Function(String error) onError,
    String lang = 'en-US',
  }) {}
  @override
  void stopListening() {}
  @override
  Future<void> speak(String text, {String lang = 'en-US'}) async => spoken.add(text);
  @override
  void cancelSpeech() => cancelled = true;
  @override
  void dispose() {}
}

class _FakePlayer implements TtsAudioPlayer {
  @override
  bool get isSupported => false;
  @override
  Future<void> playBase64(String base64Data) async {}
  @override
  void stop() {}
  @override
  void dispose() {}
}

/// Never used: the fake speech service always services playback.
class _FakeApi implements ApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('unused');
}

void main() {
  PenroseTtsService build(VoiceSessionManager session, _FakeSpeech speech) => PenroseTtsService(
        session: session,
        speech: speech,
        api: _FakeApi(),
        audioPlayer: _FakePlayer(),
      );

  test('a barge-in keeps the unsaid part resumable', () async {
    final session = VoiceSessionManager()..createSession();
    final speech = _FakeSpeech();
    final tts = build(session, speech);

    // Speak a multi-sentence answer, then simulate an interruption after the
    // first sentence has been spoken.
    final speakFuture = tts.speak('First sentence here. Second sentence here. Third sentence here.');
    // Let the first sentence play, then interrupt.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    tts.interrupt();
    await speakFuture;

    expect(tts.canResume, isTrue, reason: 'unsaid sentences should be retained');

    final before = speech.spoken.length;
    await tts.resume();
    expect(speech.spoken.length, greaterThan(before), reason: 'resume should speak again');
    // After resuming, the retained part is consumed.
    expect(tts.canResume, isFalse);
  });

  test('interrupt with nothing left to say is not resumable', () async {
    final session = VoiceSessionManager()..createSession();
    final speech = _FakeSpeech();
    final tts = build(session, speech);

    // Single-segment answer: after it finishes there is nothing to resume.
    await tts.speak('Only one sentence.');
    tts.interrupt();
    expect(tts.canResume, isFalse);
  });

  test('a hard stop preserves resume until explicitly cleared', () async {
    final session = VoiceSessionManager()..createSession();
    final speech = _FakeSpeech();
    final tts = build(session, speech);

    final f = tts.speak('Alpha sentence. Beta sentence. Gamma sentence.');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    tts.interrupt();
    await f;
    expect(tts.canResume, isTrue);

    // A plain stop still leaves the answer resumable (like a pause)...
    tts.stop();
    expect(tts.canResume, isTrue, reason: 'stop alone keeps the answer resumable');

    // ...until the caller explicitly discards it.
    tts.clearResume();
    expect(tts.canResume, isFalse, reason: 'clearResume abandons the answer');
  });

  test('the resume stack is bounded', () async {
    final session = VoiceSessionManager()..createSession();
    final speech = _FakeSpeech();
    final tts = build(session, speech);

    // Create several interrupted answers; the newest few are kept.
    for (var i = 0; i < 6; i++) {
      final f = tts.speak('One sentence. Two sentence. Three sentence. Four sentence.');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      tts.interrupt();
      await f;
    }
    // Drain the stack; it must not grow unbounded and must terminate.
    var drained = 0;
    while (tts.canResume && drained < 10) {
      await tts.resume();
      drained++;
    }
    expect(drained, lessThanOrEqualTo(3), reason: 'at most _maxResumeDepth entries');
  });
}
