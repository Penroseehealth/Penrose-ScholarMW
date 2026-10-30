import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_support_stub.dart' if (dart.library.js_interop) 'secure_support_web.dart';

/// Secure storage that cannot take the app down.
///
/// On web `flutter_secure_storage` encrypts with WebCrypto, which browsers only
/// expose in a secure context. On an insecure origin the plugin throws from
/// inside a JavaScript promise, where the Dart `try/catch` at the call site
/// cannot see it: the error escapes and kills the route that was building — the
/// login screen in practice.
///
/// This wrapper therefore checks the capability *before* the plugin is called and
/// keeps values in [SharedPreferences] when it is missing, so an insecure origin
/// loses the encryption but keeps the session working. Anything the plugin still
/// rejects is contained per call.
class SafeSecureStorage {
  const SafeSecureStorage();

  static const FlutterSecureStorage _platform = FlutterSecureStorage();
  static const String _fallbackPrefix = 'plain.';

  /// Cached capability probe; the answer cannot change within a page load.
  static bool? _capable;

  static bool get _usePlatform => _capable ??= secureStorageSupported();

  Future<String?> read({required String key}) async {
    if (_usePlatform) {
      try {
        final value = await _platform.read(key: key);
        if (value != null) return value;
      } catch (error) {
        _report('read', error);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_fallbackPrefix$key');
  }

  Future<void> write({required String key, required String value}) async {
    if (_usePlatform) {
      try {
        await _platform.write(key: key, value: value);
        return;
      } catch (error) {
        _report('write', error);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_fallbackPrefix$key', value);
  }

  Future<void> delete({required String key}) async {
    if (_usePlatform) {
      try {
        await _platform.delete(key: key);
      } catch (error) {
        _report('delete', error);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_fallbackPrefix$key');
  }

  Future<void> deleteAll() async {
    if (_usePlatform) {
      try {
        await _platform.deleteAll();
      } catch (error) {
        _report('deleteAll', error);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_fallbackPrefix)).toList()) {
      await prefs.remove(key);
    }
  }

  void _report(String operation, Object error) {
    debugPrint('SafeSecureStorage: $operation failed, keeping values in local storage: $error');
  }
}
