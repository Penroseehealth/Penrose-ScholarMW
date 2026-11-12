import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Creates a Blob URL for [bytes] so the browser can render or download them.
String createObjectUrl(List<int> bytes, String mimeType) {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  return web.URL.createObjectURL(blob);
}

/// Releases a URL returned by [createObjectUrl].
void revokeObjectUrl(String url) => web.URL.revokeObjectURL(url);

/// Downloads [bytes] as [filename] via a temporary anchor element.
void downloadBytes(List<int> bytes, String filename, String mimeType) {
  final url = createObjectUrl(bytes, mimeType);
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();
  revokeObjectUrl(url);
}

/// Opens [url] in a new browser tab.
void openUrl(String url) => web.window.open(url, '_blank');

/// Opens [html] as a document in a new browser tab (used for print previews).
void openHtmlDocument(String html) => openUrl(Uri.dataFromString(html, mimeType: 'text/html').toString());
