import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  const defined = String.fromEnvironment('API_BASE_URL');
  if (defined.isNotEmpty) return defined;
  // Dev: talk to the local backend directly. Release builds keep the relative path.
  if (kDebugMode) return 'http://localhost:8000/api/v1';
  return '/api/v1';
}

const String appName = 'Penrose ScholarMw';
const String appTagline = 'Learn. Teach. Research. Advance.';
