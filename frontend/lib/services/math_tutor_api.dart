import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../widgets/math_tutor/math_solution.dart';
import 'api_service.dart';

/// One conversational reply from the tutor.
class TutorReply {
  final String text;

  /// Step the student asked about, when the tutor could identify one.
  final int? stepRef;

  /// 'ai' or 'deterministic' - lets the panel show which engine answered.
  final String source;

  const TutorReply({required this.text, this.stepRef, required this.source});
}

/// Result of inspecting a line of the student's own working.
class TutorWorkCheck {
  final bool ok;
  final String message;
  final String expectedLatex;
  final String correctionLatex;
  final int? stepRef;

  const TutorWorkCheck({
    required this.ok,
    required this.message,
    this.expectedLatex = '',
    this.correctionLatex = '',
    this.stepRef,
  });
}

/// Thin client over the Penrose mathematics tutor API.
///
/// The backend owns the mathematics (SymPy) and the tutoring voice. When the
/// network is unavailable every method returns null so the caller can fall
/// back to the deterministic on-device solver and stay fully usable offline.
class MathTutorApi {
  MathTutorApi({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static const _timeout = Duration(seconds: 20);

  /// Deterministic, verified solution for [problem], or null on any failure.
  Future<TutorSolution?> solve(String problem) async {
    try {
      final response =
          await _api.post('/mathematics/tutor/solve', body: <String, dynamic>{'problem': problem}).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('MathTutorApi.solve failed: HTTP ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return TutorSolution.fromJson(decoded);
    } catch (error) {
      debugPrint('MathTutorApi.solve error: $error');
      return null;
    }
  }

  /// Ask a follow-up question about the solution currently on screen.
  Future<TutorReply?> explain({
    required String problem,
    required String question,
    required TutorSolution? solution,
    int? stepId,
    String? topic,
    String? currentEquation,
    List<String> conceptsExplained = const <String>[],
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async {
    try {
      final response = await _api.post(
        '/mathematics/tutor/explain',
        body: <String, dynamic>{
          'problem': problem,
          'question': question,
          'step_id': stepId,
          'topic': topic,
          'current_equation': currentEquation,
          'concepts_explained': conceptsExplained,
          'solution': _solutionJson(solution),
          'history': history,
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('MathTutorApi.explain failed: HTTP ${response.statusCode}');
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
      debugPrint('MathTutorApi.explain error: $error');
      return null;
    }
  }

  /// Check a line of the student's own working for a wrong operation.
  Future<TutorWorkCheck?> check({required String problem, required String studentLine}) async {
    try {
      final response = await _api.post(
        '/mathematics/tutor/check',
        body: <String, dynamic>{'problem': problem, 'student_line': studentLine},
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('MathTutorApi.check failed: HTTP ${response.statusCode}');
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
      debugPrint('MathTutorApi.check error: $error');
      return null;
    }
  }

  /// Serialise the shared model back into the API contract for the explain call.
  Map<String, dynamic>? _solutionJson(TutorSolution? solution) {
    if (solution == null) return null;
    return <String, dynamic>{
      'problem': solution.problem,
      'subject': solution.subject.name,
      'topic': solution.topic,
      'final_answer_latex': solution.answerLatex,
      'final_answer_text': solution.finalAnswer,
      'verification_status': solution.verificationStatus,
      'verification_detail': solution.verificationDetail,
      'visual': solution.visualData,
      'steps': solution.steps
          .map(
            (step) => <String, dynamic>{
              'id': step.id,
              'title': step.title,
              'narration': step.narration,
              'explanation': step.explanation,
              'latex_lines': step.latexLines,
            },
          )
          .toList(),
    };
  }
}
