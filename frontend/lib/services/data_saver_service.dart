import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DataSaverService {
  static final DataSaverService _instance = DataSaverService._();
  factory DataSaverService() => _instance;
  DataSaverService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _enabled = false;
  bool _imagesEnabled = false;

  static const _kDataSaverEnabled = 'data_saver_enabled';
  static const _kImagesEnabled = 'data_saver_images_enabled';
  static const _kCachePrefix = 'api_cache_';
  static const _kCacheTimePrefix = 'api_cache_time_';
  static const _kDefaultTtl = Duration(minutes: 15);
  static const _kLongTtl = Duration(hours: 1);

  bool get enabled => _enabled;
  bool get imagesEnabled => _imagesEnabled;

  Future<void> init() async {
    final saverVal = await _storage.read(key: _kDataSaverEnabled);
    final imagesVal = await _storage.read(key: _kImagesEnabled);
    _enabled = saverVal == 'true';
    _imagesEnabled = imagesVal == 'true';
  }

  Future<void> toggleDataSaver() async {
    _enabled = !_enabled;
    await _storage.write(key: _kDataSaverEnabled, value: _enabled.toString());
  }

  Future<void> toggleImages() async {
    _imagesEnabled = !_imagesEnabled;
    await _storage.write(key: _kImagesEnabled, value: _imagesEnabled.toString());
  }

  Future<void> cacheResponse(String endpoint, Map<String, dynamic> data) async {
    if (!_enabled) return;
    final key = _kCachePrefix + _sanitizeKey(endpoint);
    final timeKey = _kCacheTimePrefix + _sanitizeKey(endpoint);
    await _storage.write(key: key, value: jsonEncode(data));
    await _storage.write(key: timeKey, value: DateTime.now().toIso8601String());
  }

  Future<Map<String, dynamic>?> getCachedResponse(String endpoint) async {
    if (!_enabled) return null;
    final key = _kCachePrefix + _sanitizeKey(endpoint);
    final timeKey = _kCacheTimePrefix + _sanitizeKey(endpoint);
    final cached = await _storage.read(key: key);
    final cachedTime = await _storage.read(key: timeKey);
    if (cached == null || cachedTime == null) return null;
    final time = DateTime.tryParse(cachedTime);
    if (time == null) return null;
    final ttl = _isStaticEndpoint(endpoint) ? _kLongTtl : _kDefaultTtl;
    if (DateTime.now().difference(time) > ttl) {
      await clearCacheFor(endpoint);
      return null;
    }
    try {
      return jsonDecode(cached) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCacheFor(String endpoint) async {
    final key = _kCachePrefix + _sanitizeKey(endpoint);
    final timeKey = _kCacheTimePrefix + _sanitizeKey(endpoint);
    await _storage.delete(key: key);
    await _storage.delete(key: timeKey);
  }

  Future<void> clearAllCache() async {
    await _storage.deleteAll();
    await _storage.write(key: _kDataSaverEnabled, value: _enabled.toString());
    await _storage.write(key: _kImagesEnabled, value: _imagesEnabled.toString());
  }

  String getRequestBudgetInfo() {
    if (!_enabled) return 'Data saver off';
    return _imagesEnabled
        ? 'Data saver ON (images compressed)'
        : 'Data saver ON (images off)';
  }

  bool _isStaticEndpoint(String endpoint) {
    return endpoint.contains('/stem/') ||
        endpoint.contains('/courses/') ||
        endpoint.contains('/knowledge-vault') ||
        endpoint.contains('/formulas') ||
        endpoint.contains('/careers') ||
        endpoint.contains('/malawi');
  }

  String _sanitizeKey(String endpoint) {
    return endpoint.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }
}
