import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Returns true when the browser supports the Fullscreen API.
bool isFullscreenSupported() {
  // The API is available when `document.fullscreenEnabled` is true.
  // We catch any exception to stay robust against unusual browser policies.
  try {
    return web.document.fullscreenEnabled;
  } catch (_) {
    return false;
  }
}

/// Requests browser fullscreen for the element whose DOM id is [elementId].
///
/// Falls back gracefully: if the element is not found, or the browser rejects
/// the request (e.g. the page is not focused), the returned future completes
/// without throwing.
Future<void> requestFullscreen(String elementId) async {
  try {
    final el = web.document.getElementById(elementId);
    if (el == null) return;
    await el.requestFullscreen().toDart;
  } catch (_) {
    // Browser denied (e.g. not triggered by a user gesture) — silent fallback.
  }
}

/// Exits browser fullscreen if it is currently active.
Future<void> exitFullscreen() async {
  try {
    if (web.document.fullscreenElement != null) {
      await web.document.exitFullscreen().toDart;
    }
  } catch (_) {}
}

/// Returns true when the browser is currently in fullscreen mode.
bool isFullscreenActive() {
  try {
    return web.document.fullscreenElement != null;
  } catch (_) {
    return false;
  }
}

/// Registers a [callback] that fires whenever the browser fullscreen state
/// changes. Returns a disposal function that removes the listener.
void Function() onFullscreenChange(void Function(bool isFullscreen) callback) {
  void handler(web.Event _) => callback(isFullscreenActive());
  web.document.addEventListener('fullscreenchange', handler.toJS);
  return () =>
      web.document.removeEventListener('fullscreenchange', handler.toJS);
}
