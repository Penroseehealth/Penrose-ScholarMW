import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'handwriting_glyphs.dart';

/// Draws text as if a student had written it by hand, revealing it stroke by
/// stroke.
///
/// Nothing here is an image or a font file: every glyph is a list of vector
/// outlines from [glyphStrokes], converted to paths and stroked on a
/// [CustomPainter]. That keeps the output crisp at any size, lets a partial
/// stroke be drawn exactly part-way (which is what makes the animation look
/// like a moving pen rather than a fade), and means new characters can be added
/// as data only.
class HandwritingBoard extends StatefulWidget {
  const HandwritingBoard(
    this.text, {
    super.key,
    this.animate = true,
    this.fontSize = 22,
    this.color,
    this.maxWidth,
    this.showBaseline = false,
    this.strokeWidth,
    this.onComplete,
  });

  /// Plain text (not LaTeX) to write out.
  final String text;

  /// Whether strokes are revealed progressively. When false the writing appears
  /// complete immediately, which is what the "animate steps" preference uses
  /// once a student has already seen the derivation.
  final bool animate;

  final double fontSize;
  final Color? color;

  /// Wraps onto additional lines when a line would exceed this width.
  final double? maxWidth;

  /// Draws a faint ruled baseline, like paper.
  final bool showBaseline;

  final double? strokeWidth;
  final VoidCallback? onComplete;

  @override
  State<HandwritingBoard> createState() => HandwritingBoardState();
}

class HandwritingBoardState extends State<HandwritingBoard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<PlacedStroke> _strokes = const <PlacedStroke>[];
  int _strokeCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
      ..addStatusListener(_onStatus);
    _rebuild();
    if (widget.animate && _strokeCount > 0) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(HandwritingBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool needsLayout =
        oldWidget.text != widget.text || oldWidget.fontSize != widget.fontSize || oldWidget.maxWidth != widget.maxWidth;
    if (needsLayout) {
      _rebuild();
    }
    if (!widget.animate) {
      _controller.value = 1;
      widget.onComplete?.call();
    } else if (needsLayout || !oldWidget.animate) {
      replay();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onComplete?.call();
  }

  static Duration _durationFor(int strokes) {
    if (strokes <= 0) return const Duration(milliseconds: 200);
    return Duration(milliseconds: (strokes * 95).clamp(500, 7000));
  }

  /// Rewrites the working from the beginning.
  void replay() {
    if (!mounted) return;
    _controller
      ..duration = _durationFor(_strokeCount)
      ..forward(from: 0);
  }

  void _rebuild() {
    final HandwritingLayout layout = HandwritingLayout.build(
      widget.text,
      fontSize: widget.fontSize,
      maxWidth: widget.maxWidth,
    );
    _strokes = layout.strokes;
    _strokeCount = _strokes.length;
    _controller.duration = _durationFor(_strokeCount);
  }

  @override
  Widget build(BuildContext context) {
    if (_strokes.isEmpty) return const SizedBox.shrink();
    final double height = HandwritingLayout.heightOf(widget.text, widget.fontSize);
    final double width = widget.maxWidth ?? HandwritingLayout.widthOf(widget.text, widget.fontSize);

    return SizedBox(
      width: widget.maxWidth,
      height: height,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) => CustomPaint(
            size: Size(width, height),
            painter: _HandwritingPainter(
              strokes: _strokes,
              progress: widget.animate ? _controller.value : 1,
              color: widget.color ?? Theme.of(context).colorScheme.onSurface,
              showBaseline: widget.showBaseline,
              strokeWidth: widget.strokeWidth,
              lineHeight: HandwritingLayout.lineHeightOf(widget.fontSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single vector stroke already positioned in canvas coordinates.
class PlacedStroke {
  const PlacedStroke(this.path, this.width);

  final Path path;
  final double width;
}

class HandwritingLayout {
  const HandwritingLayout(this.strokes);

  final List<PlacedStroke> strokes;

  static double lineHeightOf(double fontSize) => fontSize * 1.62;

  static double heightOf(String text, double fontSize) {
    final int lines = text.isEmpty ? 1 : '\n'.allMatches(text).length + 1;
    return lines * lineHeightOf(fontSize);
  }

  static double widthOf(String text, double fontSize) {
    double widest = 0;
    for (final String line in text.split('\n')) {
      double width = 0;
      for (final int unit in line.runes) {
        width += advanceFor(String.fromCharCode(unit)) * fontSize;
      }
      if (width > widest) widest = width;
    }
    return math.max(widest, fontSize);
  }

  /// Only wrap after a space or a breakable mark, never mid-number.
  static bool _isBreakable(String char) => char == ' ' || char == ',' || char == ';' || char == '+' || char == '=';

  static HandwritingLayout build(String text, {required double fontSize, double? maxWidth}) {
    final double lineHeight = lineHeightOf(fontSize);
    // Unit box -> canvas mapping. The box is taller than it is wide so digits
    // keep the squat proportions of real handwriting.
    final double unitHeight = fontSize * 0.78;
    final double baselineDrop = fontSize * 0.62;
    final List<PlacedStroke> strokes = <PlacedStroke>[];

    int lineIndex = 0;
    for (final String line in text.split('\n')) {
      double penX = 0;
      final double unitTop = lineIndex * lineHeight + baselineDrop;

      for (final int rune in line.runes) {
        final String char = String.fromCharCode(rune);
        final double advance = advanceFor(char);

        if (char.trim().isNotEmpty) {
          final List<String> outlines = strokesFor(char);
          // Stable per-glyph variation: the same character always gets the same
          // tilt and weight, so text does not shimmer while it animates.
          final int seed = rune * 31 + char.codeUnitAt(0);
          for (int s = 0; s < outlines.length; s++) {
            final double jitter = ((seed * 7 + s * 13) % 100) / 100.0;
            final double tilt = (jitter - 0.5) * 0.05;
            final double lift = (jitter - 0.5) * fontSize * 0.035;
            final Path unit = _parseStroke(outlines[s]);
            if (unit.computeMetrics().isEmpty) continue;

            final Matrix4 matrix = Matrix4.identity()
              ..multiply(Matrix4.translationValues(penX + advance * fontSize * 0.5 + lift, unitTop, 0))
              ..multiply(Matrix4.rotationZ(tilt))
              ..multiply(Matrix4.translationValues(-0.5, -0.5, 0))
              ..multiply(Matrix4.diagonal3Values(advance * fontSize * 0.92, unitHeight * 0.78, 1));

            strokes.add(PlacedStroke(unit.transform(matrix.storage), fontSize * (0.036 + 0.016 * jitter)));
          }
        }
        penX += advance * fontSize;

        if (maxWidth != null && penX > maxWidth && _isBreakable(char)) {
          lineIndex++;
          penX = 0;
        }
      }
      lineIndex++;
    }

    return HandwritingLayout(strokes);
  }

  /// Splits a stroke into alternating command and number tokens.
  ///
  /// The outlines are written compactly as `M0.5,0.2 L0.6,0.8`, with no space
  /// after the command letter, so one is inserted before the number first.
  @visibleForTesting
  static List<String> tokenizeStroke(String source) {
    final String spaced = source.replaceAllMapped(
      RegExp(r'([MLQCZ])(?=[-\d.])'),
      (Match match) => '${match[1]} ',
    );
    return spaced.split(RegExp(r'[\s,]+')).where((String t) => t.isNotEmpty).toList();
  }

  /// Parses one stroke of the tiny path dialect into a unit-space [Path].
  static Path _parseStroke(String source) {
    final Path path = Path();
    final List<String> tokens = tokenizeStroke(source);

    double cx = 0;
    double cy = 0;
    bool started = false;

    for (int i = 0; i < tokens.length; i++) {
      switch (tokens[i]) {
        case 'M':
          cx = double.tryParse(tokens[++i]) ?? 0;
          cy = double.tryParse(tokens[++i]) ?? 0;
          path.moveTo(cx, cy);
          started = true;
          break;
        case 'L':
          final double x = double.tryParse(tokens[++i]) ?? cx;
          final double y = double.tryParse(tokens[++i]) ?? cy;
          if (started) path.lineTo(x, y);
          cx = x;
          cy = y;
          break;
        case 'Q':
          final double qx = double.tryParse(tokens[++i]) ?? cx;
          final double qy = double.tryParse(tokens[++i]) ?? cy;
          final double x = double.tryParse(tokens[++i]) ?? cx;
          final double y = double.tryParse(tokens[++i]) ?? cy;
          if (started) path.quadraticBezierTo(qx, qy, x, y);
          cx = x;
          cy = y;
          break;
        case 'C':
          final double c1x = double.tryParse(tokens[++i]) ?? cx;
          final double c1y = double.tryParse(tokens[++i]) ?? cy;
          final double c2x = double.tryParse(tokens[++i]) ?? cx;
          final double c2y = double.tryParse(tokens[++i]) ?? cy;
          final double x = double.tryParse(tokens[++i]) ?? cx;
          final double y = double.tryParse(tokens[++i]) ?? cy;
          if (started) path.cubicTo(c1x, c1y, c2x, c2y, x, y);
          cx = x;
          cy = y;
          break;
        case 'Z':
          path.close();
          break;
      }
    }
    return path;
  }
}

class _HandwritingPainter extends CustomPainter {
  _HandwritingPainter({
    required this.strokes,
    required this.progress,
    required this.color,
    required this.showBaseline,
    required this.strokeWidth,
    required this.lineHeight,
  });

  final List<PlacedStroke> strokes;
  final double progress;
  final Color color;
  final bool showBaseline;
  final double? strokeWidth;
  final double lineHeight;

  @override
  void paint(Canvas canvas, Size size) {
    if (showBaseline) {
      final Paint rule = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..strokeWidth = 1;
      for (double y = lineHeight * 0.62; y < size.height; y += lineHeight) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
      }
    }

    if (strokes.isEmpty) return;

    final double total = strokes.length.toDouble();
    final double exact = progress.clamp(0.0, 1.0) * total;
    final int complete = exact.floor().clamp(0, strokes.length);
    final double partial = (exact - complete).clamp(0.0, 1.0);

    for (int i = 0; i < complete; i++) {
      _drawStroke(canvas, strokes[i], 1);
    }
    if (complete < strokes.length && partial > 0) {
      _drawStroke(canvas, strokes[complete], partial);
    }
  }

  void _drawStroke(Canvas canvas, PlacedStroke stroke, double amount) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth ?? stroke.width
      ..color = color;

    if (amount >= 1) {
      canvas.drawPath(stroke.path, paint);
      return;
    }

    // Trim the outline to `amount` of its length so the stroke genuinely grows
    // from its start instead of fading in as a whole shape.
    final Path trimmed = Path();
    for (final ui.PathMetric metric in stroke.path.computeMetrics()) {
      trimmed.addPath(metric.extractPath(0, metric.length * amount), Offset.zero);
    }
    canvas.drawPath(trimmed, paint);
  }

  @override
  bool shouldRepaint(_HandwritingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokes != strokes ||
      oldDelegate.color != color ||
      oldDelegate.showBaseline != showBaseline ||
      oldDelegate.strokeWidth != strokeWidth;
}
