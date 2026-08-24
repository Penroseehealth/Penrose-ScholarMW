import 'web_speech_service_stub.dart' if (dart.library.js_interop) 'web_speech_service_web.dart' as platform;

abstract class WebSpeechService {
  bool get isSupported;
  bool get isListening;

  void startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onEnd,
    required void Function(String error) onError,
    String lang,
  });

  void stopListening();

  Future<void> speak(String text, {String lang});

  void cancelSpeech();

  void dispose();

  factory WebSpeechService() => platform.createWebSpeechService();
}
