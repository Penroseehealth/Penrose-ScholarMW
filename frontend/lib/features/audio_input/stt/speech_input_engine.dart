// Shared contract for the browser speech-recognition engines (web + stub).

/// Fired with the live interim transcript and the text committed so far.
typedef SpeechResultCallback = void Function(String interim, String committed);

/// Lifecycle reports: `listening`, `idle`, `error:<code>`.
typedef SpeechStatusCallback = void Function(String status);

/// Platform speech-recognition engine. Web hires the Web Speech API; the
/// stub (VM/tests) reports unsupported and is inert.
abstract class SpeechRecognitionEngine {
  /// Whether this platform can listen live in the browser.
  bool get supported;

  /// True while the recognizer is active.
  bool get listening;

  /// Starts listening for speech. Fires [onStatus] when active or on error.
  void start();

  /// Stops and commits the final transcript via [onResult].
  void stop();

  /// Aborts without committing; drops the current utterance.
  void cancel();

  /// Releases browser resources.
  void dispose();
}
