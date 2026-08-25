import 'dart:convert';

class ParsedVisual {
  final VisualType type;
  final String? rawSpec;
  final String? title;
  final String? expression;
  final List<double>? values;
  final List<String>? labels;
  final List<List<double>>? points;
  final String? shapeType;
  final double? xMin;
  final double? xMax;
  final double? yMin;
  final double? yMax;
  final String? subject;
  final String? topic;
  final String? syllabusObjective;
  final String? generationSource;
  final DateTime? generationDate;

  const ParsedVisual({
    required this.type,
    this.rawSpec,
    this.title,
    this.expression,
    this.values,
    this.labels,
    this.points,
    this.shapeType,
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
    this.subject,
    this.topic,
    this.syllabusObjective,
    this.generationSource,
    this.generationDate,
  });

  Map<String, dynamic> toMetadataMap() => {
        'type': type.name,
        'title': title,
        'subject': subject,
        'topic': topic,
        'syllabusObjective': syllabusObjective,
        'generationSource': generationSource,
        'generationDate': (generationDate ?? DateTime.now()).toIso8601String(),
        'rawSpec': rawSpec,
      };
}

enum VisualType {
  graph,
  barChart,
  pieChart,
  histogram,
  lineChart,
  frequencyPolygon,
  cumulativeFrequency,
  triangle,
  circle,
  quadrilateral,
  polygon,
  angle,
  tangent,
  unknown
}

class AIVisualParser {
  static final RegExp _visualBlockExp = RegExp(r'<!--visual:(.*?)-->', dotAll: true);
  static final RegExp _xmlVisualExp = RegExp(r'<visual>(.*?)</visual>', dotAll: true);

  static List<ParsedVisual> parseFromResponse(String response) {
    final visuals = <ParsedVisual>[];
    for (final match in _visualBlockExp.allMatches(response)) {
      final spec = match.group(1)?.trim();
      if (spec != null) {
        final parsed = _parseSpec(spec);
        if (parsed != null) visuals.add(parsed);
      }
    }
    for (final match in _xmlVisualExp.allMatches(response)) {
      final spec = match.group(1)?.trim();
      if (spec != null) {
        final parsed = _parseSpec(spec);
        if (parsed != null) visuals.add(parsed);
      }
    }
    return visuals;
  }

  static String removeVisualBlocks(String response) {
    return response.replaceAll(_visualBlockExp, '').replaceAll(_xmlVisualExp, '').trim();
  }

  static ParsedVisual? _parseSpec(String spec) {
    try {
      final map = jsonDecode(spec) as Map<String, dynamic>;
      final typeStr = map['type'] as String? ?? 'unknown';
      final type = _parseType(typeStr);
      return ParsedVisual(
        type: type,
        rawSpec: spec,
        title: map['title'] as String?,
        expression: map['expression'] as String?,
        values: (map['values'] as List?)?.map((e) => (e as num).toDouble()).toList(),
        labels: (map['labels'] as List?)?.map((e) => e.toString()).toList(),
        points: (map['points'] as List?)?.map((p) => (p as List).map((e) => (e as num).toDouble()).toList()).toList(),
        shapeType: map['shape'] as String? ?? map['shapeType'] as String?,
        xMin: (map['xMin'] as num?)?.toDouble(),
        xMax: (map['xMax'] as num?)?.toDouble(),
        yMin: (map['yMin'] as num?)?.toDouble(),
        yMax: (map['yMax'] as num?)?.toDouble(),
        subject: map['subject'] as String?,
        topic: map['topic'] as String?,
        syllabusObjective: map['syllabusObjective'] as String?,
        generationSource: map['generationSource'] as String? ?? 'ai',
        generationDate: DateTime.tryParse(map['generationDate'] as String? ?? ''),
      );
    } catch (_) {
      return _parseNaturalLanguage(spec);
    }
  }

  static ParsedVisual? _parseNaturalLanguage(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('bar chart') || lower.contains('barchart')) {
      return ParsedVisual(type: VisualType.barChart, rawSpec: text, title: text);
    }
    if (lower.contains('pie chart') || lower.contains('piechart')) {
      return ParsedVisual(type: VisualType.pieChart, rawSpec: text, title: text);
    }
    if (lower.contains('histogram')) {
      return ParsedVisual(type: VisualType.histogram, rawSpec: text, title: text);
    }
    if (lower.contains('line graph') || lower.contains('line chart')) {
      return ParsedVisual(type: VisualType.lineChart, rawSpec: text, title: text);
    }
    if (lower.contains('triangle')) {
      return ParsedVisual(type: VisualType.triangle, rawSpec: text, title: text, shapeType: 'triangle');
    }
    if (lower.contains('circle')) {
      return ParsedVisual(type: VisualType.circle, rawSpec: text, title: text, shapeType: 'circle');
    }
    final fnMatch = RegExp(r'(?:graph|plot|draw)\s+(?:of\s+)?(?:y\s*=\s*)?(.+)', caseSensitive: false).firstMatch(text);
    if (fnMatch != null) {
      return ParsedVisual(type: VisualType.graph, expression: fnMatch.group(1)?.trim(), rawSpec: text);
    }
    return null;
  }

  static VisualType _parseType(String s) {
    switch (s.toLowerCase()) {
      case 'graph':
      case 'function':
        return VisualType.graph;
      case 'bar':
      case 'bar_chart':
      case 'barchart':
        return VisualType.barChart;
      case 'pie':
      case 'pie_chart':
      case 'piechart':
        return VisualType.pieChart;
      case 'histogram':
        return VisualType.histogram;
      case 'line':
      case 'line_chart':
      case 'linechart':
        return VisualType.lineChart;
      case 'frequency_polygon':
      case 'frequencypolygon':
        return VisualType.frequencyPolygon;
      case 'cumulative_frequency':
      case 'cumulativefrequency':
        return VisualType.cumulativeFrequency;
      case 'triangle':
        return VisualType.triangle;
      case 'circle':
        return VisualType.circle;
      case 'quadrilateral':
      case 'rectangle':
      case 'parallelogram':
      case 'trapezium':
        return VisualType.quadrilateral;
      case 'polygon':
        return VisualType.polygon;
      case 'angle':
        return VisualType.angle;
      case 'tangent':
        return VisualType.tangent;
      default:
        return VisualType.unknown;
    }
  }
}
