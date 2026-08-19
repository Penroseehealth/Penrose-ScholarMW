import 'dart:convert';
import 'api_service.dart';

class StemService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> getSubjects() async {
    final response = await _api.get('/stem/subjects');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>?> getSubject(String slug) async {
    final response = await _api.get('/stem/subjects/$slug');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<List<dynamic>> getDisciplines(String slug) async {
    final response = await _api.get('/stem/subjects/$slug/disciplines');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getTopics(int disciplineId) async {
    final response = await _api.get('/stem/disciplines/$disciplineId/topics');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getSubtopics(int topicId) async {
    final response = await _api.get('/stem/topics/$topicId/subtopics');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getConcepts(int subtopicId) async {
    final response = await _api.get('/stem/subtopics/$subtopicId/concepts');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>?> getConcept(int id) async {
    final response = await _api.get('/stem/concepts/$id');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<List<dynamic>> getObjectives(int conceptId) async {
    final response = await _api.get('/stem/concepts/$conceptId/objectives');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getMaterials(int conceptId) async {
    final response = await _api.get('/stem/concepts/$conceptId/materials');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getPractices(int conceptId) async {
    final response = await _api.get('/stem/concepts/$conceptId/practices');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> submitMastery(int conceptId, bool correct) async {
    final response = await _api.post('/stem/mastery', body: {
      'concept_id': conceptId,
      'correct': correct,
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getTree() async {
    final response = await _api.get('/stem/tree');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> search(String query) async {
    final response = await _api.get('/stem/search?q=$query');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Knowledge Graph ──

  Future<List<dynamic>> getKnowledgeGraph(String slug) async {
    final response = await _api.get('/stem/knowledge-graph/subject/$slug');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getConceptConnections(int conceptId) async {
    final response = await _api.get('/stem/knowledge-graph/concept/$conceptId');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Formulas ──

  Future<List<dynamic>> getFormulas({String? subjectSlug, String? category, String? query}) async {
    final params = <String>[];
    if (subjectSlug != null && subjectSlug.isNotEmpty) params.add('subject_slug=$subjectSlug');
    if (category != null && category.isNotEmpty) params.add('category=$category');
    if (query != null && query.isNotEmpty) params.add('q=$query');
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await _api.get('/stem/formulas$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getFormulaCategories(String subjectSlug) async {
    final response = await _api.get('/stem/formulas/categories/$subjectSlug');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Careers ──

  Future<List<dynamic>> getCareers({String? subjectSlug}) async {
    final qs = subjectSlug != null && subjectSlug.isNotEmpty ? '?subject_slug=$subjectSlug' : '';
    final response = await _api.get('/stem/careers$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Labs ──

  Future<List<dynamic>> getLabs({String? subjectSlug, String? labType}) async {
    final params = <String>[];
    if (subjectSlug != null && subjectSlug.isNotEmpty) params.add('subject_slug=$subjectSlug');
    if (labType != null && labType.isNotEmpty) params.add('lab_type=$labType');
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await _api.get('/stem/labs$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Mastery Dashboard ──

  Future<Map<String, dynamic>> getMasteryDashboard() async {
    final response = await _api.get('/stem/mastery/dashboard');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getMasteryRecommendations() async {
    final response = await _api.get('/stem/mastery/recommendations');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> completeRecommendation(int id) async {
    final response = await _api.post('/stem/mastery/recommendations/$id/complete');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  // ── STEM Tutor ──

  Future<Map<String, dynamic>> chatWithStemTutor(int conceptId, String message, String mode) async {
    final response = await _api.post('/stem/tutor/chat', body: {
      'concept_id': conceptId,
      'message': message,
      'mode': mode,
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {'response': 'Failed to get response. Please try again.'};
  }

  Future<List<dynamic>> getTutorModes() async {
    final response = await _api.get('/stem/tutor/modes');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Assessment ──

  Future<Map<String, dynamic>> generateAssessment(String type, int conceptId, int numQuestions, String difficulty) async {
    final response = await _api.post('/stem/assessment/generate', body: {
      'type': type,
      'concept_id': conceptId,
      'num_questions': numQuestions,
      'difficulty': difficulty,
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> submitAssessment(String type, int conceptId, List<Map<String, dynamic>> answers) async {
    final response = await _api.post('/stem/assessment/submit', body: {
      'type': type,
      'concept_id': conceptId,
      'answers': answers,
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getAssessmentHistory() async {
    final response = await _api.get('/stem/assessment/history');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Revision Tools ──

  Future<List<dynamic>> getFlashcards({int? conceptId}) async {
    final qs = conceptId != null ? '?concept_id=$conceptId' : '';
    final response = await _api.get('/stem/revision/flashcards$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> createFlashcard(int conceptId, String front, String back, String difficulty) async {
    final response = await _api.post('/stem/revision/flashcards', body: {
      'concept_id': conceptId,
      'front': front,
      'back': back,
      'difficulty': difficulty,
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> reviewFlashcard(int id, int quality) async {
    final response = await _api.post('/stem/revision/flashcards/$id/review', body: {
      'quality': quality,
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getDueFlashcards() async {
    final response = await _api.get('/stem/revision/flashcards/due');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getStudyPlans() async {
    final response = await _api.get('/stem/revision/plans');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> createStudyPlan(String title, String? description, String? subjectSlug) async {
    final response = await _api.post('/stem/revision/plans', body: {
      'title': title,
      'description': description,
      'subject_slug': subjectSlug,
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> getStudyPlanDetail(int id) async {
    final response = await _api.get('/stem/revision/plans/$id');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> completePlanItem(int planId, int itemId) async {
    final response = await _api.post('/stem/revision/plans/$planId/items/$itemId/complete');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  // ── Malawi STEM ──

  Future<Map<String, dynamic>> getMalawiStats() async {
    final response = await _api.get('/stem/malawi/stats');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getMalawiExamples({int? conceptId}) async {
    final qs = conceptId != null ? '?concept_id=$conceptId' : '';
    final response = await _api.get('/stem/malawi/examples$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getMalawiCurriculum({int? conceptId, String? formLevel}) async {
    final params = <String>[];
    if (conceptId != null) params.add('concept_id=$conceptId');
    if (formLevel != null && formLevel.isNotEmpty) params.add('form_level=$formLevel');
    final qs = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await _api.get('/stem/malawi/curriculum$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Analytics ──

  Future<Map<String, dynamic>> getStudySummary() async {
    final response = await _api.get('/stem/analytics/study-summary');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getSubjectComparison() async {
    final response = await _api.get('/stem/analytics/subject-comparison');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getWeakestConcepts() async {
    final response = await _api.get('/stem/analytics/weakest-concepts');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getHeatmap() async {
    final response = await _api.get('/stem/analytics/heatmap');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Study Groups ──

  Future<List<dynamic>> getStudyGroups({String? subjectSlug}) async {
    final qs = subjectSlug != null && subjectSlug.isNotEmpty ? '?subject_slug=$subjectSlug' : '';
    final response = await _api.get('/stem/groups$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getMyGroups() async {
    final response = await _api.get('/stem/groups/mine');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>?> getGroupDetail(int id) async {
    final response = await _api.get('/stem/groups/$id');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<Map<String, dynamic>> createStudyGroup(String name, String? description, String? subjectSlug) async {
    final response = await _api.post('/stem/groups', body: {
      'name': name,
      'description': description,
      'subject_slug': subjectSlug,
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> joinGroup(int id) async {
    final response = await _api.post('/stem/groups/$id/join');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getGroupMessages(int groupId) async {
    final response = await _api.get('/stem/groups/$groupId/messages');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> sendGroupMessage(int groupId, String message) async {
    final response = await _api.post('/stem/groups/$groupId/messages', body: {'message': message});
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  // ── Gamification ──

  Future<List<dynamic>> getBadges({String? category}) async {
    final qs = category != null && category.isNotEmpty ? '?category=$category' : '';
    final response = await _api.get('/stem/gamification/badges$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getEarnedBadges() async {
    final response = await _api.get('/stem/gamification/badges/earned');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getLeaderboard({String? subjectSlug}) async {
    final qs = subjectSlug != null && subjectSlug.isNotEmpty ? '?subject_slug=$subjectSlug' : '';
    final response = await _api.get('/stem/gamification/leaderboard$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getChallenges({String? type}) async {
    final qs = type != null && type.isNotEmpty ? '?challenge_type=$type' : '';
    final response = await _api.get('/stem/gamification/challenges$qs');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> joinChallenge(int id) async {
    final response = await _api.post('/stem/gamification/challenges/$id/join');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> getStreak() async {
    final response = await _api.get('/stem/gamification/streak');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<Map<String, dynamic>> getPoints() async {
    final response = await _api.get('/stem/gamification/points');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }
}
