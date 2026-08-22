import 'dart:convert';

import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final data = jsonDecode(response.body);
      await _api.setTokens(data['access_token'], data['refresh_token']);
      return {'success': true, 'user': data['user']};
    }
    try {
      if (response.body.isNotEmpty) {
        return {'success': false, 'error': jsonDecode(response.body)['detail'] ?? 'Login failed'};
      }
    } catch (_) {}
    return {'success': false, 'error': 'Login failed'};
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String role = 'student',
    String? institution,
    String? department,
    String? studentId,
    int? yearOfStudy,
  }) async {
    final response = await _api.post('/auth/register', body: {
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role,
      'institution': institution,
      'department': department,
      'student_id': studentId,
      'year_of_study': yearOfStudy,
    });
    if (response.statusCode == 201 && response.body.isNotEmpty) {
      final data = jsonDecode(response.body);
      await _api.setTokens(data['access_token'], data['refresh_token']);
      return {'success': true, 'user': data['user']};
    }
    try {
      if (response.body.isNotEmpty) {
        return {'success': false, 'error': jsonDecode(response.body)['detail'] ?? 'Registration failed'};
      }
    } catch (_) {}
    return {'success': false, 'error': 'Registration failed'};
  }

  Future<void> logout() async {
    await _api.clearTokens();
  }

  Future<Map<String, dynamic>?> getMe() async {
    final response = await _api.get('/auth/me');
    if (response.statusCode == 200 && response.body.isNotEmpty) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<bool> isAuthenticated() async {
    return _api.hasToken();
  }
}
