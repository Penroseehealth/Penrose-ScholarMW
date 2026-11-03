import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(String baseUrl, {http.Client? client})
    : baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (baseUrl.isEmpty) throw const ApiException('Set an API base URL first.');
    try {
      final uri = _uri(path);
      final request = http.Request(method, uri)
        ..headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 12));
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map<String, dynamic>
            ? decoded['detail']
            : null;
        throw ApiException(
          detail is String
              ? detail
              : detail is Map<String, dynamic>
              ? (detail['message'] as String? ?? 'Request failed.')
              : 'Request failed (${response.statusCode}).',
        );
      }
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{'items': decoded};
    } on ApiException {
      rethrow;
    } on FormatException catch (error) {
      throw ApiException('The API returned invalid JSON: ${error.message}');
    } on Exception catch (error) {
      throw ApiException('Could not reach $baseUrl: $error');
    }
  }

  Future<Map<String, dynamic>> checkHealth() => _request('GET', '/api/health');

  Future<Map<String, dynamic>> generateMap(Map<String, dynamic> config) =>
      _request('POST', '/api/maps/generate', body: {'config': config});

  Future<List<Map<String, dynamic>>> listMaps() async {
    final response = await _request('GET', '/api/maps');
    final items = response['items'];
    if (items is! List)
      throw const ApiException('Invalid map library response.');
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getMap(String id) =>
      _request('GET', '/api/maps/$id');

  Future<Map<String, dynamic>> createMap({
    required String name,
    required Map<String, dynamic> config,
    required List<dynamic> annotations,
  }) => _request(
    'POST',
    '/api/maps',
    body: {'name': name, 'config': config, 'annotations': annotations},
  );

  Future<Map<String, dynamic>> updateMap(
    String id, {
    required String name,
    required Map<String, dynamic> config,
    required List<dynamic> annotations,
  }) => _request(
    'PUT',
    '/api/maps/$id',
    body: {'name': name, 'config': config, 'annotations': annotations},
  );

  Future<void> deleteMap(String id) async {
    await _request('DELETE', '/api/maps/$id');
  }

  Future<String> createPngExport(String id, String dataUrl) async {
    final response = await _request(
      'POST',
      '/api/maps/$id/exports/png',
      body: {'data_url': dataUrl},
    );
    final path = response['download_url'];
    if (path is! String) throw const ApiException('Invalid export response.');
    return '$baseUrl$path';
  }

  void close() => _client.close();
}
