import 'dart:convert';
import 'api_service.dart';

export 'api_service.dart';
export 'cache_service.dart';
export 'stem_service.dart';

class CourseService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> listCourses() async {
    final response = await _api.getWithCache('/courses/');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getCourse(int id) async {
    final response = await _api.get('/courses/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>> enroll(int courseId) async {
    final response = await _api.post('/courses/$courseId/enroll');
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': jsonDecode(response.body)['detail'] ?? 'Enrollment failed'};
  }

  Future<List<dynamic>> getSchedule(int courseId) async {
    final response = await _api.get('/courses/$courseId/schedule');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }
}

class AiService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> chat({
    required String message,
    int? sessionId,
    String agentType = 'tutor',
    int? contextCourseId,
  }) async {
    final response = await _api.post('/ai/chat', body: {
      'message': message,
      'session_id': sessionId,
      'agent_type': agentType,
      'context_course_id': contextCourseId,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to get response'};
  }

  Future<List<dynamic>> listSessions() async {
    final response = await _api.get('/ai/sessions');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getSession(int id) async {
    final response = await _api.get('/ai/sessions/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  Future<Map<String, dynamic>> generateLessonPlan({
    required String topic,
    required String level,
    int durationMinutes = 90,
  }) async {
    final response = await _api.post('/ai/lesson-plan', body: {
      'topic': topic,
      'level': level,
      'duration_minutes': durationMinutes,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to generate lesson plan'};
  }

  Future<Map<String, dynamic>> generateAssessment({
    required int courseId,
    required String topic,
    int numQuestions = 10,
    String difficulty = 'medium',
    List<String> questionTypes = const ['mcq', 'short_answer'],
  }) async {
    final response = await _api.post('/ai/generate-assessment', body: {
      'course_id': courseId,
      'topic': topic,
      'num_questions': numQuestions,
      'difficulty': difficulty,
      'question_types': questionTypes,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to generate assessment'};
  }

  Future<Map<String, dynamic>> generateStudyPlan({
    required int courseId,
    String? examDate,
    double hoursPerDay = 2.0,
  }) async {
    final response = await _api.post('/ai/study-plan', body: {
      'course_id': courseId,
      'exam_date': examDate,
      'hours_per_day': hoursPerDay,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to generate study plan'};
  }

  Future<Map<String, dynamic>> analyzeData({
    required String csvText,
    String question = '',
  }) async {
    final response = await _api.post('/ai/data-analysis', body: {
      'csv_text': csvText,
      'question': question,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to analyze data'};
  }

  Future<Map<String, dynamic>> runCode({
    required String code,
    String language = 'python',
  }) async {
    final response = await _api.post('/ai/coding-playground', body: {
      'code': code,
      'language': language,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to run code'};
  }
}

class NotificationService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> listNotifications() async {
    final response = await _api.get('/notifications/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<int> unreadCount() async {
    final response = await _api.get('/notifications/unread-count');
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['count'] ?? 0;
    }
    return 0;
  }

  Future<void> markAllRead() async {
    await _api.post('/notifications/mark-all-read');
  }
}

class ResearchService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> listProjects() async {
    final response = await _api.get('/research/projects');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> createProject(Map<String, dynamic> body) async {
    final response = await _api.post('/research/projects', body: body);
    if (response.statusCode == 201) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Failed to create project'};
  }

  Future<List<dynamic>> searchLiterature(String query, {int maxResults = 10}) async {
    final response = await _api.post('/research/literature-search', body: {
      'query': query,
      'max_results': maxResults,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }
}

class AssessmentService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> listAssessments(int courseId) async {
    final response = await _api.get('/assessments/course/$courseId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  Future<Map<String, dynamic>> submit(int assessmentId, String answers) async {
    final response = await _api.post('/assessments/submit', body: {
      'assessment_id': assessmentId,
      'answers': answers,
    });
    if (response.statusCode == 201) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': 'Submission failed'};
  }
}
