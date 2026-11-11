// Non-web no-op stubs for the browser Fullscreen API helpers.
//
// These are compiled on VM/mobile targets where `dart:js_interop` is absent.
// The classroom viewport will fall back to its Flutter-route full-workspace
// mode instead of real browser fullscreen.

/// Returns true when browser fullscreen is supported on the current platform.
bool isFullscreenSupported() => false;

/// Requests browser fullscreen for the element identified by [elementId].
/// No-op on non-web builds.
Future<void> requestFullscreen(String elementId) async {}

/// Exits browser fullscreen. No-op on non-web builds.
Future<void> exitFullscreen() async {}

/// Returns true when the browser is currently in fullscreen mode.
bool isFullscreenActive() => false;

/// Registers a [callback] that fires whenever the fullscreen state changes.
/// Returns a disposal function. No-op on non-web builds.
void Function() onFullscreenChange(void Function(bool isFullscreen) callback) =>
    () {}; // no-op disposer
