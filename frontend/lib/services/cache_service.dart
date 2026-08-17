import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  Future<void> cacheList(
    String key,
    List<Map<String, dynamic>> data, {
    Duration ttl = const Duration(hours: 1),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheEntry = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl.inMilliseconds,
    };
    await prefs.setString('cache_$key', jsonEncode(cacheEntry));
  }

  Future<List<Map<String, dynamic>>?> getCachedList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cache_$key');
    if (raw == null) return null;
    final entry = jsonDecode(raw);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(entry['timestamp']);
    if (DateTime.now().difference(timestamp).inMilliseconds > entry['ttl']) {
      await prefs.remove('cache_$key');
      return null;
    }
    return List<Map<String, dynamic>>.from(entry['data']);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cache_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_$key');
  }
}
