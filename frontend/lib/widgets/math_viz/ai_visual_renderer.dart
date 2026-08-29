import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../stem_text.dart';
import '../visual_action_controls.dart';
import '../visual_pipeline/svg_render_widget.dart';
import 'ai_visual_parser.dart';
import 'editable_data_grid.dart';
import 'function_plotter.dart';
import 'geometric_shapes.dart';
import 'statistical_charts.dart';

class AIVisualRenderer extends StatefulWidget {
  final ParsedVisual visual;

  const AIVisualRenderer({super.key, required this.visual});

  static bool hasVisuals(String response) {
    return response.contains('<!--visual:') ||
        response.contains('<visual>') ||
        response.contains('<svg') ||
        RegExp(r'```(?:mermaid|mmd)\s*\n', dotAll: true).hasMatch(response) ||
        RegExp(r'```(?:latex|tex|math)\s*\n', dotAll: true).hasMatch(response);
  }

  @override
  State<AIVisualRenderer> createState() => _AIVisualRendererState();
}

class _AIVisualRendererState extends State<AIVisualRenderer> {
  late List<double> _currentValues;
  late List<String> _currentLabels;
  final GlobalKey _visualKey = GlobalKey();

  bool _isEditing = false;

  late double _editRadius;
  late String _editLabel;
  late List<Offset> _editPoints;
  late String _editExpression;
  late double _editXMin;
  late double _editXMax;
  late double _editYMin;
  late double _editYMax;
  late TextEditingController _exprCtrl;
  late TextEditingController _labelCtrl;
  late TextEditingController _svgCtrl;

  @override
  void initState() {
    super.initState();
    _currentValues = List<double>.from(widget.visual.values ?? []);
    _currentLabels = List<String>.from(widget.visual.labels ?? []);
    _editRadius = widget.visual.radius ?? 1.5;
    _editLabel = widget.visual.title ?? '';
    _editPoints = (widget.visual.points ?? []).map((p) => Offset(p[0], p[1])).toList();
    _editExpression = widget.visual.expression ?? 'x';
    _editXMin = widget.visual.xMin ?? -10;
    _editXMax = widget.visual.xMax ?? 10;
    _editYMin = widget.visual.yMin ?? -10;
    _editYMax = widget.visual.yMax ?? 10;
    _exprCtrl = TextEditingController(text: _editExpression);
    _labelCtrl = TextEditingController(text: _editLabel);
    final svgInitial = widget.visual.svgSource ?? widget.visual.codeSource ?? widget.visual.rawSpec ?? '';
    _svgCtrl = TextEditingController(text: svgInitial);
  }

  @override
  void dispose() {
    _exprCtrl.dispose();
    _labelCtrl.dispose();
    _svgCtrl.dispose();
    super.dispose();
  }

  ParsedVisual get visual => widget.visual;

  bool get _canEdit =>
      visual.type == VisualType.circle ||
      visual.type == VisualType.triangle ||
      visual.type == VisualType.quadrilateral ||
      visual.type == VisualType.polygon ||
      visual.type == VisualType.angle ||
      visual.type == VisualType.tangent ||
      visual.type == VisualType.graph ||
      visual.type == VisualType.svg ||
      visual.type == VisualType.mermaid;

  @override
  Widget build(BuildContext context) {
    Widget visualWidget;
    switch (visual.type) {
      case VisualType.graph:
        visualWidget = _buildGraph();
      case VisualType.barChart:
      case VisualType.pieChart:
      case VisualType.histogram:
      case VisualType.lineChart:
      case VisualType.frequencyPolygon:
      case VisualType.cumulativeFrequency:
        visualWidget = _buildChartWithGrid(_chartTypeFor(visual.type));
      case VisualType.triangle:
      case VisualType.circle:
      case VisualType.quadrilateral:
      case VisualType.polygon:
      case VisualType.angle:
      case VisualType.tangent:
        visualWidget = _buildShape();
      case VisualType.svg:
        visualWidget = _buildSvg();
      case VisualType.mermaid:
        visualWidget = _buildMermaid();
      case VisualType.html:
        visualWidget = _buildHtmlVisual();
      case VisualType.latexBlock:
        visualWidget = _buildLatexBlock();
      default:
        visualWidget = _buildFallback();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: _visualKey,
          child: visualWidget,
        ),
        if (_isEditing) _buildEditPanel(),
        VisualActionControls(
          visual: visual,
          visualKey: _visualKey,
          isEditing: _isEditing,
          canEdit: _canEdit,
          onEditToggle: () => setState(() => _isEditing = !_isEditing),
        ),
      ],
    );
  }

  StatisticalChartType _chartTypeFor(VisualType t) => switch (t) {
        VisualType.barChart => StatisticalChartType.bar,
        VisualType.pieChart => StatisticalChartType.pie,
        VisualType.histogram => StatisticalChartType.histogram,
        VisualType.lineChart => StatisticalChartType.line,
        VisualType.frequencyPolygon => StatisticalChartType.frequencyPolygon,
        VisualType.cumulativeFrequency => StatisticalChartType.cumulativeFrequency,
        _ => StatisticalChartType.bar,
      };

  // ── Graph ────────────────────────────────────────────────────────

  Widget _buildGraph() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visual.title != null && !_isEditing)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(visual.title!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        SizedBox(
          height: 280,
          child: FunctionPlotter(
            functions: [
              FunctionPlotConfig(
                expression: _editExpression,
                color: Colors.cyanAccent,
                label: 'y',
              ),
            ],
            xMin: _editXMin,
            xMax: _editXMax,
            yMin: _editYMin,
            yMax: _editYMax,
          ),
        ),
      ],
    );
  }

  // ── Charts ───────────────────────────────────────────────────────

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

  // ── Shape ────────────────────────────────────────────────────────

  Widget _buildShape() {
    final pts = _editPoints.isNotEmpty ? _editPoints : (visual.points ?? []).map((p) => Offset(p[0], p[1])).toList();
    final shape = GeometricShape(
      type: _mapShapeType(visual.shapeType ?? 'triangle'),
      label: _editLabel.isNotEmpty ? _editLabel : null,
      points: pts,
      radius: _editRadius,
    );
    return GeometricShapeRenderer(
      shapes: [shape],
      width: 380,
      height: 340,
    );
  }

  // ── SVG ──────────────────────────────────────────────────────────

  Widget _buildSvg() {
    final svgCode = _isEditing ? _svgCtrl.text : (visual.svgSource ?? '');
    return SvgRenderWidget(svgString: svgCode);
  }

  // ── Mermaid ──────────────────────────────────────────────────────

  Widget _buildMermaid() {
    final code = _isEditing ? _svgCtrl.text : (visual.codeSource ?? '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyanAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_rounded, size: 18, color: Colors.cyanAccent.withAlpha(200)),
              const SizedBox(width: 8),
              Text(
                _editLabel.isNotEmpty ? _editLabel : (visual.title ?? 'Diagram'),
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withAlpha(60), borderRadius: BorderRadius.circular(6)),
            child: SelectableText(
              code.trim(),
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace', height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── HTML ─────────────────────────────────────────────────────────

  Widget _buildHtmlVisual() {
    final code = visual.codeSource ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orangeAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.html_rounded, size: 18, color: Colors.orangeAccent.withAlpha(200)),
              const SizedBox(width: 8),
              const Text(
                'HTML Visual',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withAlpha(60), borderRadius: BorderRadius.circular(6)),
            child: SelectableText(
              code.length > 300 ? '${code.substring(0, 300)}...' : code,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace', height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── LaTeX ────────────────────────────────────────────────────────

  Widget _buildLatexBlock() {
    final code = visual.expression ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purpleAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.functions_rounded, size: 18, color: Colors.purpleAccent.withAlpha(200)),
              const SizedBox(width: 8),
              const Text(
                'Equation',
                style: TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StemText(
            code.trim(),
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
            selectable: true,
          ),
        ],
      ),
    );
  }

  // ── Fallback ─────────────────────────────────────────────────────

  Widget _buildFallback() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, color: Colors.white38, size: 16),
          SizedBox(width: 8),
          Text('Visual representation', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Edit Panel ───────────────────────────────────────────────────

  Widget _buildEditPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141522),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.cyanAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.edit_rounded, size: 16, color: Colors.cyanAccent.withAlpha(200)),
              const SizedBox(width: 8),
              const Text(
                'Edit Parameters',
                style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildEditFields(),
        ],
      ),
    );
  }

  List<Widget> _buildEditFields() {
    switch (visual.type) {
      case VisualType.circle:
      case VisualType.tangent:
        return _buildCircleEditFields();
      case VisualType.triangle:
      case VisualType.quadrilateral:
      case VisualType.polygon:
      case VisualType.angle:
        return _buildShapeEditFields();
      case VisualType.graph:
        return _buildGraphEditFields();
      case VisualType.svg:
      case VisualType.mermaid:
        return _buildCodeEditFields();
      default:
        return [];
    }
  }

  List<Widget> _buildCircleEditFields() {
    return [
      _buildLabelField(),
      const SizedBox(height: 10),
      _buildSliderField(
        label: 'Radius',
        value: _editRadius,
        min: 0.2,
        max: 3.0,
        onChanged: (v) => setState(() => _editRadius = v),
      ),
    ];
  }

  List<Widget> _buildShapeEditFields() {
    return [
      _buildLabelField(),
      const SizedBox(height: 10),
      if (_editPoints.isNotEmpty) ...[
        const Text('Vertices', style: TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 6),
        ...List.generate(_editPoints.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    'P${i + 1}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
                Expanded(
                  child: _buildCompactTextField(
                    value: _editPoints[i].dx.toStringAsFixed(2),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? _editPoints[i].dx;
                      setState(() {
                        _editPoints[i] = Offset(val, _editPoints[i].dy);
                      });
                    },
                    label: 'X',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactTextField(
                    value: _editPoints[i].dy.toStringAsFixed(2),
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? _editPoints[i].dy;
                      setState(() {
                        _editPoints[i] = Offset(_editPoints[i].dx, val);
                      });
                    },
                    label: 'Y',
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ];
  }

  List<Widget> _buildGraphEditFields() {
    return [
      _buildLabelField(),
      const SizedBox(height: 10),
      const Text('Expression', style: TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 6),
      TextField(
        controller: _exprCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
        decoration: InputDecoration(
          hintText: 'e.g. x^2, sin(x), 2*x+1',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.cyanAccent),
          ),
          filled: true,
          fillColor: Colors.black.withAlpha(60),
        ),
        onChanged: (v) => setState(() => _editExpression = v),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _buildCompactTextField(
              value: _editXMin.toStringAsFixed(0),
              onChanged: (v) => setState(() => _editXMin = double.tryParse(v) ?? _editXMin),
              label: 'X min',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactTextField(
              value: _editXMax.toStringAsFixed(0),
              onChanged: (v) => setState(() => _editXMax = double.tryParse(v) ?? _editXMax),
              label: 'X max',
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(
            child: _buildCompactTextField(
              value: _editYMin.toStringAsFixed(0),
              onChanged: (v) => setState(() => _editYMin = double.tryParse(v) ?? _editYMin),
              label: 'Y min',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildCompactTextField(
              value: _editYMax.toStringAsFixed(0),
              onChanged: (v) => setState(() => _editYMax = double.tryParse(v) ?? _editYMax),
              label: 'Y max',
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildCodeEditFields() {
    return [
      _buildLabelField(),
      const SizedBox(height: 10),
      const Text('Source Code', style: TextStyle(color: Colors.white60, fontSize: 11)),
      const SizedBox(height: 6),
      TextField(
        controller: _svgCtrl,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace', height: 1.5),
        maxLines: 8,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.all(10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.cyanAccent),
          ),
          filled: true,
          fillColor: Colors.black.withAlpha(60),
        ),
        onChanged: (_) => setState(() {}),
      ),
    ];
  }

  Widget _buildLabelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Label / Title', style: TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 6),
        TextField(
          controller: _labelCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter label...',
            hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Colors.cyanAccent),
            ),
            filled: true,
            fillColor: Colors.black.withAlpha(60),
          ),
          onChanged: (v) => setState(() => _editLabel = v),
        ),
      ],
    );
  }

  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.cyanAccent,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.cyanAccent,
            overlayColor: Colors.cyanAccent.withAlpha(30),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTextField({
    required String value,
    required ValueChanged<String> onChanged,
    required String label,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]'))],
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.cyanAccent),
        ),
        filled: true,
        fillColor: Colors.black.withAlpha(40),
      ),
      onChanged: onChanged,
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

// ── Helper widgets (unchanged) ───────────────────────────────────

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
            child: StemText(
              description!,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              selectable: true,
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
      child: StemText(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        selectable: true,
      ),
    );
  }
}
