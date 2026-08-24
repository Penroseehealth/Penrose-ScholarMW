import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;
  String get userRole => (_user?['role'] ?? 'student') as String;
  String get userName => (_user?['full_name'] ?? '') as String;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      final me = await _authService.getMe();
      if (me != null) {
        _user = me;
        _isLoading = false;
        notifyListeners();
        return;
      }
      final result = await _authService.login('student@scholar.mw', 'student123');
      if (result['success'] == true) {
        _user = result['user'] as Map<String, dynamic>?;
      }
    } catch (_) {
      // Auto-login failed — stay unauthenticated
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.login(email, password);
    _isLoading = false;

    if (result['success'] == true) {
      _user = result['user'] as Map<String, dynamic>?;
      notifyListeners();
      return true;
    } else {
      _error = result['error'] as String?;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    String role = 'student',
    String? institution,
    String? department,
    String? studentId,
    int? yearOfStudy,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.register(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
      institution: institution,
      department: department,
      studentId: studentId,
      yearOfStudy: yearOfStudy,
    );
    _isLoading = false;

    if (result['success'] == true) {
      _user = result['user'] as Map<String, dynamic>?;
      notifyListeners();
      return true;
    } else {
      _error = result['error'] as String?;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }
}
