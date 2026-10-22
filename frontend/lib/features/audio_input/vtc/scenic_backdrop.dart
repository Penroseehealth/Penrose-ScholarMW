import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'vtc_theme.dart';

/// Full-bleed cinematic backdrop: violet/blue sunset sky, warm horizon sun,
/// layered mountain ridges, a calm lake with the sun's reflection and a soft
/// atmospheric haze band.
///
/// Painted procedurally (no binary asset) so the scene scales to any viewport
/// and can react subtly to the workspace state.
class ScenicBackdrop extends StatelessWidget {
  const ScenicBackdrop({super.key, required this.child, this.animation, this.horizon = 0.635});

  final Widget child;

  /// Optional 0..1 loop used for the water shimmer and idle sun breathing.
  final Animation<double>? animation;

  /// Fraction of the height where the waterline sits.
  final double horizon;

  @override
  Widget build(BuildContext context) {
    final painter = _SceneryPainter(horizon: horizon, phase: animation);
    if (animation == null) {
      return CustomPaint(painter: painter, child: child);
    }
    return AnimatedBuilder(
      animation: animation!,
      child: child,
      builder: (context, child) => CustomPaint(painter: painter, child: child),
    );
  }
}

class _SceneryPainter extends CustomPainter {
  _SceneryPainter({required this.horizon, this.phase}) : super(repaint: phase);

  final double horizon;
  final Animation<double>? phase;

  static const double _kPi = math.pi;

  double get _t => phase?.value ?? 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = size.height;
    final horizonY = h * horizon;

    _paintSky(canvas, size, horizonY);
    _paintSun(canvas, size, horizonY);
    _paintStars(canvas, size, horizonY);
    _paintHaze(canvas, size, horizonY);
    _paintRidges(canvas, size, horizonY);
    _paintLake(canvas, size, horizonY);
    _paintVignette(canvas, size);
  }

  // -- sky -------------------------------------------------------------------

  void _paintSky(Canvas canvas, Size size, double horizonY) {
    final rect = Rect.fromLTWH(0, 0, size.width, horizonY);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF04061A),
          Color(0xFF0A1030),
          Color(0xFF1A1C55),
          Color(0xFF2A1E5C),
          Color(0xFF5B2A63),
          Color(0xFFA84C5A),
          Color(0xFFE08A55),
        ],
        stops: [0.0, 0.18, 0.40, 0.58, 0.76, 0.92, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void _paintSun(Canvas canvas, Size size, double horizonY) {
    final cx = size.width * 0.72;
    final cy = horizonY - size.height * 0.035;
    final breathe = 1.0 + 0.03 * math.sin(_t * _kPi * 2);

    // Wide atmospheric glow.
    canvas.drawCircle(
      Offset(cx, cy),
      size.height * 0.30 * breathe,
      Paint()
        ..shader = RadialGradient(
          colors: [
            VtcPalette.sunCore.withValues(alpha: 0.34),
            VtcPalette.sunset.withValues(alpha: 0.16),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: size.height * 0.30)),
    );
    // Sun disc, softened by haze.
    canvas.drawCircle(
      Offset(cx, cy),
      size.height * 0.052 * breathe,
      Paint()
        ..color = VtcPalette.sunCore.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  void _paintStars(Canvas canvas, Size size, double horizonY) {
    final rng = math.Random(20260928);
    final paint = Paint()..style = PaintingStyle.fill;
    final limit = horizonY * 0.55;
    for (var i = 0; i < 90; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * limit;
      // Fade stars out as they approach the bright horizon.
      final fade = (1.0 - (y / limit)).clamp(0.0, 1.0);
      final r = 0.6 + rng.nextDouble() * 1.1;
      paint.color = Colors.white.withValues(alpha: 0.05 + 0.35 * fade * rng.nextDouble());
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _paintHaze(Canvas canvas, Size size, double horizonY) {
    final rect = Rect.fromLTWH(0, horizonY - size.height * 0.10, size.width, size.height * 0.20);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            VtcPalette.sunset.withValues(alpha: 0.20),
            VtcPalette.sunCore.withValues(alpha: 0.26),
            VtcPalette.sunset.withValues(alpha: 0.14),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  // -- mountains -------------------------------------------------------------

  /// Deterministic ridge line: layered sine harmonics, no RNG state.
  double _ridgeY(double nx, double seed, double amp, double baseY) {
    final a = 0.58 * math.sin(nx * 2.10 + seed);
    final b = 0.27 * math.sin(nx * 4.70 + seed * 1.7);
    final c = 0.15 * math.sin(nx * 9.30 + seed * 2.3);
    return baseY - amp * (a + b + c);
  }

  void _paintRidges(Canvas canvas, Size size, double horizonY) {
    // Farthest to nearest. Atmospheric perspective: far ridges are lighter and
    // pick up more of the sunset, near ridges go deep and cool.
    const layers = <_Ridge>[
      _Ridge(seed: 0.7, ampF: 0.115, baseF: 0.030, color: Color(0xFF6B3F6E), rim: 0.30),
      _Ridge(seed: 2.9, ampF: 0.150, baseF: 0.012, color: Color(0xFF4A2A5C), rim: 0.34),
      _Ridge(seed: 5.1, ampF: 0.185, baseF: -0.010, color: Color(0xFF2C1A47), rim: 0.26),
      _Ridge(seed: 8.3, ampF: 0.215, baseF: -0.040, color: Color(0xFF151033), rim: 0.16),
    ];

    for (final layer in layers) {
      final baseY = horizonY + size.height * layer.baseF;
      final amp = size.height * layer.ampF;
      final path = _ridgePath(size, baseY, amp, layer.seed);
      canvas.drawPath(path, Paint()..color = layer.color);

      // Gold rim light along the crest, fading away from the sun (x ~ 0.72).
      final rim = _rimPath(size, baseY, amp, layer.seed);
      canvas.drawPath(
        rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              VtcPalette.gold.withValues(alpha: 0.0),
              VtcPalette.goldLight.withValues(alpha: layer.rim),
              VtcPalette.sunCore.withValues(alpha: layer.rim * 1.1),
              VtcPalette.gold.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.45, 0.72, 1.0],
          ).createShader(Offset.zero & size),
      );
    }
  }

  Path _ridgePath(Size size, double baseY, double amp, double seed) {
    final path = Path()..moveTo(0, size.height);
    const steps = 160;
    for (var i = 0; i <= steps; i++) {
      final nx = i / steps * 6.0;
      final x = i / steps * size.width;
      path.lineTo(x, _ridgeY(nx, seed, amp, baseY));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  /// A stroke that traces only the visible crest (not the closing edges).
  Path _rimPath(Size size, double baseY, double amp, double seed) {
    final path = Path();
    const steps = 160;
    for (var i = 0; i <= steps; i++) {
      final nx = i / steps * 6.0;
      final x = i / steps * size.width;
      final y = _ridgeY(nx, seed, amp, baseY) + 1.2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path;
  }

  // -- lake ------------------------------------------------------------------

  void _paintLake(Canvas canvas, Size size, double horizonY) {
    final rect = Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF6A3A5F), const Color(0xFF2B1B4C), const Color(0xFF120E32), const Color(0xFF070A20)],
          stops: const [0.0, 0.24, 0.62, 1.0],
        ).createShader(rect),
    );

    // Mirrored ridges, squashed and faded — the classic lake reflection.
    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(0, horizonY * 2);
    canvas.scale(1, -0.62);
    const layers = <_Ridge>[
      _Ridge(seed: 2.9, ampF: 0.150, baseF: 0.012, color: Color(0x332C1A47), rim: 0),
      _Ridge(seed: 5.1, ampF: 0.185, baseF: -0.010, color: Color(0x2E151033), rim: 0),
    ];
    for (final layer in layers) {
      final baseY = horizonY + size.height * layer.baseF;
      canvas.drawPath(_ridgePath(size, baseY, size.height * layer.ampF, layer.seed), Paint()..color = layer.color);
    }
    canvas.restore();

    // Sun glitter column, animated.
    final cx = size.width * 0.72;
    final columnWidth = size.width * 0.16;
    final column = Rect.fromLTRB(cx - columnWidth / 2, horizonY, cx + columnWidth / 2, size.height);
    canvas.drawRect(
      column,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            VtcPalette.sunCore.withValues(alpha: 0.42),
            VtcPalette.gold.withValues(alpha: 0.16),
            Colors.transparent,
          ],
        ).createShader(column),
    );

    // Horizontal shimmer lines; offsets drift with the phase.
    final rng = math.Random(4242);
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 46; i++) {
      final t = rng.nextDouble();
      final y = horizonY + (size.height - horizonY) * (t * t);
      final drift = math.sin(_t * _kPi * 2 + i * 1.7) * size.width * 0.012;
      final len = columnWidth * (0.20 + rng.nextDouble() * 0.75);
      final alpha = (0.30 * (1 - t) + 0.05).clamp(0.0, 1.0);
      paint
        ..color = VtcPalette.sunCore.withValues(alpha: alpha)
        ..strokeWidth = 0.8 + rng.nextDouble() * 1.6;
      canvas.drawLine(Offset(cx - len / 2 + drift, y), Offset(cx + len / 2 + drift, y), paint);
    }

    // Cool foreground water to seat the interface.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, const Color(0xCC04061A)],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  void _paintVignette(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.1, -0.1),
          radius: 1.05,
          colors: [Colors.transparent, Colors.transparent, const Color(0x73020612)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_SceneryPainter old) => old.horizon != horizon || old.phase != phase;
}

class _Ridge {
  const _Ridge({required this.seed, required this.ampF, required this.baseF, required this.color, required this.rim});

  final double seed;
  final double ampF;
  final double baseF;
  final Color color;
  final double rim;
}
