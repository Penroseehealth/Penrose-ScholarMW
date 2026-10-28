import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../vtc_theme.dart';

class RecordingWaveIndicator extends StatefulWidget {
  const RecordingWaveIndicator({
    super.key,
    this.size = 18,
    this.color = VtcPalette.gold,
    this.active = true,
  });

  final double size;
  final Color color;
  final bool active;

  @override
  State<RecordingWaveIndicator> createState() => _RecordingWaveIndicatorState();
}

class _RecordingWaveIndicatorState extends State<RecordingWaveIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return SizedBox(width: widget.size * 2.2, height: widget.size);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size * 2.2, widget.size),
          painter: _WavePainter(
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final maxR = math.min(size.width, size.height) / 2;
    for (var i = 0; i < 3; i++) {
      final t = (progress + i * 0.18) % 1.0;
      final r = maxR * (0.25 + t * 0.9);
      final alpha = (1.0 - t).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(Offset(size.width / 2, centerY), r, paint);
    }
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, centerY), maxR * 0.22, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

