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

  Future<Map<String, dynamic>> chatWithStemTutor(int conceptId, String message, String mode, {List<Map<String, String>>? history}) async {
    final body = <String, dynamic>{
      'concept_id': conceptId,
      'message': message,
      'mode': mode,
    };
    if (history != null && history.isNotEmpty) {
      body['history'] = history;
    }
    final response = await _api.post('/stem/tutor/chat', body: body);
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

  // ── Subject Dashboard ──

  Future<Map<String, dynamic>> getSubjectDashboard(String slug) async {
    final response = await _api.get('/stem/subjects/$slug/dashboard');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<Map<String, dynamic>>> getSubjectModules() async {
    final response = await _api.get('/stem/subjects/modules');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  // ── Adaptive Learning ──

  Future<List<dynamic>> getDueReviews() async {
    final response = await _api.get('/stem/adaptive/due-reviews');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> getLearningPath(String slug) async {
    final response = await _api.get('/stem/adaptive/learning-path/$slug');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getStudySchedule() async {
    final response = await _api.get('/stem/adaptive/study-schedule');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Mock Exam ──

  Future<Map<String, dynamic>> startMockExam(String slug, {int numQuestions = 10}) async {
    final response = await _api.post('/stem/mock-exam/start', body: {
      'subject_slug': slug,
      'num_questions': numQuestions,
    });
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to start mock exam');
  }

  Future<Map<String, dynamic>> submitMockExam(int sessionId, List<Map<String, dynamic>> answers) async {
    final response = await _api.post('/stem/mock-exam/$sessionId/submit', body: {
      'answers': answers,
    });
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to submit mock exam');
  }

  Future<List<dynamic>> getMockExamHistory() async {
    final response = await _api.get('/stem/mock-exam/history');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // ── Group Sessions ──

  Future<Map<String, dynamic>> startGroupSession(int groupId, String title, {List<int>? conceptIds}) async {
    final body = <String, dynamic>{
      'group_id': groupId,
      'title': title,
    };
    if (conceptIds != null && conceptIds.isNotEmpty) {
      body['concept_ids'] = conceptIds;
    }
    final response = await _api.post('/stem/group-sessions/start', body: body);
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to start group session');
  }

  Future<Map<String, dynamic>> endGroupSession(int sessionId, {List<int>? conceptsStudied}) async {
    final body = <String, dynamic>{};
    if (conceptsStudied != null && conceptsStudied.isNotEmpty) {
      body['concepts_studied'] = conceptsStudied;
    }
    final response = await _api.post('/stem/group-sessions/$sessionId/end', body: body);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to end group session');
  }

  Future<Map<String, dynamic>> getGroupSession(int sessionId) async {
    final response = await _api.get('/stem/group-sessions/$sessionId');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getGroupSessions(int groupId) async {
    final response = await _api.get('/stem/group-sessions/group/$groupId');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> getGroupSessionStats(int groupId) async {
    final response = await _api.get('/stem/group-stats/$groupId');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  // ── Exam Analytics ──

  Future<Map<String, dynamic>> getExamSummary() async {
    final response = await _api.get('/stem/analytics/exam-summary');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getExamTrends(String slug) async {
    final response = await _api.get('/stem/analytics/exam-trends/$slug');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> getExamBreakdown(int resultId) async {
    final response = await _api.get('/stem/analytics/exam-breakdown/$resultId');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }

  // ── Study Planner ──

  Future<Map<String, dynamic>> generateStudyPlan(String slug, {int dailyMinutes = 60, int daysAhead = 14}) async {
    final response = await _api.post('/stem/study-planner/generate', body: {
      'subject_slug': slug,
      'daily_minutes': dailyMinutes,
      'days_ahead': daysAhead,
    });
    if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body);
    return {};
  }

  Future<List<dynamic>> getDailyStudyPlan() async {
    final response = await _api.get('/stem/study-planner/today');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<Map<String, dynamic>> getStudyPlanOverview() async {
    final response = await _api.get('/stem/study-planner/overview');
    if (response.statusCode == 200) return jsonDecode(response.body);
    return {};
  }
}
