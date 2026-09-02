import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/biology_visualization.dart';
import 'api_service.dart';

/// Typed client for the Biology Visualization Engine.
class BiologyVisualizationService {
  final ApiService _api = ApiService();

  static const String _base = '/biology/diagrams';

  static String _err(http.Response r, String fallback) {
    try {
      final body = jsonDecode(r.body);
      if (body is Map) {
        return (body['detail'] ?? body['error'] ?? body['message'] ?? fallback).toString();
      }
    } catch (_) {}
    return fallback;
  }

  Future<GenerationJob> generate({
    required String prompt,
    int? form,
    String? app,
    String? topic,
    String? background,
  }) async {
    final response = await _api.post(
      '$_base/generate',
      body: {
        'prompt': prompt,
        if (form != null) 'form': form,
        if (app != null) 'app': app,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (background != null) 'background': background,
      },
    );
    if (response.statusCode == 202 || response.statusCode == 200) {
      return GenerationJob.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(_err(response, 'Failed to start diagram generation'));
  }

  Future<GenerationJob> generationStatus(int jobId) async {
    final response = await _api.get('$_base/jobs/$jobId');
    if (response.statusCode == 200) {
      return GenerationJob.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(_err(response, 'Failed to load generation status'));
  }

  Future<VisualizationDetail> save({
    required String prompt,
    int? form,
    String? app,
    String? topic,
    String? background,
  }) async {
    final response = await _api.post(
      '$_base/save',
      body: {
        'prompt': prompt,
        if (form != null) 'form': form,
        if (app != null) 'app': app,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (background != null) 'background': background,
      },
    );
    if (response.statusCode == 200) {
      return VisualizationDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(_err(response, 'Failed to save diagram'));
  }

  Future<List<VisualizationSummary>> history({int? form, String? category}) async {
    final query = [if (form != null) 'form=$form', if (category != null) 'category=$category'].join('&');
    final response = await _api.get(query.isEmpty ? _base : '$_base?$query');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => VisualizationSummary.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception(_err(response, 'Failed to load diagram history'));
  }

  Future<VisualizationDetail> get(int id) async {
    final response = await _api.get('$_base/$id');
    if (response.statusCode == 200) {
      return VisualizationDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(_err(response, 'Failed to load diagram'));
  }

  Future<VisualizationDetail> edit(
    int id, {
    String? background,
    bool? labelsShown,
    String? title,
  }) async {
    final response = await _api.put(
      '$_base/$id',
      body: {
        if (background != null) 'background': background,
        if (labelsShown != null) 'labels_shown': labelsShown,
        if (title != null) 'title': title,
      },
    );
    if (response.statusCode == 200) {
      return VisualizationDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(_err(response, 'Failed to update diagram'));
  }

  Future<void> delete(int id) async {
    final response = await _api.delete('$_base/$id');
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_err(response, 'Failed to delete diagram'));
    }
  }

  Future<List<Map<String, dynamic>>> syllabusTopics({int? form}) async {
    final query = form != null ? '?form=$form' : '';
    final response = await _api.get('$_base/syllabus/topics$query');
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
    }
    return const [];
  }
}
