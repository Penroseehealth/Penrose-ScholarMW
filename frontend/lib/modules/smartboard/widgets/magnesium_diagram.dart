import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Board ink colour used across the lesson layer.
const Color kInk = Color(0xFF12294A);
const Color kInkMuted = Color(0xFF3F5570);
const Color kEmphasis = Color(0xFFB42318);

/// Electron population per shell of a neutral magnesium atom: K, L, M = 2, 8, 2.
/// This — not the drawing — is the source of truth for the diagram.
const List<int> kMagnesiumShells = <int>[2, 8, 2];

/// Mg²⁺ has lost its two valence electrons: K, L = 2, 8 (ten electrons).
const List<int> kMagnesiumIonShells = <int>[2, 8];

/// A live, editable-pipeline Bohr-style diagram for neutral magnesium.
///
/// Electron counts are fixed by the model, not by the drawing: K = 2,
/// L = 8, M = 2 (12 total). Nothing here is a flattened image.
class MagnesiumDiagram extends StatelessWidget {
  const MagnesiumDiagram({
    super.key,
    this.size = 290,
    this.highlightValence = true,
    this.ionised = false,
  });

  final double size;

  /// Draws the two outer electrons in the emphasis colour.
  final bool highlightValence;

  /// Renders Mg2+ (10 electrons, 2 / 8) when true.
  final bool ionised;

  @override
  Widget build(BuildContext context) {
    final List<int> shells = ionised ? kMagnesiumIonShells : kMagnesiumShells;
    return Semantics(
      label: ionised
          ? 'Magnesium 2+ ion Bohr diagram. Electron arrangement 2, 8. Ten electrons.'
          : 'Magnesium Bohr diagram. Electron arrangement 2, 8, 2. Twelve electrons.',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _BohrPainter(
            shellCounts: shells,
            highlightValence: highlightValence,
          ),
        ),
      ),
    );
  }
}

class _BohrPainter extends CustomPainter {
  _BohrPainter({required this.shellCounts, required this.highlightValence});

  final List<int> shellCounts;
  final bool highlightValence;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double maxRadius = math.min(size.width, size.height) / 2 - 12;
    final List<double> radii = <double>[maxRadius * 0.38, maxRadius * 0.68, maxRadius * 0.97];
    const List<String> shellNames = <String>['K', 'L', 'M'];

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = kInk.withValues(alpha: 0.35);

    for (var shell = 0; shell < radii.length; shell++) {
      canvas.drawCircle(centre, radii[shell], ring);
    }

    // Shell labels sit just inside the left edge of each ring.
    for (var shell = 0; shell < radii.length; shell++) {
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: shellNames[shell],
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kInkMuted.withValues(alpha: 0.8)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(centre.dx + radii[shell] - 14, centre.dy - 7));
    }

    final Paint nucleusFill = Paint()..color = kInk;
    canvas.drawCircle(centre, radii.first * 0.52, nucleusFill);

    final TextPainter nucleus = TextPainter(
      text: const TextSpan(
        text: 'Mg',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nucleus.paint(canvas, centre - Offset(nucleus.width / 2, nucleus.height / 2 + 7));

    final TextPainter protonCount = TextPainter(
      text: TextSpan(
        text: '12p',
        style: TextStyle(fontSize: 8.5, color: Colors.white.withValues(alpha: 0.85)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    protonCount.paint(canvas, centre - Offset(protonCount.width / 2, -nucleus.height / 2 + 1));

    // Stagger each shell's start angle so electrons never line up radially.
    const List<double> angleOffsets = <double>[-math.pi / 2, -math.pi / 2 + math.pi / 8, -math.pi / 2 + math.pi / 4];

    for (var shell = 0; shell < radii.length; shell++) {
      final int count = shellCounts[shell];
      for (var i = 0; i < count; i++) {
        final double angle = angleOffsets[shell] + (2 * math.pi / count) * i;
        final Offset position = centre + Offset(math.cos(angle), math.sin(angle)) * radii[shell];
        final bool isValence = highlightValence && shell == 2;
        final Paint dot = Paint()..color = isValence ? kEmphasis : const Color(0xFF1D4ED8);
        canvas.drawCircle(position, 7, dot);
        canvas.drawCircle(position, 2.2, Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BohrPainter oldDelegate) =>
      oldDelegate.highlightValence != highlightValence || !_sameShells(oldDelegate.shellCounts, shellCounts);

  static bool _sameShells(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
