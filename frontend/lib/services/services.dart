import 'dart:convert';

import 'api_service.dart';

export 'api_service.dart';
export 'cache_service.dart';
export 'connectivity_manager.dart';
export 'context_service.dart';
export 'data_saver_service.dart';
export 'livekit_service.dart';
export 'stem_service.dart';
export 'streaming_chat_service.dart';
export 'voice_conversation_service.dart';

String _extractError(dynamic response, String fallback) {
  try {
    if ((response.body as String).isEmpty) return fallback;
    final body = jsonDecode(response.body as String) as Map<String, dynamic>;
    return (body['detail'] ?? body['error'] ?? body['message'] ?? fallback) as String;
  } catch (_) {
    return fallback;
  }
}

class OcrService {
  final ApiService _api = ApiService();

  /// Upload a scan (image/PDF) and extract text via OCR.
  Future<Map<String, dynamic>> scanFile(List<int> bytes, String filename) async {
    try {
      final response = await _api.uploadFileBytes('/ocr/scan', bytes, filename);
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Scan failed')};
    } catch (e) {
      return {'success': false, 'error': 'Scan failed: $e'};
    }
  }

  /// Ask the AI to analyse already-extracted text.
  Future<Map<String, dynamic>> analyzeText(
    String text, {
    String filename = 'document',
    String? question,
    String? language,
  }) async {
    try {
      final response = await _api.post(
        '/ocr/analyze',
        body: {
          'filename': filename,
          'text': text,
          if (question != null && question.trim().isNotEmpty) 'question': question.trim(),
          if (language != null && language.trim().isNotEmpty) 'language': language.trim(),
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Analysis failed')};
    } catch (e) {
      return {'success': false, 'error': 'Analysis failed: $e'};
    }
  }
}

class PresentationBuilderService {
  final ApiService _api = ApiService();

  /// Upload a source file and get its extracted text back with a source label.
  Future<Map<String, dynamic>> uploadSource(
    List<int> bytes,
    String filename,
    String label,
  ) async {
    try {
      final response = await _api.uploadFileBytes(
        '/presentations/upload',
        bytes,
        filename,
        fields: {'label': label},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Upload failed')};
    } catch (e) {
      return {'success': false, 'error': 'Upload failed: $e'};
    }
  }

  /// Build the presentation outline from the configuration + source text.
  Future<Map<String, dynamic>> buildOutline(Map<String, dynamic> config) async {
    try {
      final response = await _api.post(
        '/presentations/outline',
        body: {'config': config},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Outline failed')};
    } catch (e) {
      return {'success': false, 'error': 'Outline failed: $e'};
    }
  }

  /// Generate slide content + speaker notes from an approved outline.
  Future<Map<String, dynamic>> generateSlides(
    Map<String, dynamic> config,
    List<dynamic> outline,
  ) async {
    try {
      final response = await _api.post(
        '/presentations/generate',
        body: {'config': config, 'outline': outline},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Generation failed')};
    } catch (e) {
      return {'success': false, 'error': 'Generation failed: $e'};
    }
  }

  /// Compute the academic quality report for the current deck.
  Future<Map<String, dynamic>> computeQuality(
    Map<String, dynamic> config,
    List<dynamic> outline,
    List<dynamic> slides,
  ) async {
    try {
      final response = await _api.post(
        '/presentations/quality',
        body: {
          'config': config,
          'outline': outline,
          'slides': slides,
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Quality check failed')};
    } catch (e) {
      return {'success': false, 'error': 'Quality check failed: $e'};
    }
  }

  /// Export an editable .pptx and trigger a browser download.
  Future<Map<String, dynamic>> exportPptx(
    Map<String, dynamic> config,
    List<dynamic> slides,
  ) async {
    try {
      final response = await _api.post(
        '/presentations/pptx/from-data',
        body: {'config': config, 'slides': slides},
      );
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.bodyBytes,
          'name': ((config['topic'] as String?) ?? 'presentation').replaceAll(' ', '_'),
        };
      }
      return {'success': false, 'error': _extractError(response, 'Export failed')};
    } catch (e) {
      return {'success': false, 'error': 'Export failed: $e'};
    }
  }
}

class ExaminationBuilderService {
  final ApiService _api = ApiService();

  /// Generate exam questions from a syllabus-driven config map.
  Future<Map<String, dynamic>> generateQuestions(Map<String, dynamic> config) async {
    try {
      final response = await _api.post(
        '/examinations-builder/generate',
        body: {'config': config},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Generation failed')};
    } catch (e) {
      return {'success': false, 'error': 'Generation failed: $e'};
    }
  }

  /// Fetch a stored examination (for re-editing after generation).
  Future<Map<String, dynamic>> fetchExam(String examId) async {
    try {
      final response = await _api.get('/examinations-builder/$examId');
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Could not load examination')};
    } catch (e) {
      return {'success': false, 'error': 'Could not load examination: $e'};
    }
  }

  /// Compute the academic quality report for the generated paper.
  Future<Map<String, dynamic>> computeQuality(String examId) async {
    try {
      final response = await _api.post('/examinations-builder/$examId/quality');
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Quality check failed')};
    } catch (e) {
      return {'success': false, 'error': 'Quality check failed: $e'};
    }
  }

  /// Regenerate a single question with an optional focus hint.
  Future<Map<String, dynamic>> regenerateQuestion(
    String examId,
    String questionId,
    String focus,
  ) async {
    try {
      final response = await _api.post(
        '/examinations-builder/$examId/regenerate-question',
        body: {'exam_id': examId, 'question_id': questionId, 'focus': focus},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Regeneration failed')};
    } catch (e) {
      return {'success': false, 'error': 'Regeneration failed: $e'};
    }
  }

  /// Add a manually authored question to the paper.
  Future<Map<String, dynamic>> addQuestion(String examId, Map<String, dynamic> question) async {
    try {
      final response = await _api.post(
        '/examinations-builder/$examId/questions',
        body: question,
      );
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Could not add question')};
    } catch (e) {
      return {'success': false, 'error': 'Could not add question: $e'};
    }
  }

  /// Remove a question from the paper.
  Future<Map<String, dynamic>> removeQuestion(String examId, String questionId) async {
    try {
      final response = await _api.delete('/examinations-builder/$examId/questions/$questionId');
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': _extractError(response, 'Could not remove question')};
    } catch (e) {
      return {'success': false, 'error': 'Could not remove question: $e'};
    }
  }

  /// Export the paper as an editable .docx (or .pdf) and trigger download.
  Future<Map<String, dynamic>> exportExam(
    String examId, {
    required String format,
    required bool includeAnswers,
    String title = 'examination',
  }) async {
    try {
      final response = await _api.post(
        '/examinations-builder/$examId/export',
        body: {'exam_id': examId, 'format': format, 'include_answers': includeAnswers},
      );
      if (response.statusCode == 200) {
        final ext = format == 'pdf' ? 'pdf' : 'docx';
        return {
          'success': true,
          'data': response.bodyBytes,
          'name': '${title.replaceAll(' ', '_')}.$ext',
        };
      }
      return {'success': false, 'error': _extractError(response, 'Export failed')};
    } catch (e) {
      return {'success': false, 'error': 'Export failed: $e'};
    }
  }
}

class CourseService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> listCourses() async {
    final response = await _api.getWithCache('/courses/');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>?> getCourse(int id) async {
    final response = await _api.get('/courses/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> enroll(int courseId) async {
    final response = await _api.post('/courses/$courseId/enroll');
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.body.isEmpty) return {'success': true, 'data': null};
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': _extractError(response, 'Enrollment failed')};
  }

  Future<List<dynamic>> getSchedule(int courseId) async {
    final response = await _api.get('/courses/$courseId/schedule');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
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
    return {'success': false, 'error': _extractError(response, 'Failed to get response')};
  }

  Future<List<dynamic>> listSessions() async {
    final response = await _api.get('/ai/sessions');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>?> getSession(int id) async {
    final response = await _api.get('/ai/sessions/$id');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
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
    return {'success': false, 'error': _extractError(response, 'Failed to generate lesson plan')};
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
    return {'success': false, 'error': _extractError(response, 'Failed to generate assessment')};
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
    return {'success': false, 'error': _extractError(response, 'Failed to generate study plan')};
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
    return {'success': false, 'error': _extractError(response, 'Failed to analyze data')};
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
    return {'success': false, 'error': _extractError(response, 'Failed to run code')};
  }
}

class NotificationService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> listNotifications() async {
    final response = await _api.get('/notifications/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<int> unreadCount() async {
    final response = await _api.get('/notifications/unread-count');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (body['count'] as num?)?.toInt() ?? 0;
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
      return jsonDecode(response.body) as List<dynamic>;
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
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }
}

class AssessmentService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> listAssessments(int courseId) async {
    final response = await _api.get('/assessments/course/$courseId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
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

class MultimodalService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> uploadFile(String filePath, String filename) async {
    final response = await _api.uploadFile('/ai/multimodal/upload', filePath, filename);
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': _extractError(response, 'Upload failed')};
  }

  Future<Map<String, dynamic>> uploadFileBytes(List<int> bytes, String filename) async {
    final response = await _api.uploadFileBytes('/ai/multimodal/upload', bytes, filename);
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': _extractError(response, 'Upload failed')};
  }

  Future<Map<String, dynamic>> deleteFile(String fileId) async {
    final response = await _api.delete('/ai/multimodal/files/$fileId');
    if (response.statusCode == 200) {
      return {'success': true};
    }
    return {'success': false, 'error': _extractError(response, 'Delete failed')};
  }

  Future<List<dynamic>> listVoices({String? language}) async {
    final path = language != null ? '/ai/multimodal/voices?language=$language' : '/ai/multimodal/voices';
    final response = await _api.get(path);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> updateVoiceSettings({
    required String voiceId,
    double speed = 1.0,
    bool autoRead = false,
  }) async {
    final response = await _api.post('/ai/multimodal/voices/settings', body: {
      'default_voice_id': voiceId,
      'playback_speed': speed,
      'auto_read': autoRead,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': _extractError(response, 'Settings update failed')};
  }

  Future<Map<String, dynamic>> synthesizeTTS({
    required String text,
    String voiceId = 'default',
    double speed = 1.0,
  }) async {
    final response = await _api.post('/ai/multimodal/tts/synthesize', body: {
      'text': text,
      'voice_id': voiceId,
      'speed': speed,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': _extractError(response, 'TTS failed')};
  }

  Future<Map<String, dynamic>> stemToSpeech({
    required String latex,
    String language = 'en',
  }) async {
    final response = await _api.post('/ai/multimodal/stem-to-speech', body: {
      'text': latex,
      'language': language,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': _extractError(response, 'STEM speech conversion failed')};
  }

  Future<Map<String, dynamic>> chatWithFiles({
    required String message,
    int? sessionId,
    String agentType = 'tutor',
    List<String> fileIds = const [],
  }) async {
    final response = await _api.post('/ai/chat', body: {
      'message': message,
      'session_id': sessionId,
      'agent_type': agentType,
      'file_ids': fileIds,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': _extractError(response, 'Chat failed')};
  }

  Future<Map<String, dynamic>> createVoiceClone({
    required String voiceName,
    required bool consentConfirmed,
  }) async {
    final response = await _api.post('/ai/multimodal/voices/clone', body: {
      'voice_name': voiceName,
      'consent_confirmed': consentConfirmed,
    });
    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    }
    return {'success': false, 'error': _extractError(response, 'Voice clone failed')};
  }

  Future<Map<String, dynamic>> deleteVoiceClone(String cloneId) async {
    final response = await _api.delete('/ai/multimodal/voices/clone/$cloneId');
    if (response.statusCode == 200) {
      return {'success': true};
    }
    return {'success': false, 'error': _extractError(response, 'Delete failed')};
  }
}

class SyllabusService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> getSubjects() async {
    final response = await _api.get('/syllabus/subjects');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> getForms(String slug) async {
    final response = await _api.get('/syllabus/subjects/$slug/forms');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'forms': <dynamic>[]};
  }

  Future<List<dynamic>> getTopics(String slug, int form) async {
    final response = await _api.get('/syllabus/subjects/$slug/forms/$form/topics');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getSubtopics(int topicId) async {
    final response = await _api.get('/syllabus/topics/$topicId/subtopics');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getObjectives(int subtopicId) async {
    final response = await _api.get('/syllabus/subtopics/$subtopicId/objectives');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['objectives'] as List<dynamic>?) ?? [];
    }
    return [];
  }
}
