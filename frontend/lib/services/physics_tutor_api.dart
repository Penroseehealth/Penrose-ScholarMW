import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../widgets/physics_tutor/physics_solution.dart';
import 'api_service.dart';
import 'math_tutor_api.dart';

/// Thin client over the Penrose visual physics tutor API.
///
/// Mirrors [MathTutorApi]: the backend owns the deterministic physics and the
/// tutoring voice. When the network is unavailable every method returns null so
/// the caller can show an honest "not reachable" message rather than inventing
/// a result. The conversational reply and work-check types are shared with the
/// mathematics tutor.
class PhysicsTutorApi {
  PhysicsTutorApi({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static const _timeout = Duration(seconds: 20);

  /// Deterministic, verified solution for [problem], or null on any failure.
  Future<PhysicsSolution?> solve(String problem) async {
    try {
      final response =
          await _api.post('/physics/tutor/solve', body: <String, dynamic>{'problem': problem}).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('PhysicsTutorApi.solve failed: HTTP ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return PhysicsSolution.fromJson(decoded);
    } catch (error) {
      debugPrint('PhysicsTutorApi.solve error: $error');
      return null;
    }
  }

  /// Ask a follow-up question about the solution currently on screen.
  Future<TutorReply?> explain({
    required String problem,
    required String question,
    required PhysicsSolution? solution,
    int? stepId,
    String? topic,
    String? currentEquation,
    List<String> conceptsExplained = const <String>[],
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async {
    try {
      final response = await _api.post(
        '/physics/tutor/explain',
        body: <String, dynamic>{
          'problem': problem,
          'question': question,
          'step_id': stepId,
          'topic': topic,
          'current_equation': currentEquation,
          'concepts_explained': conceptsExplained,
          'solution': solution?.toExplainJson(),
          'history': history,
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('PhysicsTutorApi.explain failed: HTTP ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final text = (decoded['reply'] as String?)?.trim() ?? '';
      if (text.isEmpty) return null;
      return TutorReply(
        text: text,
        stepRef: (decoded['step_ref'] as num?)?.toInt(),
        source: (decoded['source'] as String?) ?? 'ai',
      );
    } catch (error) {
      debugPrint('PhysicsTutorApi.explain error: $error');
      return null;
    }
  }

  /// Check a line of the student's own working for a wrong operation.
  Future<TutorWorkCheck?> check({required String problem, required String studentLine}) async {
    try {
      final response = await _api.post(
        '/physics/tutor/check',
        body: <String, dynamic>{'problem': problem, 'student_line': studentLine},
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('PhysicsTutorApi.check failed: HTTP ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return TutorWorkCheck(
        ok: decoded['ok'] == true,
        message: (decoded['message'] as String?)?.trim() ?? '',
        expectedLatex: (decoded['expected_latex'] as String?) ?? '',
        correctionLatex: (decoded['correction_latex'] as String?) ?? '',
        stepRef: (decoded['step_ref'] as num?)?.toInt(),
      );
    } catch (error) {
      debugPrint('PhysicsTutorApi.check error: $error');
      return null;
    }
  }
}
