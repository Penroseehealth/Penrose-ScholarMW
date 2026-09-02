/// Structured biological specification models shared by service + renderer.
///
/// Mirrors the backend `BiologySpec` JSON so the renderer is driven entirely by
/// the structured spec (never free-form drawing instructions).
library;

class StructureSpec {
  final String id;
  final String name;
  final String kind;
  final bool present;

  StructureSpec({
    required this.id,
    required this.name,
    required this.kind,
    this.present = true,
  });

  factory StructureSpec.fromJson(Map<String, dynamic> json) => StructureSpec(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        kind: json['kind'] as String? ?? 'component',
        present: json['present'] as bool? ?? true,
      );
}

/// A single labelled object in a process/cycle diagram. `shape` selects a
/// deterministic scientific primitive: box, circle, leaf, sun, input, output.
class ProcessNode {
  final String id;
  final String label;
  final String shape;
  final String detail;
  final bool required;

  ProcessNode({
    required this.id,
    required this.label,
    this.shape = 'box',
    this.detail = '',
    this.required = true,
  });

  factory ProcessNode.fromJson(Map<String, dynamic> json) => ProcessNode(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        shape: json['shape'] as String? ?? 'box',
        detail: json['detail'] as String? ?? '',
        required: json['required'] as bool? ?? true,
      );
}

/// A directed relationship between two process nodes.
class ProcessEdge {
  final String from;
  final String to;
  final String label;

  ProcessEdge({required this.from, required this.to, this.label = ''});

  factory ProcessEdge.fromJson(Map<String, dynamic> json) => ProcessEdge(
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );
}

class BiologySpec {
  final String category;
  final String app;
  final String kind;
  final String layout;
  final String title;
  final String style;
  final int form;
  final String topic;
  final String subtopic;
  final String diagramType;
  String background;
  bool labelsShown;
  final String qualityLevel;
  final List<StructureSpec> structures;
  final List<ProcessNode> nodes;
  final List<ProcessEdge> edges;
  final List<String> labels;
  final List<String> annotations;
  final String? syllabusReference;

  BiologySpec({
    this.category = 'cell',
    this.app = 'plant_cell',
    this.kind = 'cell',
    this.layout = 'cycle',
    this.title = 'Plant Cell',
    this.style = 'educational',
    this.form = 1,
    this.topic = '',
    this.subtopic = '',
    this.diagramType = 'labelled_diagram',
    this.background = 'white',
    this.labelsShown = true,
    this.qualityLevel = 'standard',
    this.structures = const [],
    this.nodes = const [],
    this.edges = const [],
    this.labels = const [],
    this.annotations = const [],
    this.syllabusReference,
  });

  factory BiologySpec.fromJson(Map<String, dynamic> json) => BiologySpec(
        category: json['category'] as String? ?? 'cell',
        app: json['app'] as String? ?? 'plant_cell',
        kind: json['kind'] as String? ?? 'cell',
        layout: json['layout'] as String? ?? 'cycle',
        title: json['title'] as String? ?? 'Plant Cell',
        style: json['style'] as String? ?? 'educational',
        form: (json['form'] as num?)?.toInt() ?? 1,
        topic: json['topic'] as String? ?? '',
        subtopic: json['subtopic'] as String? ?? '',
        diagramType: json['diagram_type'] as String? ?? 'labelled_diagram',
        background: json['background'] as String? ?? 'white',
        labelsShown: json['labels_shown'] as bool? ?? true,
        qualityLevel: json['quality_level'] as String? ?? 'standard',
        structures: (json['structures'] as List? ?? const [])
            .map((e) => StructureSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
        nodes:
            (json['nodes'] as List? ?? const []).map((e) => ProcessNode.fromJson(e as Map<String, dynamic>)).toList(),
        edges:
            (json['edges'] as List? ?? const []).map((e) => ProcessEdge.fromJson(e as Map<String, dynamic>)).toList(),
        labels: (json['labels'] as List? ?? const []).cast<String>(),
        annotations: (json['annotations'] as List? ?? const []).cast<String>(),
        syllabusReference: json['syllabus_reference'] as String?,
      );
}

class GenerationJob {
  final int jobId;
  final int? visualizationId;
  final String status;
  final double progress;
  final String? error;

  GenerationJob({
    required this.jobId,
    this.visualizationId,
    required this.status,
    this.progress = 0,
    this.error,
  });

  bool get isFinished => status == 'COMPLETED' || status == 'FAILED' || status == 'CANCELLED';

  factory GenerationJob.fromJson(Map<String, dynamic> json) => GenerationJob(
        jobId: (json['job_id'] as num).toInt(),
        visualizationId: (json['visualization_id'] as num?)?.toInt(),
        status: json['status'] as String? ?? 'QUEUED',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        error: json['error'] as String?,
      );
}

class VisualizationSummary {
  final int id;
  final String title;
  final String category;
  final String app;
  final int form;
  final String topic;
  final int version;
  final String? createdAt;

  VisualizationSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.app,
    required this.form,
    this.topic = '',
    this.version = 1,
    this.createdAt,
  });

  factory VisualizationSummary.fromJson(Map<String, dynamic> json) => VisualizationSummary(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? 'Biology Diagram',
        category: json['category'] as String? ?? 'cell',
        app: json['app'] as String? ?? 'plant_cell',
        form: (json['form'] as num?)?.toInt() ?? 1,
        topic: json['topic'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 1,
        createdAt: json['created_at'] as String?,
      );
}

class VisualizationDetail {
  final int id;
  final String title;
  final String category;
  final String app;
  final int form;
  final String topic;
  final String subtopic;
  final String diagramType;
  final String prompt;
  final BiologySpec spec;
  String background;
  final String qualityLevel;
  final String? syllabusReference;

  VisualizationDetail({
    required this.id,
    required this.title,
    required this.category,
    required this.app,
    required this.form,
    required this.topic,
    required this.subtopic,
    required this.diagramType,
    required this.prompt,
    required this.spec,
    required this.background,
    required this.qualityLevel,
    this.syllabusReference,
  });

  factory VisualizationDetail.fromJson(Map<String, dynamic> json) => VisualizationDetail(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? 'Biology Diagram',
        category: json['category'] as String? ?? 'cell',
        app: json['app'] as String? ?? 'plant_cell',
        form: (json['form'] as num?)?.toInt() ?? 1,
        topic: json['topic'] as String? ?? '',
        subtopic: json['subtopic'] as String? ?? '',
        diagramType: json['diagram_type'] as String? ?? 'labelled_diagram',
        prompt: json['prompt'] as String? ?? '',
        spec: BiologySpec.fromJson(json['spec'] as Map<String, dynamic>? ?? const {}),
        background: json['background'] as String? ?? 'white',
        qualityLevel: json['quality_level'] as String? ?? 'standard',
        syllabusReference: json['syllabus_reference'] as String?,
      );
}
