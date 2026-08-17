import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  String? _accessToken;
  String? _refreshToken;

  Future<Map<String, String>> get headers async {
    if (_accessToken == null) {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
    }
    return {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  Future<void> setTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }

  Future<http.Response> get(String path) async {
    final h = await headers;
    final response = await http.get(Uri.parse('$apiBaseUrl$path'), headers: h);
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return http.get(Uri.parse('$apiBaseUrl$path'), headers: await headers);
      }
    }
    return response;
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final h = await headers;
    final response = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: h,
      body: body != null ? jsonEncode(body) : null,
    );
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return http.post(
          Uri.parse('$apiBaseUrl$path'),
          headers: await headers,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    final h = await headers;
    return http.put(
      Uri.parse('$apiBaseUrl$path'),
      headers: h,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> delete(String path) async {
    final h = await headers;
    return http.delete(Uri.parse('$apiBaseUrl$path'), headers: h);
  }

  Future<bool> _tryRefresh() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setTokens(data['access_token'], data['refresh_token']);
        return true;
      }
      await clearTokens();
      return false;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  Future<http.StreamedResponse> postStream(String path, {Map<String, dynamic>? body}) async {
    final h = await headers;
    final request = http.Request('POST', Uri.parse('$apiBaseUrl$path'));
    request.headers.addAll(h);
    if (body != null) request.body = jsonEncode(body);
    return await http.Client().send(request);
  }
}
