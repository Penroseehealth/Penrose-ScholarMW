import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../errors/app_exception.dart';

/// How long a single backend request may take before it is reported as
/// unreachable. Generous because TTS/STT calls can be slow.
const Duration _apiTimeout = Duration(seconds: 120);

/// One file attached to a multipart request.
class MultipartFilePart {
  MultipartFilePart({required this.name, required this.filename, required this.bytes, this.contentType});

  final String name;
  final String filename;
  final List<int> bytes;
  final String? contentType;
}

/// Thin HTTP client for the Penrose backend.
///
/// All API calls go through this class so features never construct HTTP
/// requests and the auth token (when a module adds it) is applied in one
/// place. Responses are decoded to `Map<String, dynamic>`.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? _authToken;

  set authToken(String? token) => _authToken = token;

  /// Resolves the session token on first use when no explicit [authToken]
  /// was set. Wired to the app's stored session by the router.
  Future<String?> Function()? tokenProvider;

  Future<void> _resolveToken() async {
    if (_authToken != null || tokenProvider == null) return;
    _authToken = await tokenProvider!();
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$baseUrl$normalized');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: query);
  }

  /// Resolves an API path to a playable absolute URL.
  ///
  /// Needed for streamed media such as a turn's stored audio, which a browser
  /// `<audio>` element fetches itself rather than through `http`.
  Uri mediaUri(String path) => _uri(path);

  Map<String, String> _headers({bool json = true, Map<String, String>? extra}) {
    return <String, String>{
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Per-request headers (e.g. an owner key) are added last so a caller can
      // never silently drop the transport-level content negotiation.
      ...?extra,
    };
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers, Map<String, String>? query}) =>
      _send('GET', path, body: null, extra: headers, query: query);

  /// GET returning the raw response body as text. Used by non-JSON endpoints
  /// such as the markdown review report that Copy Report copies verbatim, and
  /// by CSV downloads.
  Future<String> getText(String path, {Map<String, String>? headers, Map<String, String>? query}) async {
    await _resolveToken();
    final uri = _uri(path, query);
    final requestHeaders = _headers(json: false, extra: headers);
    try {
      final response = await _client.get(uri, headers: requestHeaders).timeout(_apiTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
      throw _toApiException(response.statusCode, _decode(response));
    } on TimeoutException {
      throw const NetworkUnavailableException('Backend timed out');
    } on http.ClientException catch (e) {
      throw NetworkUnavailableException('Cannot reach the backend (${e.message})');
    }
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) =>
      _send('POST', path, body: body, extra: headers);

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) =>
      _send('PUT', path, body: body, extra: headers);

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) =>
      _send('PATCH', path, body: body, extra: headers);

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) =>
      _send('DELETE', path, body: body, extra: headers);

  /// Multipart upload — used by documents, images, and audio.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? fields,
    List<MultipartFilePart>? files,
    Map<String, String>? headers,
  }) async {
    await _resolveToken();
    final request = http.MultipartRequest('POST', _uri(path));
    request.fields.addAll(fields ?? const <String, String>{});
    for (final part in files ?? const <MultipartFilePart>[]) {
      request.files.add(
        http.MultipartFile.fromBytes(
          part.name,
          part.bytes,
          filename: part.filename,
          contentType: part.contentType == null ? null : MediaType.parse(part.contentType!),
        ),
      );
    }
    if (_authToken != null) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }
    // Caller headers are honoured, except Content-Type: `http` has to own it
    // to write the multipart boundary, and an overwritten value would send a
    // body the server cannot parse.
    for (final entry in headers?.entries ?? const <String, String>{}.entries) {
      if (entry.key.toLowerCase() != 'content-type') {
        request.headers[entry.key] = entry.value;
      }
    }
    request.headers['Accept'] = 'application/json';
    try {
      final streamed = await _client.send(request).timeout(_apiTimeout);
      final response = await http.Response.fromStream(streamed);
      final decoded = _decode(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      throw _toApiException(response.statusCode, decoded);
    } on TimeoutException {
      throw const NetworkUnavailableException('Backend timed out');
    } on http.ClientException catch (e) {
      throw NetworkUnavailableException('Cannot reach the backend (${e.message})');
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? extra,
    Map<String, String>? query,
  }) async {
    await _resolveToken();
    final uri = _uri(path, query);
    final headers = _headers(json: body != null, extra: extra);

    try {
      final http.Response response;
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(_apiTimeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(_apiTimeout);
          break;
        case 'PUT':
          response = await _client.put(uri, headers: headers, body: jsonEncode(body)).timeout(_apiTimeout);
          break;
        case 'PATCH':
          response = await _client.patch(uri, headers: headers, body: jsonEncode(body)).timeout(_apiTimeout);
          break;
        default:
          response = await _client.post(uri, headers: headers, body: jsonEncode(body)).timeout(_apiTimeout);
      }

      final decoded = _decode(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      throw _toApiException(response.statusCode, decoded);
    } on TimeoutException {
      throw const NetworkUnavailableException('Backend timed out');
    } on http.ClientException catch (e) {
      throw NetworkUnavailableException('Cannot reach the backend (${e.message})');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is List) {
      return <String, dynamic>{'items': decoded};
    }
    return <String, dynamic>{'value': decoded};
  }

  ApiException _toApiException(int status, Map<String, dynamic> body) {
    // A busy conversation is its own type so the chat can keep the draft and
    // invite a retry instead of reporting a send failure.
    if (status == 409) {
      final busy = body['error'] ?? body['detail'];
      return ConflictException(
        busy is String && busy.isNotEmpty ? busy : 'Still working on your previous message — try again in a moment.',
      );
    }
    final detail = body['detail'];
    if (detail is String) {
      return ApiException(detail, code: (body['code'] as String?) ?? 'api_error', status: status);
    }
    if (detail is List) {
      final first = detail.isNotEmpty ? detail.first : null;
      final msg = first is Map<String, dynamic>
          ? ('${first['msg'] ?? 'Invalid request'} @ ${(first['loc'] as List?)?.join('.')}')
          : 'Invalid request';
      return ApiException(msg, code: 'validation_error', status: status);
    }
    // The backend's AppException handler answers with {ok, error, code,
    // details} rather than FastAPI's {detail}. Without this branch every
    // handled backend error reached the UI as a bare "Request failed (422)".
    final message = body['error'];
    if (message is String && message.isNotEmpty) {
      final rawDetails = body['details'];
      return ApiException(
        message,
        code: (body['code'] as String?) ?? 'api_error',
        status: status,
        details: rawDetails is Map<String, dynamic> ? rawDetails : body,
      );
    }
    return ApiException(
      'Request failed ($status)',
      code: (body['code'] as String?) ?? 'api_error',
      status: status,
      details: body,
    );
  }
}
