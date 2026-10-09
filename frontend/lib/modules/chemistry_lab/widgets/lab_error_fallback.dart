import 'package:flutter/material.dart';

import '../../../core/theme/theme_colors.dart';
import '../state/chemistry_lab_provider.dart';

/// Fallback UI shown when the 3D engine cannot run (no WebGL, load failure,
/// context loss, unsupported platform).
///
/// Provides an actionable explanation plus a static, labelled illustration
/// of laboratory apparatus (drawn with a [CustomPainter] — no 3D required),
/// so the educational flow continues without rendering.
class LabErrorFallback extends StatelessWidget {
  final ChemistryLabProvider provider;
  final VoidCallback? onRetry;

  const LabErrorFallback({super.key, required this.provider, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final canRetry = provider.isSupported && onRetry != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_in_ar_outlined, size: 56, color: Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          Text(
            '3D view unavailable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              provider.errorMessage ??
                  'The 3D laboratory could not start in this browser. '
                      'The guided experiment steps below remain fully usable.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          if (canRetry)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          const SizedBox(height: 20),
          // Static illustration keeps the lesson going without WebGL.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CustomPaint(
                painter: _ApparatusFallbackPainter(
                  strokeColor: colors.textMuted,
                  accent: const Color(0xFFF59E0B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Burette, conical flask and stand (static diagram)',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Simple line-art of a titration setup: stand, burette, conical flask.
class _ApparatusFallbackPainter extends CustomPainter {
  final Color strokeColor;
  final Color accent;

  _ApparatusFallbackPainter({required this.strokeColor, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()..color = accent.withValues(alpha: 0.15);
    final w = size.width;
    final h = size.height;

    // Base + stand rod
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, h * 0.9, w * 0.3, h * 0.05), const Radius.circular(4)),
      paint,
    );
    canvas.drawLine(Offset(w * 0.2, h * 0.9), Offset(w * 0.2, h * 0.08), paint);

    // Burette (tall thin tube on the stand)
    final burette = Rect.fromLTWH(w * 0.16, h * 0.1, w * 0.08, h * 0.55);
    canvas.drawRect(burette, paint);
    canvas.drawRect(burette, fill);
    // Stopcock + tip
    canvas.drawLine(Offset(w * 0.2, h * 0.65), Offset(w * 0.2, h * 0.72), paint);
    canvas.drawCircle(Offset(w * 0.2, h * 0.67), 5, paint);
    // Clamp
    canvas.drawLine(Offset(w * 0.2, h * 0.3), Offset(w * 0.34, h * 0.3), paint);

    // Conical flask under the burette tip
    final flaskTop = Offset(w * 0.2, h * 0.76);
    final path = Path()
      ..moveTo(flaskTop.dx - w * 0.04, flaskTop.dy)
      ..lineTo(flaskTop.dx + w * 0.04, flaskTop.dy)
      ..lineTo(flaskTop.dx + w * 0.12, h * 0.92)
      ..lineTo(flaskTop.dx - w * 0.12, h * 0.92)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, fill);

    // Labels
    final tp = TextPainter(
      text: TextSpan(
        text: 'burette',
        style: TextStyle(color: strokeColor, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w * 0.26, h * 0.28));

    final tp2 = TextPainter(
      text: TextSpan(
        text: 'conical flask',
        style: TextStyle(color: strokeColor, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(w * 0.36, h * 0.84));
  }

  @override
  bool shouldRepaint(covariant _ApparatusFallbackPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor || oldDelegate.accent != accent;
}
