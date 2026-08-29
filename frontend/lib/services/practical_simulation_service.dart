import 'dart:convert';

import 'api_service.dart';

String _simulationError(dynamic response, String fallback) {
  try {
    final body = jsonDecode(response.body as String) as Map<String, dynamic>;
    return (body['detail'] ?? body['error'] ?? body['message'] ?? fallback) as String;
  } catch (_) {
    return fallback;
  }
}

/// A syllabus-linked practical simulation (e.g. 'Using a Microscope').
class PracticalSimulationSummary {
  final int id;
  final String subjectSlug;
  final String practicalKey;
  final String title;
  final String? description;
  final String? syllabusReference;
  final bool isSaved;
  final int versions;
  final String? latestStatus;
  final String? latestVideoUrl;

  PracticalSimulationSummary({
    required this.id,
    required this.subjectSlug,
    required this.practicalKey,
    required this.title,
    this.description,
    this.syllabusReference,
    this.isSaved = false,
    this.versions = 0,
    this.latestStatus,
    this.latestVideoUrl,
  });

  factory PracticalSimulationSummary.fromJson(Map<String, dynamic> json) => PracticalSimulationSummary(
        id: (json['id'] as num).toInt(),
        subjectSlug: json['subject_slug'] as String? ?? '',
        practicalKey: json['practical_key'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        syllabusReference: json['syllabus_reference'] as String?,
        isSaved: json['is_saved'] as bool? ?? false,
        versions: (json['versions'] as num?)?.toInt() ?? 0,
        latestStatus: json['latest_status'] as String?,
        latestVideoUrl: json['latest_video_url'] as String?,
      );
}

/// A single storyboard scene.
class PracticalScene {
  final String sceneId;
  final double duration;
  final String purpose;
  final String camera;
  final String action;
  final String narration;
  final String onScreenText;
  final String safetyNote;
  final String transition;
  final String continuityReference;

  PracticalScene({
    required this.sceneId,
    this.duration = 0,
    this.purpose = '',
    this.camera = '',
    this.action = '',
    this.narration = '',
    this.onScreenText = '',
    this.safetyNote = '',
    this.transition = 'cut',
    this.continuityReference = '',
  });

  factory PracticalScene.fromJson(Map<String, dynamic> json) => PracticalScene(
        sceneId: json['scene_id'] as String? ?? '',
        duration: (json['duration'] as num?)?.toDouble() ?? 0,
        purpose: json['purpose'] as String? ?? '',
        camera: json['camera'] as String? ?? '',
        action: json['action'] as String? ?? '',
        narration: json['narration'] as String? ?? '',
        onScreenText: json['on_screen_text'] as String? ?? '',
        safetyNote: json['safety_note'] as String? ?? '',
        transition: json['transition'] as String? ?? 'cut',
        continuityReference: json['continuity_reference'] as String? ?? '',
      );
}

/// The full structured video spec returned by the storyboard/detail endpoints.
class PracticalSimulationSpec {
  final int? simulationId;
  final String practicalId;
  final String title;
  final String syllabusReference;
  final List<String> learningObjectives;
  final List<String> equipment;
  final List<PracticalScene> scenes;
  final List<String> assessmentPoints;
  final String generationProvider;
  final String generationModel;
  final bool syllabusMapped;
  final String message;

  PracticalSimulationSpec({
    this.simulationId,
    this.practicalId = '',
    this.title = '',
    this.syllabusReference = '',
    this.learningObjectives = const [],
    this.equipment = const [],
    this.scenes = const [],
    this.assessmentPoints = const [],
    this.generationProvider = '',
    this.generationModel = '',
    this.syllabusMapped = false,
    this.message = '',
  });

  factory PracticalSimulationSpec.fromJson(Map<String, dynamic> json) {
    final spec = json['spec'] as Map<String, dynamic>? ?? json;
    final scenes = (spec['scenes'] as List<dynamic>? ?? [])
        .map((e) => PracticalScene.fromJson(e as Map<String, dynamic>))
        .toList();
    return PracticalSimulationSpec(
      simulationId: (json['simulation_id'] as num?)?.toInt() ?? (json['id'] as num?)?.toInt(),
      practicalId: spec['practical_id'] as String? ?? '',
      title: spec['title'] as String? ?? '',
      syllabusReference: spec['syllabus_reference'] as String? ?? '',
      learningObjectives: (spec['learning_objectives'] as List<dynamic>? ?? []).cast<String>(),
      equipment: (spec['equipment'] as List<dynamic>? ?? []).cast<String>(),
      scenes: scenes,
      assessmentPoints: (spec['assessment_points'] as List<dynamic>? ?? []).cast<String>(),
      generationProvider: spec['generation_provider'] as String? ?? '',
      generationModel: spec['generation_model'] as String? ?? '',
      syllabusMapped: json['syllabus_mapped'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Async generation job status.
class GenerationJob {
  final int jobId;
  final int simulationId;
  final String status;
  final double progress;
  final String? provider;
  final String? model;
  final double? estimatedCredits;
  final String? error;
  final String? videoUrl;

  GenerationJob({
    required this.jobId,
    required this.simulationId,
    required this.status,
    this.progress = 0,
    this.provider,
    this.model,
    this.estimatedCredits,
    this.error,
    this.videoUrl,
  });

  bool get isFinished => status == 'COMPLETED' || status == 'FAILED' || status == 'CANCELLED';

  factory GenerationJob.fromJson(Map<String, dynamic> json) => GenerationJob(
        jobId: (json['job_id'] as num).toInt(),
        simulationId: (json['simulation_id'] as num).toInt(),
        status: json['status'] as String? ?? 'QUEUED',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        provider: json['provider'] as String?,
        model: json['model'] as String?,
        estimatedCredits: (json['estimated_credits'] as num?)?.toDouble(),
        error: json['error'] as String?,
        videoUrl: json['video_url'] as String?,
      );
}

/// Handles all Practical Simulation Video API calls.
class PracticalSimulationService {
  final ApiService _api = ApiService();

  static const String _base = '/biology/practicals/simulations';

  Future<List<PracticalSimulationSummary>> listSimulations({String? subject}) async {
    final path = subject == null ? _base : '$_base?subject=$subject';
    final response = await _api.get(path);
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => PracticalSimulationSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PracticalSimulationSpec> createSimulation({
    String subjectSlug = 'biology',
    String practicalKey = 'using-a-microscope',
    String title = 'Using a Microscope',
  }) async {
    final response = await _api.post(_base, body: {
      'subject_slug': subjectSlug,
      'practical_key': practicalKey,
      'title': title,
    });
    if (response.statusCode == 201 || response.statusCode == 200) {
      return PracticalSimulationSpec.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(_simulationError(response, 'Failed to create simulation'));
  }

  Future<PracticalSimulationSpec> getSimulation(int simulationId) async {
    final response = await _api.get('$_base/$simulationId');
    if (response.statusCode == 200) {
      return PracticalSimulationSpec.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(_simulationError(response, 'Failed to load simulation'));
  }

  Future<Map<String, dynamic>> storyboard(int simulationId) async {
    final response = await _api.post('$_base/$simulationId/storyboard', body: {});
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_simulationError(response, 'Failed to build storyboard'));
  }

  Future<GenerationJob> generate(int simulationId, {String quality = 'standard', String? provider}) async {
    final response = await _api.post('$_base/$simulationId/generate', body: {
      'quality': quality,
      if (provider != null && provider.isNotEmpty) 'provider': provider,
    });
    if (response.statusCode == 202 || response.statusCode == 200) {
      return GenerationJob.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(_simulationError(response, 'Failed to start generation'));
  }

  Future<GenerationJob> generationStatus(int simulationId, int jobId) async {
    final response = await _api.get('$_base/$simulationId/generate/$jobId');
    if (response.statusCode == 200) {
      return GenerationJob.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception(_simulationError(response, 'Failed to load generation status'));
  }

  Future<Map<String, dynamic>> providersStatus() async {
    final response = await _api.get('$_base/providers/status');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'generation_enabled': false, 'configured': const []};
  }
}
