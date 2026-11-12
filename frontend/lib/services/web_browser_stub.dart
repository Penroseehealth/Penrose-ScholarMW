/// Non-web fallback for [web_browser.dart].
///
/// Penrose ships as a web app, so these helpers are never reached on the Dart
/// VM; they exist so shared screens stay compilable outside the browser.
Never _unsupported() => throw UnsupportedError('Browser file helpers are only available on the web.');

/// Creates a Blob URL for [bytes]. Only supported on the web.
String createObjectUrl(List<int> bytes, String mimeType) => _unsupported();

/// Releases a URL returned by [createObjectUrl].
void revokeObjectUrl(String url) {}

/// Downloads [bytes] as [filename]. Only supported on the web.
void downloadBytes(List<int> bytes, String filename, String mimeType) => _unsupported();

/// Opens [url] in a new browser tab. Only supported on the web.
void openUrl(String url) => _unsupported();

/// Opens [html] as a document in a new browser tab. Only supported on the web.
void openHtmlDocument(String html) => _unsupported();
