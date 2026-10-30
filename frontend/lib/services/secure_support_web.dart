import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Whether the browser exposes WebCrypto, which `flutter_secure_storage` needs.
///
/// `crypto.subtle` is only defined in a secure context — HTTPS, `localhost` or a
/// `file://` page. Served over plain HTTP from a LAN address (for example
/// `http://192.168.1.201:8000`) it is `undefined`, and the plugin's first call
/// into it fails inside a JavaScript promise. That failure does not come back
/// through the Dart `try/catch` at the call site, so it surfaces as an uncaught
/// error and takes down whatever route was building.
bool secureStorageSupported() {
  try {
    final crypto = globalContext.getProperty<JSObject?>('crypto'.toJS);
    if (crypto == null) return false;
    return crypto.getProperty<JSObject?>('subtle'.toJS) != null;
  } catch (_) {
    return false;
  }
}
