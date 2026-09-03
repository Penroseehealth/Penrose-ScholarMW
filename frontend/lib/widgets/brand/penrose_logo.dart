import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

const kSilverGoldSilver = Color(0xFFE8E8EE);
const kSilverGoldMid = Color(0xFFEDE4C8);
const kSilverGoldGold = Color(0xFFE8C15A);
const kSilverGoldGoldBright = Color(0xFFFFE49A);

/// Renders the Silver-to-Gold brand wordmark in large bold type.
class SilverGoldTitle extends StatelessWidget {
  const SilverGoldTitle(
    this.text, {
    super.key,
    this.fontSize = 26,
  });

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.4,
      height: 1.1,
    );
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          kSilverGoldSilver,
          kSilverGoldGold,
          kSilverGoldGoldBright,
          kSilverGoldSilver,
        ],
        stops: [0.0, 0.45, 0.7, 1.0],
      ).createShader(rect),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

/// The Penrose (impossible) triangle, drawn as three interlocking bars in
/// deep-purple hues. Used as the brand logo mark.
class PenroseTriangle extends StatelessWidget {
  const PenroseTriangle({
    super.key,
    this.size = 72,
    this.triangleColor = AppColors.primaryMuted,
    this.highlightColor = AppColors.primaryLight,
    this.shadowColor = AppColors.primaryDark,
    this.gradient,
  });

  final double size;
  final Color triangleColor;
  final Color highlightColor;
  final Color shadowColor;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _PenroseTrianglePainter(
            triangleColor: triangleColor,
            highlightColor: highlightColor,
            shadowColor: shadowColor,
            gradient: gradient,
          ),
        ),
      );
}

class _PenroseTrianglePainter extends CustomPainter {
  _PenroseTrianglePainter({
    required this.triangleColor,
    required this.highlightColor,
    required this.shadowColor,
    required this.gradient,
  });

  final Color triangleColor;
  final Color highlightColor;
  final Color shadowColor;
  final List<Color>? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final r = side * 0.42;
    const s32 = 0.8660254;

    final aTop = center + Offset(0, -r);
    final aBR = center + Offset(r * s32, r * 0.5);
    final aBL = center + Offset(-r * s32, r * 0.5);
    final verts = <Offset>[aBL, aBR, aTop];
    final cen = (aTop + aBR + aBL) / 3;

    final bars = _buildBars(verts, cen, r * 0.42, 0.45);

    // The 3 bars tinted deep purple (darkest / base / lightest) for depth.
    final faces = <Color>[shadowColor, triangleColor, highlightColor];
    // Interlock draw order (matches the verified construction).
    final order = <int>[1, 2, 0];
    for (var k = 0; k < order.length; k++) {
      final i = order[k];
      final path = Path()..addPolygon(bars[i], true);
      final paint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill;
      if (gradient != null && gradient!.isNotEmpty) {
        paint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient!,
        ).createShader(Rect.fromCenter(center: center, width: size.width, height: size.height));
      } else {
        paint.color = faces[i];
      }
      canvas.drawPath(path, paint);

      final stroke = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, side * 0.014)
        ..color = highlightColor.withValues(alpha: 0.55);
      canvas.drawPath(path, stroke);
    }
  }

  /// Builds the three interlocked bars of the Penrose triangle.
  ///
  /// Each bar is an asymmetric trapezoid running beside one edge, offset toward
  /// the centroid and shifted along its edge so every bar wraps the following
  /// corner and recedes from the previous one — producing the impossible look.
  List<List<Offset>> _buildBars(
    List<Offset> verts,
    Offset centroid,
    double t,
    double shiftFactor,
  ) {
    final bars = <List<Offset>>[];
    final shift = t * shiftFactor;
    for (var i = 0; i < 3; i++) {
      final p = verts[i];
      final q = verts[(i + 1) % 3];
      final d = (q - p) / (q - p).distance;
      final mid = (p + q) / 2;
      Offset nv = centroid - mid;
      if (nv.distance == 0) nv = Offset(d.dy, -d.dx);
      nv = nv / nv.distance;

      final pOut = p + d * shift;
      final qOut = q + d * shift;
      final ip = pOut + nv * t;
      final iq = qOut + nv * t;
      final be = t * 0.9;
      final pEnd = ip + d * (-be);
      final qEnd = iq + d * be;
      bars.add(<Offset>[pOut, qOut, qEnd, iq, ip, pEnd]);
    }
    return bars;
  }

  @override
  bool shouldRepaint(_PenroseTrianglePainter oldDelegate) =>
      oldDelegate.triangleColor != triangleColor ||
      oldDelegate.highlightColor != highlightColor ||
      oldDelegate.shadowColor != shadowColor;
}
