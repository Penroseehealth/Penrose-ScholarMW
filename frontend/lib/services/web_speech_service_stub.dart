import 'web_speech_service.dart';

WebSpeechService createWebSpeechService() => WebSpeechServiceStub();

class WebSpeechServiceStub implements WebSpeechService {
  @override
  bool get isSupported => false;

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
  Future<void> speak(String text, {String lang = 'en-US'}) async {}

  @override
  void cancelSpeech() {}

  @override
  void dispose() {}
}
