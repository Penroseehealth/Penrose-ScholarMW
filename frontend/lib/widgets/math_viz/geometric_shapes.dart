import 'dart:math';
import 'package:flutter/material.dart';

enum ShapeType {
  triangle,
  rightTriangle,
  quadrilateral,
  circle,
  semicircle,
  tangentCircle,
  parallelogram,
  trapezium,
  polygon,
  angle,
  cyclicQuadrilateral
}

class GeometricShape {
  final ShapeType type;
  final String? label;
  final Color color;
  final List<Offset> points;
  final double? radius;
  final List<ArcAnnotation>? arcs;
  final List<LineLabel>? labels;

  const GeometricShape({
    required this.type,
    this.label,
    this.color = Colors.cyanAccent,
    this.points = const [],
    this.radius,
    this.arcs,
    this.labels,
  });
}

class ArcAnnotation {
  final Offset center;
  final double radius;
  final double startAngle;
  final double sweepAngle;
  final String? label;
  const ArcAnnotation(
      {required this.center, required this.radius, required this.startAngle, required this.sweepAngle, this.label});
}

class LineLabel {
  final Offset start;
  final Offset end;
  final String text;
  const LineLabel({required this.start, required this.end, required this.text});
}

class GeometricShapeRenderer extends StatelessWidget {
  final List<GeometricShape> shapes;
  final double? width;
  final double? height;

  const GeometricShapeRenderer({super.key, required this.shapes, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _ShapePainter(shapes: shapes),
          );
        },
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  final List<GeometricShape> shapes;

  _ShapePainter({required this.shapes});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final scale = min(w, h) * 0.42;

    for (final shape in shapes) {
      final paint = Paint()
        ..color = shape.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final fillPaint = Paint()
        ..color = shape.color.withAlpha(25)
        ..style = PaintingStyle.fill;

      final textPaint = Paint()..color = shape.color;

      final labelStyle = TextStyle(color: shape.color, fontSize: 12, fontWeight: FontWeight.w500);

      switch (shape.type) {
        case ShapeType.circle:
          final r = (shape.radius ?? 1.5) * scale;
          final c = shape.points.isNotEmpty ? _map(shape.points[0], center, scale) : center;
          canvas.drawCircle(c, r, fillPaint);
          canvas.drawCircle(c, r, paint);
          _drawPoint(canvas, c, textPaint);
          if (shape.label != null) _drawLabel(canvas, c + Offset(0, -r - 16), shape.label!, labelStyle);

        case ShapeType.semicircle:
          final r = (shape.radius ?? 1.0) * scale;
          final c = shape.points.isNotEmpty ? _map(shape.points[0], center, scale) : center;
          final rect = Rect.fromCircle(center: c, radius: r);
          canvas.drawArc(rect, 0, pi, false, fillPaint);
          canvas.drawArc(rect, 0, pi, false, paint);
          canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
          _drawPoint(canvas, c, textPaint);

        case ShapeType.triangle:
        case ShapeType.rightTriangle:
          final pts = _mapPoints(shape.points, center, scale, 3);
          final path = Path()..moveTo(pts[0].dx, pts[0].dy);
          for (int i = 1; i < pts.length; i++) {
            path.lineTo(pts[i].dx, pts[i].dy);
          }
          path.close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, paint);
          for (final p in pts) _drawPoint(canvas, p, textPaint);
          if (shape.type == ShapeType.rightTriangle && pts.length >= 3) {
            _drawRightAngle(canvas, pts[1], pts[0], pts[2], paint);
          }
          if (shape.labels != null) {
            for (final lb in shape.labels!) {
              final mid = Offset((lb.start.dx + lb.end.dx) / 2, (lb.start.dy + lb.end.dy) / 2);
              _drawLabel(canvas, mid, lb.text, labelStyle.copyWith(fontSize: 11));
            }
          }

        case ShapeType.quadrilateral:
        case ShapeType.parallelogram:
        case ShapeType.trapezium:
        case ShapeType.cyclicQuadrilateral:
          final pts = _mapPoints(shape.points, center, scale, 4);
          final path = Path()..moveTo(pts[0].dx, pts[0].dy);
          for (int i = 1; i < pts.length; i++) {
            path.lineTo(pts[i].dx, pts[i].dy);
          }
          path.close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, paint);
          for (final p in pts) _drawPoint(canvas, p, textPaint);
          if (shape.type == ShapeType.cyclicQuadrilateral) {
            final cx = pts.map((p) => p.dx).reduce((a, b) => a + b) / 4;
            final cy = pts.map((p) => p.dy).reduce((a, b) => a + b) / 4;
            final avgR = pts.map((p) => sqrt(pow(p.dx - cx, 2) + pow(p.dy - cy, 2))).reduce((a, b) => a + b) / 4;
            canvas.drawCircle(
                Offset(cx, cy),
                avgR,
                Paint()
                  ..color = shape.color.withAlpha(40)
                  ..style = PaintingStyle.stroke);
          }

        case ShapeType.polygon:
          final n = shape.points.length;
          final pts = _mapPoints(shape.points, center, scale, n);
          final path = Path()..moveTo(pts[0].dx, pts[0].dy);
          for (int i = 1; i < pts.length; i++) {
            path.lineTo(pts[i].dx, pts[i].dy);
          }
          path.close();
          canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, paint);
          for (final p in pts) _drawPoint(canvas, p, textPaint);

        case ShapeType.tangentCircle:
          final r1 = (shape.radius ?? 1.2) * scale;
          final c = shape.points.isNotEmpty ? _map(shape.points[0], center, scale) : center;
          canvas.drawCircle(c, r1, fillPaint);
          canvas.drawCircle(c, r1, paint);
          _drawPoint(canvas, c, textPaint);
          final tangentPt = Offset(c.dx + r1, c.dy);
          final tangentLineEnd = Offset(c.dx + r1, c.dy - r1 * 1.5);
          canvas.drawLine(
              tangentPt,
              tangentLineEnd,
              Paint()
                ..color = Colors.orangeAccent
                ..strokeWidth = 2);
          _drawPoint(canvas, tangentPt, Paint()..color = Colors.orangeAccent);
          if (shape.label != null) _drawLabel(canvas, tangentPt + Offset(8, 0), shape.label!, labelStyle);

        case ShapeType.angle:
          if (shape.points.length >= 3) {
            final p1 = _map(shape.points[0], center, scale);
            final vertex = _map(shape.points[1], center, scale);
            final p2 = _map(shape.points[2], center, scale);
            canvas.drawLine(vertex, p1, paint);
            canvas.drawLine(vertex, p2, paint);
            _drawPoint(canvas, vertex, textPaint);
            _drawPoint(canvas, p1, textPaint);
            _drawPoint(canvas, p2, textPaint);
            if (shape.arcs != null) {
              for (final arc in shape.arcs!) {
                final arcPaint = Paint()
                  ..color = Colors.orangeAccent
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.5;
                final arcCenter = _map(arc.center, center, scale);
                final rect = Rect.fromCircle(center: arcCenter, radius: arc.radius * scale * 0.3);
                canvas.drawArc(rect, arc.startAngle, arc.sweepAngle, false, arcPaint);
                if (arc.label != null) {
                  final midAngle = arc.startAngle + arc.sweepAngle / 2;
                  final labelPos = arcCenter + Offset(cos(midAngle), sin(midAngle)) * arc.radius * scale * 0.5;
                  _drawLabel(
                      canvas, labelPos, arc.label!, labelStyle.copyWith(fontSize: 10, color: Colors.orangeAccent));
                }
              }
            }
          }
      }

      if (shape.label != null && shape.type != ShapeType.circle && shape.type != ShapeType.tangentCircle) {
        _drawLabel(canvas, Offset(w / 2, h - 20), shape.label!, labelStyle);
      }
    }
  }

  void _drawRightAngle(Canvas canvas, Offset vertex, Offset p1, Offset p2, Paint paint) {
    final d1 = Offset(p1.dx - vertex.dx, p1.dy - vertex.dy);
    final d2 = Offset(p2.dx - vertex.dx, p2.dy - vertex.dy);
    final len1 = sqrt(d1.dx * d1.dx + d1.dy * d1.dy);
    final len2 = sqrt(d2.dx * d2.dx + d2.dy * d2.dy);
    if (len1 == 0 || len2 == 0) return;
    final u1 = Offset(d1.dx / len1 * 15, d1.dy / len1 * 15);
    final u2 = Offset(d2.dx / len2 * 15, d2.dy / len2 * 15);
    final sqPaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final path = Path()
      ..moveTo(vertex.dx + u1.dx, vertex.dy + u1.dy)
      ..lineTo(vertex.dx + u1.dx + u2.dx, vertex.dy + u1.dy + u2.dy)
      ..lineTo(vertex.dx + u2.dx, vertex.dy + u2.dy);
    canvas.drawPath(path, sqPaint);
  }

  Offset _map(Offset p, Offset center, double scale) => Offset(center.dx + p.dx * scale, center.dy - p.dy * scale);

  List<Offset> _mapPoints(List<Offset> points, Offset center, double scale, int needed) {
    if (points.length >= needed) return points.take(needed).map((p) => _map(p, center, scale)).toList();
    final defaultShapes = {
      3: [Offset(-0.8, -0.6), Offset(0.8, -0.6), Offset(0, 0.8)],
      4: [Offset(-0.8, -0.6), Offset(0.8, -0.6), Offset(0.8, 0.6), Offset(-0.8, 0.6)],
    };
    final defaults = defaultShapes[needed] ??
        List.generate(needed, (i) {
          final angle = 2 * pi * i / needed - pi / 2;
          return Offset(cos(angle), sin(angle));
        });
    return defaults.map((p) => _map(p, center, scale)).toList();
  }

  void _drawPoint(Canvas canvas, Offset p, Paint paint) {
    canvas.drawCircle(p, 3, paint..style = PaintingStyle.fill);
  }

  void _drawLabel(Canvas canvas, Offset p, String text, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
