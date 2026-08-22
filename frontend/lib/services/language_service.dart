import 'dart:convert';
import 'api_service.dart';

class LanguageService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> getLanguages() async {
    final response = await _api.get('/languages');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> getLanguage(String slug) async {
    final response = await _api.get('/languages/$slug');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> getLanguageTree(String slug) async {
    final response = await _api.get('/languages/$slug/tree');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  // ── Levels / Units / Lessons ──

  Future<List<dynamic>> getLevels(String slug) async {
    final response = await _api.get('/languages/$slug/levels');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> getLevel(String slug, String levelSlug) async {
    final response = await _api.get('/languages/$slug/levels/$levelSlug');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> getUnit(int unitId) async {
    final response = await _api.get('/languages/units/$unitId');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> getLesson(int lessonId) async {
    final response = await _api.get('/languages/lessons/$lessonId');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  // ── Vocabulary ──

  Future<List<dynamic>> getVocabulary(String slug, {String? theme, String? difficulty, int? limit}) async {
    final params = <String>[];
    if (theme != null && theme.isNotEmpty) params.add('theme=$theme');
    if (difficulty != null && difficulty.isNotEmpty) params.add('difficulty=$difficulty');
    if (limit != null) params.add('limit=$limit');
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await _api.get('/languages/$slug/vocabulary$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getVocabularyThemes(String slug) async {
    final response = await _api.get('/languages/$slug/vocabulary/themes');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Grammar ──

  Future<List<dynamic>> getGrammar(String slug, {String? category}) async {
    final qs = category != null && category.isNotEmpty ? '?category=$category' : '';
    final response = await _api.get('/languages/$slug/grammar$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getGrammarCategories(String slug) async {
    final response = await _api.get('/languages/$slug/grammar/categories');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Analytics / Placement / Search ──

  Future<Map<String, dynamic>> getAnalytics(String slug, int userId) async {
    final response = await _api.get('/languages/$slug/analytics/$userId');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> startPlacement(int userId, int languageId) async {
    final response = await _api.post('/languages/placement/start', body: {
      'user_id': userId,
      'language_id': languageId,
    });
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> searchLanguages(String query) async {
    final response = await _api.get('/languages/search?q=$query');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }
}
