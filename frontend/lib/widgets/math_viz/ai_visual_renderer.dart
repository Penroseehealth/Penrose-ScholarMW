import 'package:flutter/material.dart';
import 'ai_visual_parser.dart';
import 'editable_data_grid.dart';
import 'function_plotter.dart';
import 'geometric_shapes.dart';
import 'statistical_charts.dart';

class AIVisualRenderer extends StatefulWidget {
  final ParsedVisual visual;

  const AIVisualRenderer({super.key, required this.visual});

  static bool hasVisuals(String response) {
    return response.contains('<!--visual:') || response.contains('<visual>');
  }

  @override
  State<AIVisualRenderer> createState() => _AIVisualRendererState();
}

class _AIVisualRendererState extends State<AIVisualRenderer> {
  late List<double> _currentValues;
  late List<String> _currentLabels;

  @override
  void initState() {
    super.initState();
    _currentValues = List<double>.from(widget.visual.values ?? []);
    _currentLabels = List<String>.from(widget.visual.labels ?? []);
  }

  ParsedVisual get visual => widget.visual;

  @override
  Widget build(BuildContext context) {
    switch (visual.type) {
      case VisualType.graph:
        return _buildGraph();
      case VisualType.barChart:
        return _buildChartWithGrid(StatisticalChartType.bar);
      case VisualType.pieChart:
        return _buildChartWithGrid(StatisticalChartType.pie);
      case VisualType.histogram:
        return _buildChartWithGrid(StatisticalChartType.histogram);
      case VisualType.lineChart:
        return _buildChartWithGrid(StatisticalChartType.line);
      case VisualType.frequencyPolygon:
        return _buildChartWithGrid(StatisticalChartType.frequencyPolygon);
      case VisualType.cumulativeFrequency:
        return _buildChartWithGrid(StatisticalChartType.cumulativeFrequency);
      case VisualType.triangle:
      case VisualType.circle:
      case VisualType.quadrilateral:
      case VisualType.polygon:
      case VisualType.angle:
      case VisualType.tangent:
        return _buildShape();
      case VisualType.unknown:
        return _buildFallback();
    }
  }

  Widget _buildGraph() {
    final expr = visual.expression ?? 'x';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visual.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(visual.title!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        SizedBox(
          height: 250,
          child: FunctionPlotter(
            functions: [
              FunctionPlotConfig(
                expression: expr,
                color: Colors.cyanAccent,
                label: 'y',
              ),
            ],
            xMin: visual.xMin ?? -10,
            xMax: visual.xMax ?? 10,
            yMin: visual.yMin ?? -10,
            yMax: visual.yMax ?? 10,
          ),
        ),
      ],
    );
  }

  Widget _buildChartWithGrid(StatisticalChartType chartType) {
    final data = _currentValues.asMap().entries.map((e) => ChartDataPoint(x: e.key.toDouble(), y: e.value)).toList();
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 260,
          child: StatisticalChartWidget(
            type: chartType,
            data: data,
            title: visual.title,
            categoryLabels: _currentLabels.isNotEmpty ? _currentLabels : null,
          ),
        ),
        const SizedBox(height: 8),
        EditableDataGrid(
          title: 'Edit Data',
          columnHeaders: [
            if (_currentLabels.isNotEmpty) 'Label',
            'Value',
          ],
          initialData: _buildGridData(),
          onDataChanged: (newData) {
            setState(() {
              final parsed = _parseGridData(newData);
              _currentValues = parsed.values;
              _currentLabels = parsed.labels;
            });
          },
        ),
      ],
    );
  }

  List<List<String>> _buildGridData() {
    if (_currentLabels.isNotEmpty) {
      return List.generate(
        _currentValues.length,
        (i) => [
          i < _currentLabels.length ? _currentLabels[i] : 'Item ${i + 1}',
          _currentValues[i].toStringAsFixed(1),
        ],
      );
    }
    return List.generate(
      _currentValues.length,
      (i) => [_currentValues[i].toStringAsFixed(1)],
    );
  }

  ({List<double> values, List<String> labels}) _parseGridData(List<List<String>> raw) {
    final values = <double>[];
    final labels = <String>[];
    final hasLabels = raw.isNotEmpty && raw[0].length > 1;

    for (final row in raw) {
      final lastVal = row.isNotEmpty ? double.tryParse(row.last) ?? 0.0 : 0.0;
      values.add(lastVal);
      if (hasLabels && row.length > 1) {
        labels.add(row[0]);
      }
    }
    return (values: values, labels: labels);
  }

  Widget _buildShape() {
    final points = (visual.points ?? []).map((p) => Offset(p[0], p[1])).toList();
    final shape = GeometricShape(
      type: _mapShapeType(visual.shapeType ?? 'triangle'),
      label: visual.title,
      points: points,
    );
    return GeometricShapeRenderer(
      shapes: [shape],
      height: 250,
    );
  }

  Widget _buildFallback() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.info_outline, color: Colors.white38, size: 16),
          SizedBox(width: 8),
          Text('Visual representation', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  ShapeType _mapShapeType(String s) {
    switch (s.toLowerCase()) {
      case 'triangle':
        return ShapeType.triangle;
      case 'right_triangle':
        return ShapeType.rightTriangle;
      case 'circle':
        return ShapeType.circle;
      case 'semicircle':
        return ShapeType.semicircle;
      case 'quadrilateral':
      case 'rectangle':
        return ShapeType.quadrilateral;
      case 'parallelogram':
        return ShapeType.parallelogram;
      case 'trapezium':
        return ShapeType.trapezium;
      case 'cyclic':
      case 'cyclic_quadrilateral':
        return ShapeType.cyclicQuadrilateral;
      case 'tangent':
        return ShapeType.tangentCircle;
      case 'angle':
        return ShapeType.angle;
      default:
        return ShapeType.polygon;
    }
  }
}

class InlineVisualMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const InlineVisualMessage({super.key, required this.text, this.isUser = false});

  @override
  Widget build(BuildContext context) {
    final visuals = AIVisualParser.parseFromResponse(text);
    final cleanText = AIVisualParser.removeVisualBlocks(text);

    if (visuals.isEmpty) {
      return _TextBubble(text: text, isUser: isUser);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cleanText.isNotEmpty) _TextBubble(text: cleanText, isUser: isUser),
        ...visuals.map((v) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AIVisualRenderer(visual: v),
            )),
      ],
    );
  }
}

class DirectVisualMessage extends StatelessWidget {
  final ParsedVisual visual;
  final String? description;

  const DirectVisualMessage({super.key, required this.visual, this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (description != null && description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              description!,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        AIVisualRenderer(visual: visual),
      ],
    );
  }
}

class _TextBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _TextBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF3D5AFE) : const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
    );
  }
}
