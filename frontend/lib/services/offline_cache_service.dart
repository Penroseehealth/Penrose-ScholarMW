import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  static OfflineCacheService? _instance;
  late SharedPreferences _prefs;

  OfflineCacheService._();

  factory OfflineCacheService() {
    _instance ??= OfflineCacheService._();
    return _instance!;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static const _prefix = 'offline_';
  static const _timestampPrefix = '${_prefix}ts_';

  Future<void> cacheJson(String key, dynamic data, {Duration ttl = const Duration(days: 7)}) async {
    final encoded = jsonEncode(data);
    await _prefs.setString('$_prefix$key', encoded);
    await _prefs.setInt('$_prefix${_timestampPrefix}$key', DateTime.now().millisecondsSinceEpoch);
  }

  T? getJson<T>(String key, {Duration ttl = const Duration(days: 7)}) {
    final ts = _prefs.getInt('$_prefix${_timestampPrefix}$key');
    if (ts == null) return null;
    if (DateTime.now().millisecondsSinceEpoch - ts > ttl.inMilliseconds) {
      remove(key);
      return null;
    }
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as T;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    await _prefs.remove('$_prefix$key');
    await _prefs.remove('$_prefix${_timestampPrefix}$key');
  }

  Future<void> cacheSyllabus(String subjectSlug, String yearLevel, dynamic data) async {
    await cacheJson('syllabus_${subjectSlug}_$yearLevel', data, ttl: const Duration(days: 30));
  }

  dynamic getSyllabus(String subjectSlug, String yearLevel) {
    return getJson('syllabus_${subjectSlug}_$yearLevel', ttl: const Duration(days: 30));
  }

  Future<void> cacheFormulas(List<dynamic> formulas) async {
    await cacheJson('formulas', formulas, ttl: const Duration(days: 14));
  }

  List<dynamic>? getFormulas() {
    return getJson<List<dynamic>>('formulas', ttl: const Duration(days: 14));
  }

  Future<void> cacheChatHistory(int sessionId, List<Map<String, dynamic>> messages) async {
    await cacheJson('chat_$sessionId', messages, ttl: const Duration(days: 3));
  }

  List<Map<String, dynamic>>? getChatHistory(int sessionId) {
    final raw = getJson('chat_$sessionId', ttl: const Duration(days: 3));
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    return null;
  }

  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    await cacheJson('user_profile', profile, ttl: const Duration(days: 1));
  }

  Map<String, dynamic>? getUserProfile() {
    return getJson<Map<String, dynamic>>('user_profile', ttl: const Duration(days: 1));
  }

  Future<int> getCacheSize() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix));
    int totalBytes = 0;
    for (final key in keys) {
      final val = _prefs.get(key);
      if (val is String) totalBytes += val.length * 2;
    }
    return totalBytes;
  }

  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}
