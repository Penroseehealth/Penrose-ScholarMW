// Non-web fallback: live browser speech recognition is unavailable.
import 'speech_input_engine.dart';

SpeechRecognitionEngine createSpeechRecognitionEngine({
  required SpeechResultCallback onResult,
  SpeechStatusCallback? onStatus,
}) =>
    _StubRecognitionEngine(onResult: onResult, onStatus: onStatus);

class _StubRecognitionEngine implements SpeechRecognitionEngine {
  _StubRecognitionEngine({required this.onResult, this.onStatus});

  final SpeechResultCallback onResult;
  final SpeechStatusCallback? onStatus;

  @override
  bool get supported => false;

  @override
  bool get listening => false;

  @override
  void start() => onStatus?.call('error:unsupported');

  @override
  void stop() => onStatus?.call('idle');

  @override
  void cancel() => onStatus?.call('idle');

  @override
  void dispose() {}
}
