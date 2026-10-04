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
