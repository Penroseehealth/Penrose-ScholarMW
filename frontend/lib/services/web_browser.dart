/// Browser-only file and window helpers.
///
/// `package:web` and `dart:js_interop` only compile for the web, so importing
/// them directly from a shared screen breaks the widget tests (which run on the
/// Dart VM) and any non-web build. The conditional export keeps the browser
/// implementation for web and a stub everywhere else, matching the pattern used
/// by `web_speech_service.dart`, `tts_audio_player.dart` and the lab bridges.
library;

export 'web_browser_stub.dart' if (dart.library.js_interop) 'web_browser_web.dart';
