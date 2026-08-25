import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class CoordinatePlane extends StatelessWidget {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final Widget? child;
  final bool showGrid;
  final TextStyle? labelStyle;

  const CoordinatePlane({
    super.key,
    this.xMin = -10,
    this.xMax = 10,
    this.yMin = -10,
    this.yMax = 10,
    this.child,
    this.showGrid = true,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _CoordinatePlanePainter(
            xMin: xMin,
            xMax: xMax,
            yMin: yMin,
            yMax: yMax,
            showGrid: showGrid,
            labelStyle: labelStyle,
          ),
          child: child,
        );
      },
    );
  }
}

class _CoordinatePlanePainter extends CustomPainter {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final bool showGrid;
  final TextStyle? labelStyle;

  _CoordinatePlanePainter({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.showGrid,
    this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final painter = _GridPainter(
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      showGrid: showGrid,
      labelStyle: labelStyle,
    );
    painter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_CoordinatePlanePainter oldDelegate) {
    return oldDelegate.xMin != xMin ||
        oldDelegate.xMax != xMax ||
        oldDelegate.yMin != yMin ||
        oldDelegate.yMax != yMax ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.labelStyle != labelStyle;
  }
}

class _GridPainter extends CustomPainter {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final bool showGrid;
  final TextStyle? labelStyle;

  _GridPainter({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.showGrid,
    this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final scaleX = width / (xMax - xMin);
    final scaleY = height / (yMax - yMin);

    final axisPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final minorGridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final majorGridPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final tickPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    final defaultStyle = labelStyle ??
        const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.normal,
        );

    double worldToScreenX(double worldX) => (worldX - xMin) * scaleX;
    double worldToScreenY(double worldY) => height - (worldY - yMin) * scaleY;

    final xOrigin = worldToScreenX(0).clamp(0.0, width);
    final yOrigin = worldToScreenY(0).clamp(0.0, height);

    if (showGrid) {
      _drawMinorGrid(canvas, width, height, scaleX, scaleY, minorGridPaint);
      _drawMajorGrid(canvas, width, height, scaleX, scaleY, majorGridPaint);
    }

    // X axis
    canvas.drawLine(
      Offset(0, yOrigin),
      Offset(width, yOrigin),
      axisPaint,
    );

    // Y axis
    canvas.drawLine(
      Offset(xOrigin, 0),
      Offset(xOrigin, height),
      axisPaint,
    );

    _drawXTicks(canvas, width, height, scaleX, xOrigin, yOrigin, tickPaint, textPainter, defaultStyle);
    _drawYTicks(canvas, width, height, scaleY, xOrigin, yOrigin, tickPaint, textPainter, defaultStyle);
  }

  void _drawMinorGrid(
    Canvas canvas,
    double width,
    double height,
    double scaleX,
    double scaleY,
    Paint paint,
  ) {
    final xStep = _majorStep(xMax - xMin) / 5;
    final yStep = _majorStep(yMax - yMin) / 5;

    final xOrigin = ((0 - xMin) * scaleX).clamp(0.0, width);
    final yOrigin = (height - (0 - yMin) * scaleY).clamp(0.0, height);

    for (double x = xOrigin % (xStep * scaleX); x < width; x += xStep * scaleX) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), paint);
    }

    for (double y = yOrigin % (yStep * scaleY); y < height; y += yStep * scaleY) {
      canvas.drawLine(Offset(0, y), Offset(width, y), paint);
    }
  }

  void _drawMajorGrid(
    Canvas canvas,
    double width,
    double height,
    double scaleX,
    double scaleY,
    Paint paint,
  ) {
    final majorXStep = _majorStep(xMax - xMin);
    final majorYStep = _majorStep(yMax - yMin);

    final xOrigin = ((0 - xMin) * scaleX).clamp(0.0, width);
    final yOrigin = (height - (0 - yMin) * scaleY).clamp(0.0, height);

    for (double x = xOrigin % (majorXStep * scaleX); x < width; x += majorXStep * scaleX) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), paint);
    }

    for (double y = yOrigin % (majorYStep * scaleY); y < height; y += majorYStep * scaleY) {
      canvas.drawLine(Offset(0, y), Offset(width, y), paint);
    }
  }

  void _drawXTicks(
    Canvas canvas,
    double width,
    double height,
    double scaleX,
    double xOrigin,
    double yOrigin,
    Paint tickPaint,
    TextPainter textPainter,
    TextStyle style,
  ) {
    final majorStep = _majorStep(xMax - xMin);
    final tickLength = 6.0;

    for (double x = _ceilTo(xMin, majorStep); x <= xMax; x += majorStep) {
      if (x == 0) continue;
      final screenX = ((x - xMin) * scaleX).clamp(0.0, width);

      canvas.drawLine(
        Offset(screenX, yOrigin - tickLength),
        Offset(screenX, yOrigin + tickLength),
        tickPaint,
      );

      final label = _formatLabel(x);
      textPainter
        ..text = TextSpan(text: label, style: style)
        ..layout();

      textPainter.paint(
        canvas,
        Offset(screenX - textPainter.width / 2, yOrigin + tickLength + 4),
      );
    }
  }

  void _drawYTicks(
    Canvas canvas,
    double width,
    double height,
    double scaleY,
    double xOrigin,
    double yOrigin,
    Paint tickPaint,
    TextPainter textPainter,
    TextStyle style,
  ) {
    final majorStep = _majorStep(yMax - yMin);
    final tickLength = 6.0;

    for (double y = _ceilTo(yMin, majorStep); y <= yMax; y += majorStep) {
      if (y == 0) continue;
      final screenY = (height - (y - yMin) * scaleY).clamp(0.0, height);

      canvas.drawLine(
        Offset(xOrigin - tickLength, screenY),
        Offset(xOrigin + tickLength, screenY),
        tickPaint,
      );

      final label = _formatLabel(y);
      textPainter
        ..text = TextSpan(text: label, style: style)
        ..layout();

      textPainter.paint(
        canvas,
        Offset(xOrigin + tickLength + 4, screenY - textPainter.height / 2),
      );
    }
  }

  double _majorStep(double range) {
    if (range <= 0) return 1.0;
    final rawStep = range / 10;
    final magnitude = _pow10(rawStep);
    final normalized = rawStep / magnitude;

    if (normalized <= 1.5) return 1.0 * magnitude;
    if (normalized <= 3.5) return 2.0 * magnitude;
    if (normalized <= 7.5) return 5.0 * magnitude;
    return 10.0 * magnitude;
  }

  double _pow10(double value) {
    if (value <= 0) return 1.0;
    final exp = (value.log() / 10.0 * 2.30258509299).round();
    double result = 1.0;
    for (int i = 0; i < exp.abs(); i++) {
      result *= 10.0;
    }
    return exp >= 0 ? result : 1.0 / result;
  }

  double _ceilTo(double value, double step) {
    if (step <= 0) return value;
    return (value / step).ceilToDouble() * step;
  }

  String _formatLabel(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return oldDelegate.xMin != xMin ||
        oldDelegate.xMax != xMax ||
        oldDelegate.yMin != yMin ||
        oldDelegate.yMax != yMax ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.labelStyle != labelStyle;
  }
}

extension _LogExtension on double {
  double log() {
    if (this <= 0) return 0.0;
    double result = 0.0;
    double value = this;
    while (value >= 10.0) {
      value /= 10.0;
      result += 1.0;
    }
    while (value < 1.0) {
      value *= 10.0;
      result -= 1.0;
    }
    return result;
  }
}
