import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import 'cache_service.dart';
import 'data_saver_service.dart';
import 'safe_secure_storage.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  static const _secureStorage = SafeSecureStorage();

  String? _accessToken;
  String? _refreshToken;

  /// Mutex to prevent concurrent refresh token requests.
  Completer<void>? _refreshMutex;

  /// Called when refresh fails permanently (all tokens cleared).
  /// AuthProvider should set this to force-redirect to login.
  VoidCallback? onAuthExpired;

  Future<Map<String, String>> get headers async {
    final token = await accessToken;
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  /// The session access token, loaded from secure storage on first use.
  /// Also used to authenticate clients that build their own requests, such as
  /// the Voice Training Center's [ApiClient].
  Future<String?> get accessToken async {
    if (_accessToken == null) {
      _accessToken = await _secureStorage.read(key: 'access_token');
      _refreshToken = await _secureStorage.read(key: 'refresh_token');
    }
    return _accessToken;
  }

  Future<void> setTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    await _secureStorage.write(key: 'access_token', value: access);
    await _secureStorage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
  }

  Future<bool> hasToken() async {
    final token = await _secureStorage.read(key: 'access_token');
    return token != null;
  }

  Future<http.Response> get(String path) async {
    final saver = DataSaverService();
    if (saver.enabled) {
      final cached = await saver.getCachedResponse(path);
      if (cached != null) {
        return http.Response(jsonEncode(cached), 200);
      }
    }
    final h = await headers;
    final response = await http.get(Uri.parse('$apiBaseUrl$path'), headers: h);
    if (response.statusCode == 200 && saver.enabled) {
      try {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          await saver.cacheResponse(path, data);
        }
      } catch (_) {}
    }
    if (_isAuthFailure(response.statusCode) && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return http.get(Uri.parse('$apiBaseUrl$path'), headers: await headers);
      }
    }
    return response;
  }

  Future<http.Response?> getWithCache(String path, {Duration cacheTtl = const Duration(hours: 1)}) async {
    try {
      final response = await get(path);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          await CacheService().cacheList(
            path,
            List<Map<String, dynamic>>.from(data.map((e) => e as Map)),
            ttl: cacheTtl,
          );
        }
        return response;
      }
    } catch (_) {}
    final cached = await CacheService().getCachedList(path);
    if (cached != null) {
      return http.Response(jsonEncode(cached), 200);
    }
    return null;
  }

  Future<http.Response> post(String path, {Map<String, dynamic>? body}) async {
    final h = await headers;
    final response = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: h,
      body: body != null ? jsonEncode(body) : null,
    );
    if (_isAuthFailure(response.statusCode) && _refreshToken != null) {
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

  /// Whether a status means the bearer token was missing or no longer valid.
  ///
  /// FastAPI's `HTTPBearer` replies 403 ("Not authenticated") when the
  /// `Authorization` header is absent and 401 when the token is present but
  /// expired or invalid. Both are recovered the same way: refresh, then retry.
  static bool _isAuthFailure(int statusCode) => statusCode == 401 || statusCode == 403;

  Future<http.Response> put(String path, {Map<String, dynamic>? body}) async {
    final h = await headers;
    var response = await http.put(
      Uri.parse('$apiBaseUrl$path'),
      headers: h,
      body: body != null ? jsonEncode(body) : null,
    );
    if (_isAuthFailure(response.statusCode) && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        response = await http.put(
          Uri.parse('$apiBaseUrl$path'),
          headers: await headers,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    return response;
  }

  Future<http.Response> delete(String path) async {
    final h = await headers;
    var response = await http.delete(Uri.parse('$apiBaseUrl$path'), headers: h);
    if (_isAuthFailure(response.statusCode) && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        response = await http.delete(Uri.parse('$apiBaseUrl$path'), headers: await headers);
      }
    }
    return response;
  }

  /// Downloads a protected file as raw bytes (with auth + 401 refresh).
  /// On the web this lets the caller build a Blob URL so the file can be
  /// opened in a new tab without exposing the bearer token in the URL.
  Future<Uint8List?> downloadBytes(String path) async {
    var h = await headers;
    final uri = Uri.parse('$apiBaseUrl$path');
    var response = await http.get(uri, headers: h);
    if (_isAuthFailure(response.statusCode) && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        h = await headers;
        response = await http.get(uri, headers: h);
      }
    }
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  Future<bool> _tryRefresh() async {
    // If a refresh is already in progress, wait for it to complete.
    if (_refreshMutex != null) {
      await _refreshMutex!.future;
      return _accessToken != null;
    }

    _refreshMutex = Completer<void>();
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await setTokens(data['access_token'] as String, data['refresh_token'] as String);
        return true;
      }
      await clearTokens();
      onAuthExpired?.call();
      return false;
    } catch (_) {
      await clearTokens();
      onAuthExpired?.call();
      return false;
    } finally {
      _refreshMutex!.complete();
      _refreshMutex = null;
    }
  }

  Future<http.Response> uploadFile(
    String path,
    String filePath,
    String filename, {
    Map<String, String>? fields,
    void Function(int, int)? onProgress,
  }) async {
    final request = await _buildMultipart(path, fields);
    request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename));
    return _sendMultipart(request, path, onProgress);
  }

  Future<http.Response> uploadFileBytes(
    String path,
    List<int> bytes,
    String filename, {
    Map<String, String>? fields,
    void Function(int, int)? onProgress,
  }) async {
    final request = await _buildMultipart(path, fields);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    return _sendMultipart(request, path, onProgress);
  }

  Future<http.MultipartRequest> _buildMultipart(String path, Map<String, String>? fields) async {
    final h = await headers;
    final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl$path'));
    request.headers.addAll(h);
    request.headers.remove('Content-Type');
    if (fields != null) request.fields.addAll(fields);
    return request;
  }

  /// Sends a multipart request with optional upload progress and 401
  /// refresh-token retry (mirroring the JSON helpers).
  Future<http.Response> _sendMultipart(
    http.MultipartRequest request,
    String path,
    void Function(int, int)? onProgress,
  ) async {
    final response = onProgress == null ? await request.send() : await _sendWithProgress(request, onProgress);
    var parsed = await http.Response.fromStream(response);
    if (_isAuthFailure(parsed.statusCode) && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retry = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl$path'))
          ..fields.addAll(request.fields)
          ..files.addAll(request.files)
          ..headers.addAll(await headers)
          ..headers.remove('Content-Type');
        final retried = onProgress == null ? await retry.send() : await _sendWithProgress(retry, onProgress);
        parsed = await http.Response.fromStream(retried);
      }
    }
    return parsed;
  }

  /// Sends a multipart request and reports upload progress by intercepting the
  /// finalized byte stream. The server receives the exact multipart body; an
  /// extra header is added so the server knows how many bytes to read.
  Future<http.StreamedResponse> _sendWithProgress(
    http.MultipartRequest request,
    void Function(int, int) onProgress,
  ) async {
    final total = request.contentLength;
    final byteStream = http.ByteStream(request.finalize());
    var sent = 0;
    final progressStream = http.ByteStream(
      byteStream.map((chunk) {
        sent += chunk.length;
        onProgress(sent, total);
        return chunk;
      }),
    );
    final streamed = http.StreamedRequest('POST', request.url)
      ..contentLength = total
      ..headers.addAll(request.headers);
    progressStream.pipe(streamed.sink);
    final resp = await http.Client().send(streamed);
    if (total > 0) onProgress(total, total);
    return resp;
  }

  Future<http.StreamedResponse> postStream(String path, {Map<String, dynamic>? body}) async {
    final h = await headers;
    final request = http.Request('POST', Uri.parse('$apiBaseUrl$path'));
    request.headers.addAll(h);
    if (body != null) request.body = jsonEncode(body);
    var response = await http.Client().send(request);
    if (_isAuthFailure(response.statusCode) && _refreshToken != null) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retryReq = http.Request('POST', Uri.parse('$apiBaseUrl$path'));
        retryReq.headers.addAll(await headers);
        if (body != null) retryReq.body = jsonEncode(body);
        response = await http.Client().send(retryReq);
      }
    }
    return response;
  }
}
