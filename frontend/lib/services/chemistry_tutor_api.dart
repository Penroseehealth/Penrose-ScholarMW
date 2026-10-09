import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'math_tutor_api.dart' show TutorReply;

/// Thin client over the Penrose chemistry laboratory tutor API.
///
/// Mirrors [MathTutorApi]/[PhysicsTutorApi]: the frontend deterministic
/// chemistry engine owns every number; the backend tutor only explains the
/// validated experiment state it is handed. On any network failure the call
/// returns null so the panel can show an honest "not reachable" message
/// rather than an invented answer.
class ChemistryTutorApi {
  ChemistryTutorApi({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static const _timeout = Duration(seconds: 20);

  /// Ask the tutor about the current titration state.
  ///
  /// [state] must be the validated snapshot from [TitrationController] —
  /// the backend treats it as ground truth.
  Future<TutorReply?> explain({
    required String question,
    required Map<String, dynamic> state,
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async {
    try {
      final response = await _api.post(
        '/chemistry/tutor/explain',
        body: <String, dynamic>{
          'question': question,
          'state': state,
          'history': history,
        },
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('ChemistryTutorApi.explain failed: HTTP ${response.statusCode}');
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final text = (decoded['reply'] as String?)?.trim() ?? '';
      if (text.isEmpty) return null;
      return TutorReply(
        text: text,
        source: (decoded['source'] as String?) ?? 'ai',
      );
    } catch (error) {
      debugPrint('ChemistryTutorApi.explain error: $error');
      return null;
    }
  }
}
