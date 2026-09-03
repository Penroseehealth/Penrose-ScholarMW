String get apiBaseUrl {
  const defined = String.fromEnvironment('API_BASE_URL');
  if (defined.isNotEmpty) return defined;
  return '/api/v1';
}

const String appName = 'Penrose ScholarMw';
const String appTagline = 'Learn. Teach. Research. Advance.';
