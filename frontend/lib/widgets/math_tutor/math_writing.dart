import 'package:flutter/material.dart';

import '../../services/tutor_preferences.dart';
import '../handwriting/handwriting_board.dart';
import '../math_tutor/math_tex.dart';

/// Renders one line of mathematics the way the student asked for it.
///
/// Handwriting is the default: the answer is drawn as vector strokes on a plain
/// white board and written out step by step. Turning on computer typeset maths
/// switches the same line to the LaTeX renderer instead, so the two modes are
/// genuine alternatives and a student can move between them at any time.
class MathWriting extends StatelessWidget {
  const MathWriting(
    this.latex, {
    super.key,
    required this.preferences,
    this.fontSize = 20,
    this.animate,
    this.showGrid,
  });

  /// LaTeX (or plain text) to display.
  final String latex;

  final TutorPreferences preferences;

  final double fontSize;

  /// Overrides the "animate steps" preference for this line.
  final bool? animate;

  /// Overrides the grid preference for this line.
  final bool? showGrid;

  @override
  Widget build(BuildContext context) {
    final bool handwritten = preferences.showHandwriting;
    final bool animated = animate ?? preferences.animateSteps;
    final bool grid = showGrid ?? preferences.gridVisible;
    final Color ink = Theme.of(context).colorScheme.onSurface;

    final Widget content = handwritten
        ? HandwritingBoard(
            MathTex.plainText(latex),
            animate: animated,
            fontSize: fontSize,
            color: ink,
          )
        : MathTex(latex, fontSize: fontSize, color: ink);

    if (!grid) {
      // Plain whiteboard: nothing behind the writing unless the student asks
      // for graph paper, so the default really is a blank board.
      return Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: DefaultTextStyle(
          style: TextStyle(color: Colors.black87, fontSize: fontSize),
          child: IconTheme(
            data: const IconThemeData(color: Colors.black87),
            child: content,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: CustomPaint(
        painter: _GridPainter(),
        child: content,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = const Color(0xFF90A4AE).withValues(alpha: 0.25)
      ..strokeWidth = 0.6;
    const double step = 22;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
