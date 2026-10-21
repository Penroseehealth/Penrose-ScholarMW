import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/services/api_service.dart';
import 'package:penrose_scholar/services/streaming_chat_service.dart';
import 'package:penrose_scholar/services/web_speech_service.dart';
import 'package:penrose_scholar/voice/tts_audio_player.dart';
import 'package:penrose_scholar/voice/tts_service.dart';
import 'package:penrose_scholar/voice/voice_conversation_manager.dart';
import 'package:penrose_scholar/voice/voice_session_manager.dart';

class _FakeSpeech implements WebSpeechService {
  final List<String> spoken = <String>[];
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
  void cancelSpeech() {}
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

class _FakeApi implements ApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('unused');
}

/// Yields AI chunks as one character group at a time, in order.
class _FakeStreaming implements StreamingChatService {
  _FakeStreaming(this.chunks);

  final List<String> chunks;
  bool cancelled = false;

  @override
  bool get isStreaming => false;

  @override
  void cancelCurrentStream() => cancelled = true;

  @override
  Stream<StreamChunk> streamChat({
    required String message,
    required int? sessionId,
    String agentType = 'tutor',
    dynamic workspace,
    List<String> fileIds = const [],
    String? preferredResponseMode,
    dynamic connectivity,
  }) async* {
    for (final c in chunks) {
      yield StreamChunk(type: 'chunk', content: c);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    yield const StreamChunk(type: 'done', content: '');
  }
}

void main() {
  test('streamed sentences reach speech as each one completes', () async {
    final session = VoiceSessionManager()..createSession();
    final spoken = <String>[];
    final streaming = _FakeStreaming(['Alpha is one. ', 'Beta is two. ', 'And a tail']);
    final manager = VoiceConversationManager(session: session, api: _FakeApi(), streaming: streaming)
      ..configure(onSentenceReady: spoken.add);

    await manager.processTranscript('Tell me about alpha.');

    expect(spoken, ['Alpha is one.', 'Beta is two.', 'And a tail']);
  });

  test('a barge-in cancels the in-flight stream', () async {
    final session = VoiceSessionManager()..createSession();
    final streaming = _FakeStreaming(['Alpha is one. ', 'Beta is two. ', 'Gamma is three. ', 'Delta is four. ']);
    final spoken = <String>[];
    final manager = VoiceConversationManager(session: session, api: _FakeApi(), streaming: streaming)
      ..configure(onSentenceReady: spoken.add);

    final future = manager.processTranscript('Go.');
    // Let the first chunk land, then interrupt mid-stream.
    await Future<void>.delayed(const Duration(milliseconds: 8));
    session.startSpeaking('x');
    session.interrupt();
    await future;

    expect(streaming.cancelled, isTrue, reason: 'in-flight stream must be cancelled');
  });

  test('streamed chunks are spoken strictly in order', () async {
    final session = VoiceSessionManager()..createSession();
    final speech = _FakeSpeech();
    final tts = PenroseTtsService(
      session: session,
      speech: speech,
      api: _FakeApi(),
      audioPlayer: _FakePlayer(),
    );

    tts.speakChunk('First sentence.');
    tts.speakChunk('Second sentence.');
    tts.speakChunk('Third sentence.');

    for (var i = 0; i < 30 && speech.spoken.length < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(speech.spoken, ['First sentence.', 'Second sentence.', 'Third sentence.']);
  });
}
