import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'geometry_board.dart';
import 'math_solution.dart';

/// Shows a picture only when a picture actually helps.
///
/// The picture is derived entirely from the verified numbers in the solution,
/// so it can never disagree with the written steps. When a problem has no
/// meaningful visual (a plain arithmetic simplification, for example) the card
/// collapses to nothing rather than reserving empty space.
class TutorVisualCard extends StatelessWidget {
  const TutorVisualCard({
    super.key,
    required this.solution,
    required this.stepIndex,
  });

  final TutorSolution solution;
  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = solution.visualData?['caption']?.toString();

    final Widget? art = switch (solution.visualKind) {
      TutorVisualKind.rightTriangle => GeometryBoard(solution: solution, stepIndex: stepIndex),
      TutorVisualKind.parabola => AspectRatio(
          aspectRatio: 1.7,
          child: CustomPaint(
            painter: _ParabolaPainter(
              params: solution.visualData?['params'] as Map<String, dynamic>? ?? const <String, dynamic>{},
              stroke: scheme.primary,
              axis: scheme.outlineVariant,
              label: scheme.onSurfaceVariant,
            ),
          ),
        ),
      TutorVisualKind.percentageBar => AspectRatio(
          aspectRatio: 3.2,
          child: CustomPaint(
            painter: _PercentageBarPainter(
              data: solution.visualData ?? const <String, dynamic>{},
              fill: scheme.primary,
              track: scheme.surfaceContainerHighest,
              label: scheme.onSurface,
            ),
          ),
        ),
      TutorVisualKind.figure => AspectRatio(
          aspectRatio: 1.5,
          child: CustomPaint(
            painter: _FigurePainter(
              data: solution.visualData ?? const <String, dynamic>{},
              line: scheme.primary,
              accent: scheme.tertiary,
              label: scheme.onSurface,
              axis: scheme.outlineVariant,
              fill: scheme.primary.withAlpha(28),
              surface: scheme.surface,
            ),
          ),
        ),
      _ => null,
    };

    if (art == null) return const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.insights_rounded, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text('Visual', style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            art,
            if (caption != null && caption.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                caption,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParabolaPainter extends CustomPainter {
  _ParabolaPainter({
    required this.params,
    required this.stroke,
    required this.axis,
    required this.label,
  });

  final Map<String, dynamic> params;
  final Color stroke;
  final Color axis;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final a = (params['a'] as num?)?.toDouble() ?? 1;
    final b = (params['b'] as num?)?.toDouble() ?? 0;
    final c = (params['c'] as num?)?.toDouble() ?? 0;
    final hasRoots = params['has_real_roots'] == true;
    final roots = ((params['roots'] as List?) ?? const []).whereType<num>().map((n) => n.toDouble()).toList();

    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = 1.2;
    final curvePaint = Paint()
      ..color = stroke
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    // Work out a symmetric window around the vertex and the roots.
    final vertexX = -b / (2 * a);
    final span = roots.isEmpty
        ? math.max(4.0, vertexX.abs() + 3)
        : math.max(3.0, roots.reduce((x, y) => math.max((x - vertexX).abs(), (y - vertexX).abs())) + 2);
    final xMin = vertexX - span;
    final xMax = vertexX + span;

    final ys = <double>[];
    for (var i = 0; i <= 40; i++) {
      final x = xMin + (xMax - xMin) * i / 40;
      ys.add(a * x * x + b * x + c);
    }
    final yMin = math.min(0.0, ys.reduce(math.min));
    final yMax = math.max(0.0, ys.reduce(math.max));
    final yPad = (yMax - yMin) == 0 ? 1.0 : (yMax - yMin) * 0.15;

    Offset toPixel(double x, double y) => Offset(
          (x - xMin) / (xMax - xMin) * size.width,
          size.height - (y - (yMin - yPad)) / ((yMax + yPad) - (yMin - yPad)) * size.height,
        );

    // Axes through the origin where visible.
    final origin = toPixel(0, 0);
    canvas.drawLine(Offset(0, origin.dy), Offset(size.width, origin.dy), axisPaint);
    canvas.drawLine(Offset(origin.dx, 0), Offset(origin.dx, size.height), axisPaint);

    final path = Path();
    for (var i = 0; i <= 40; i++) {
      final x = xMin + (xMax - xMin) * i / 40;
      final point = toPixel(x, a * x * x + b * x + c);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, curvePaint);

    if (hasRoots && roots.isNotEmpty) {
      final dot = Paint()..color = stroke;
      for (final root in roots) {
        final point = toPixel(root, 0);
        canvas.drawCircle(point, 4.5, dot);
        _text(canvas, _fmt(root), Offset(point.dx, point.dy + 16), label);
      }
    }
  }

  void _text(Canvas canvas, String value, Offset centre, Color colour) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: TextStyle(color: colour, fontSize: 11, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(centre.dx - painter.width / 2, centre.dy - painter.height / 2));
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return ((value * 100).round() / 100).toString();
  }

  @override
  bool shouldRepaint(_ParabolaPainter oldDelegate) => oldDelegate.params != params;
}

class _PercentageBarPainter extends CustomPainter {
  _PercentageBarPainter({
    required this.data,
    required this.fill,
    required this.track,
    required this.label,
  });

  final Map<String, dynamic> data;
  final Color fill;
  final Color track;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    final whole = (data['whole'] as num?)?.toDouble() ?? 0;
    final part = (data['part'] as num?)?.toDouble() ?? 0;
    final fraction = whole == 0 ? 0.0 : (part / whole).clamp(0.0, 1.0);

    final bar = Rect.fromLTWH(0, size.height * 0.24, size.width, size.height * 0.34);
    final radius = Radius.circular(bar.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(bar, radius), Paint()..color = track);
    if (fraction > 0) {
      final shaded = Rect.fromLTWH(bar.left, bar.top, bar.width * fraction, bar.height);
      canvas.drawRRect(RRect.fromRectAndRadius(shaded, radius), Paint()..color = fill);
    }

    _text(canvas, _fmt(part), Offset(bar.width * fraction / 2, bar.center.dy), Colors.white);
    _text(canvas, _fmt(whole - part), Offset(bar.left + bar.width * (fraction + (1 - fraction) / 2), bar.center.dy),
        label);
  }

  void _text(Canvas canvas, String value, Offset centre, Color colour) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: TextStyle(color: colour, fontSize: 13, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(centre.dx - painter.width / 2, centre.dy - painter.height / 2));
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return ((value * 100).round() / 100).toString();
  }

  @override
  bool shouldRepaint(_PercentageBarPainter oldDelegate) => oldDelegate.data != data;
}

/// Draws the server's diagram primitives (segments, polygons, circles, bars and
/// labels) in the problem's own coordinate space, with a slight hand-drawn
/// wobble. Because every primitive comes from the verified numbers, the picture
/// can never disagree with the written solution.
class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.data,
    required this.line,
    required this.accent,
    required this.label,
    required this.axis,
    required this.fill,
    required this.surface,
  });

  final Map<String, dynamic> data;
  final Color line;
  final Color accent;
  final Color label;
  final Color axis;
  final Color fill;
  final Color surface;

  late Offset Function(double, double) _toPx;
  late double _scale;
  late Paint _stroke;
  late Paint _axisStroke;
  late Paint _fillPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, dynamic> view = (data['view'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final double xmin = (view['xmin'] as num?)?.toDouble() ?? -1;
    final double xmax = (view['xmax'] as num?)?.toDouble() ?? 1;
    final double ymin = (view['ymin'] as num?)?.toDouble() ?? -1;
    final double ymax = (view['ymax'] as num?)?.toDouble() ?? 1;
    final double spanX = (xmax - xmin).abs() < 1e-9 ? 1 : (xmax - xmin);
    final double spanY = (ymax - ymin).abs() < 1e-9 ? 1 : (ymax - ymin);

    const double pad = 16;
    final double innerW = math.max(size.width - pad * 2, 10);
    final double innerH = math.max(size.height - pad * 2, 10);
    _scale = math.min(innerW / spanX, innerH / spanY);
    final double originX = pad + (innerW - spanX * _scale) / 2;
    final double originY = pad + (innerH - spanY * _scale) / 2;
    _toPx = (double x, double y) => Offset(originX + (x - xmin) * _scale, originY + (ymax - y) * _scale);

    _stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _axisStroke = Paint()
      ..color = axis
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    _fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    final List<dynamic> primitives = (data['primitives'] as List?) ?? const <dynamic>[];
    for (final dynamic raw in primitives) {
      final Map<String, dynamic> primitive = _asMap(raw);
      switch (primitive['type']?.toString()) {
        case 'axes':
          _drawAxes(canvas, xmin, xmax, ymin, ymax);
        case 'rect':
          _drawRect(canvas, primitive);
        case 'polygon':
          _drawPolygon(canvas, primitive);
        case 'circle':
          _drawCircle(canvas, primitive);
        case 'path':
          _drawPath(canvas, primitive);
        case 'segment':
          _drawSegment(canvas, primitive);
        default:
          break;
      }
    }
    // Points and free labels sit on top of the shapes.
    for (final dynamic raw in primitives) {
      final Map<String, dynamic> primitive = _asMap(raw);
      final String? type = primitive['type']?.toString();
      if (type == 'point') {
        _drawPoint(canvas, primitive);
      } else if (type == 'label') {
        _text(canvas, primitive['text']?.toString() ?? '', _toPx(_num(primitive['x']), _num(primitive['y'])), label,
            11.5, FontWeight.w600);
      }
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map) return raw.map((dynamic key, dynamic value) => MapEntry(key.toString(), value));
    return const <String, dynamic>{};
  }

  double _num(dynamic value) => (value as num?)?.toDouble() ?? 0;

  void _drawAxes(Canvas canvas, double xmin, double xmax, double ymin, double ymax) {
    if (0 >= ymin && 0 <= ymax) {
      final Offset left = _toPx(xmin, 0);
      final Offset right = _toPx(xmax, 0);
      canvas.drawLine(left, right, _axisStroke);
      _arrow(canvas, right, const Offset(1, 0), _axisStroke);
    }
    if (0 >= xmin && 0 <= xmax) {
      final Offset bottom = _toPx(0, ymin);
      final Offset top = _toPx(0, ymax);
      canvas.drawLine(bottom, top, _axisStroke);
      _arrow(canvas, top, const Offset(0, -1), _axisStroke);
    }
  }

  void _arrow(Canvas canvas, Offset tip, Offset direction, Paint paint) {
    const double size = 7;
    final Offset back = tip - direction * size;
    final Offset normal = Offset(-direction.dy, direction.dx) * (size * 0.5);
    canvas.drawLine(tip, back + normal, paint);
    canvas.drawLine(tip, back - normal, paint);
  }

  void _drawRect(Canvas canvas, Map<String, dynamic> primitive) {
    final double x = _num(primitive['x']);
    final double y = _num(primitive['y']);
    final double w = _num(primitive['w']);
    final double h = _num(primitive['h']);
    final Rect rect = Rect.fromPoints(_toPx(x, y + h), _toPx(x + w, y));
    canvas.drawRect(rect, _fillPaint);
    canvas.drawRect(rect, _stroke);
    final String? caption = primitive['label']?.toString();
    if (caption != null && caption.isNotEmpty) {
      _textCentered(canvas, caption, Offset(rect.center.dx, rect.top - 8), label);
    }
  }

  void _drawPolygon(Canvas canvas, Map<String, dynamic> primitive) {
    final List<Offset> points = _pointsOf(primitive);
    if (points.length < 3) return;
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, _fillPaint);
    for (int index = 0; index < points.length; index++) {
      _handLine(canvas, points[index], points[(index + 1) % points.length], _stroke);
    }
    final String? caption = primitive['label']?.toString();
    if (caption != null && caption.isNotEmpty) {
      final Offset centroid = points.reduce((Offset a, Offset b) => a + b) / points.length.toDouble();
      _textCentered(canvas, caption, centroid, label);
    }
  }

  void _drawCircle(Canvas canvas, Map<String, dynamic> primitive) {
    final Offset centre = _toPx(_num(primitive['cx']), _num(primitive['cy']));
    final double radius = _num(primitive['r']) * _scale;
    canvas.drawCircle(centre, radius, _stroke);
    canvas.drawCircle(centre, 2.4, Paint()..color = line);
    final String? caption = primitive['label']?.toString();
    if (caption != null && caption.isNotEmpty) {
      _textCentered(canvas, caption, centre + Offset(0, -radius - 10), label);
    }
  }

  void _drawPath(Canvas canvas, Map<String, dynamic> primitive) {
    final List<Offset> points = _pointsOf(primitive);
    if (points.length < 2) return;
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final Offset point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, _stroke);
  }

  void _drawSegment(Canvas canvas, Map<String, dynamic> primitive) {
    final Offset a = _toPx(_num(primitive['x1']), _num(primitive['y1']));
    final Offset b = _toPx(_num(primitive['x2']), _num(primitive['y2']));
    final bool dashed = primitive['dashed'] == true;
    if (dashed) {
      _dashedLine(canvas, a, b, _stroke..color = line.withAlpha(160));
      _stroke.color = line;
    } else {
      _handLine(canvas, a, b, _stroke);
    }
    final String? caption = primitive['label']?.toString();
    if (caption != null && caption.isNotEmpty) {
      _textCentered(canvas, caption, (a + b) / 2 + const Offset(0, -10), label);
    }
  }

  void _drawPoint(Canvas canvas, Map<String, dynamic> primitive) {
    final Offset at = _toPx(_num(primitive['x']), _num(primitive['y']));
    final bool filled = primitive['filled'] != false && primitive['filled'] != 'false';
    final Paint dot = Paint()..color = filled ? accent : surface;
    canvas.drawCircle(at, 5, dot);
    canvas.drawCircle(
      at,
      5,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final String? caption = primitive['label']?.toString();
    if (caption != null && caption.isNotEmpty) {
      _text(canvas, caption, at + const Offset(8, -16), label, 11, FontWeight.w600);
    }
  }

  List<Offset> _pointsOf(Map<String, dynamic> primitive) {
    final List<dynamic> raw = (primitive['points'] as List?) ?? const <dynamic>[];
    return raw
        .whereType<List<dynamic>>()
        .where((List<dynamic> pair) => pair.length >= 2)
        .map((List<dynamic> pair) => _toPx(_num(pair[0]), _num(pair[1])))
        .toList(growable: false);
  }

  /// A nearly-straight line with a slight bow, so it reads as hand-drawn.
  void _handLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final double length = (b - a).distance;
    if (length < 1) {
      canvas.drawLine(a, b, paint);
      return;
    }
    final Offset direction = (b - a) / length;
    final Offset normal = Offset(-direction.dy, direction.dx);
    final double seed = a.dx * 12.9898 + a.dy * 78.233 + b.dx * 37.719 + b.dy * 4.669;
    final double bow = math.sin(seed) * math.min(2.2, length * 0.035);
    final Offset mid = (a + b) / 2 + normal * bow;
    final Path path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    canvas.drawPath(path, paint);
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final double total = (b - a).distance;
    if (total < 1) return;
    final Offset direction = (b - a) / total;
    const double dash = 7;
    const double gap = 5;
    double travelled = 0;
    while (travelled < total) {
      final Offset from = a + direction * travelled;
      final Offset to = a + direction * math.min(travelled + dash, total);
      canvas.drawLine(from, to, paint);
      travelled += dash + gap;
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color colour, double size, FontWeight weight) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: colour, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  void _textCentered(Canvas canvas, String text, Offset centre, Color colour) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: colour, fontSize: 11.5, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(centre.dx - painter.width / 2, centre.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(_FigurePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.line != line || oldDelegate.accent != accent;
}
