// Browser speech-recognition facade. Web builds use the Web Speech API
// (webkitSpeechRecognition/SpeechRecognition) via JS interop; other targets
// get a stub that reports "unsupported" so pages degrade gracefully.
import 'speech_input_engine.dart';

import 'speech_input_stub.dart' if (dart.library.js_interop) 'speech_input_web.dart' as impl;

export 'speech_input_engine.dart' show SpeechRecognitionEngine, SpeechResultCallback, SpeechStatusCallback;

class SpeechInput {
  SpeechInput._();

  /// Creates a recognition engine for the current platform. [onResult] fires
  /// with `(interim, committedText)` while [onStatus] reports lifecycle
  /// changes such as `listening` / `idle` / `error:<code>`.
  static SpeechRecognitionEngine create({required SpeechResultCallback onResult, SpeechStatusCallback? onStatus}) =>
      impl.createSpeechRecognitionEngine(onResult: onResult, onStatus: onStatus);
}
