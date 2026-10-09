import 'dart:math';
import 'package:flutter/material.dart';

class FunctionPlotConfig {
  final String expression;
  final Color color;
  final String label;
  final double lineWidth;

  const FunctionPlotConfig({
    required this.expression,
    required this.color,
    required this.label,
    this.lineWidth = 2.5,
  });
}

class FunctionPlotter extends StatelessWidget {
  final List<FunctionPlotConfig> functions;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final bool showGrid;
  final bool showLegend;

  const FunctionPlotter({
    super.key,
    required this.functions,
    this.xMin = -10,
    this.xMax = 10,
    this.yMin = -10,
    this.yMax = 10,
    this.showGrid = false,
    this.showLegend = true,
  });

  static const double _euler = 2.718281828459045;

  static double _eval(String expr, double x) {
    String e = expr.replaceAll(' ', '');
    e = e.replaceAll('pi', '${pi}');
    e = e.replaceAll('euler', '${_euler}');
    e = e.replaceAll('^', '**');
    e = e.replaceAll('sin', 'sin@');
    e = e.replaceAll('cos', 'cos@');
    e = e.replaceAll('tan', 'tan@');
    e = e.replaceAll('sqrt', 'sqrt@');
    e = e.replaceAll('log', 'log@');
    e = e.replaceAll('abs', 'abs@');
    e = e.replaceAll('ln', 'log@');
    e = e.replaceAllMapped(RegExp(r'(\d)([a-zA-Z@])'), (m) => '${m[1]}*${m[2]}');
    e = e.replaceAllMapped(RegExp(r'\)(\w)'), (m) => ')*${m[1]}');
    e = e.replaceAllMapped(RegExp(r'(\d)\('), (m) => '${m[1]}*(');
    e = e.replaceAll('@', '');
    e = e.replaceAll('**', '^');
    final result = _safeCalc(e, x);
    return result;
  }

  static double _safeCalc(String expr, double x) {
    try {
      String e = expr;
      e = e.replaceAll('x', '($x)');
      e = e.replaceAll('^', '**');
      final val = _compute(e);
      if (val.isNaN || val.isInfinite) return double.nan;
      return val;
    } catch (_) {
      return double.nan;
    }
  }

  static double _compute(String expr) {
    expr = expr.trim();
    if (expr.startsWith('(') && expr.endsWith(')')) {
      int depth = 0;
      bool allWrapped = true;
      for (int i = 0; i < expr.length; i++) {
        if (expr[i] == '(') depth++;
        if (expr[i] == ')') depth--;
        if (depth == 0 && i < expr.length - 1) {
          allWrapped = false;
          break;
        }
      }
      if (allWrapped) return _compute(expr.substring(1, expr.length - 1));
    }
    int depth = 0;
    for (int i = expr.length - 1; i >= 0; i--) {
      if (expr[i] == ')') depth++;
      if (expr[i] == '(') depth--;
      if (depth == 0 && (expr[i] == '+' || expr[i] == '-')) {
        if (i == 0) continue;
        if (expr[i - 1] == '(' || expr[i - 1] == '*' || expr[i - 1] == '/' || expr[i - 1] == '^') continue;
        final left = _compute(expr.substring(0, i));
        final right = _compute(expr.substring(i + 1));
        return expr[i] == '+' ? left + right : left - right;
      }
    }
    depth = 0;
    for (int i = expr.length - 1; i >= 0; i--) {
      if (expr[i] == ')') depth++;
      if (expr[i] == '(') depth--;
      if (depth == 0 && (expr[i] == '*' || expr[i] == '/')) {
        final left = _compute(expr.substring(0, i));
        final right = _compute(expr.substring(i + 1));
        return expr[i] == '*' ? left * right : left / right;
      }
    }
    depth = 0;
    for (int i = expr.length - 1; i >= 0; i--) {
      if (expr[i] == ')') depth++;
      if (expr[i] == '(') depth--;
      if (depth == 0 && expr[i] == '^') {
        final base = _compute(expr.substring(0, i));
        final exp = _compute(expr.substring(i + 1));
        return pow(base, exp).toDouble();
      }
    }
    if (expr.startsWith('-')) return -_compute(expr.substring(1));
    if (expr.startsWith('sin(') && expr.endsWith(')')) return sin(_compute(expr.substring(4, expr.length - 1)));
    if (expr.startsWith('cos(') && expr.endsWith(')')) return cos(_compute(expr.substring(4, expr.length - 1)));
    if (expr.startsWith('tan(') && expr.endsWith(')')) return tan(_compute(expr.substring(4, expr.length - 1)));
    if (expr.startsWith('sqrt(') && expr.endsWith(')')) return sqrt(_compute(expr.substring(5, expr.length - 1)));
    if (expr.startsWith('log(') && expr.endsWith(')')) return log(_compute(expr.substring(4, expr.length - 1)));
    if (expr.startsWith('abs(') && expr.endsWith(')')) return _compute(expr.substring(4, expr.length - 1)).abs();
    return double.parse(expr);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            CustomPaint(
              size: Size(w, h),
              painter: _GridPainter(
                xMin: xMin,
                xMax: xMax,
                yMin: yMin,
                yMax: yMax,
                showGrid: showGrid,
              ),
            ),
            ...functions.asMap().entries.map((entry) {
              final cfg = entry.value;
              return CustomPaint(
                size: Size(w, h),
                painter: _FunctionPainter(
                  expression: cfg.expression,
                  color: cfg.color,
                  lineWidth: cfg.lineWidth,
                  xMin: xMin,
                  xMax: xMax,
                  yMin: yMin,
                  yMax: yMax,
                  eval: _eval,
                ),
              );
            }),
            if (showLegend && functions.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: functions
                        .map((f) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 3,
                                  color: f.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${f.label} = ${f.expression}',
                                  style: TextStyle(
                                    color: f.color,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final double xMin, xMax, yMin, yMax;
  final bool showGrid;

  _GridPainter({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    double toX(double v) => (v - xMin) / (xMax - xMin) * w;
    double toY(double v) => h - (v - yMin) / (yMax - yMin) * h;

    final minorPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;
    final majorPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 0.8;
    final axisPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.2;

    final xRange = xMax - xMin;
    final yRange = yMax - yMin;
    final xStep = _niceStep(xRange);
    final yStep = _niceStep(yRange);
    final xMinorStep = xStep / 5;
    final yMinorStep = yStep / 5;

    if (showGrid) {
      for (double v = (xMin / xMinorStep).ceil() * xMinorStep; v <= xMax; v += xMinorStep) {
        final x = toX(v);
        final isMajor = (v / xStep).abs() % 1 < 0.001 || (v / xStep).abs() % 1 > 0.999;
        canvas.drawLine(Offset(x, 0), Offset(x, h), isMajor ? majorPaint : minorPaint);
      }
      for (double v = (yMin / yMinorStep).ceil() * yMinorStep; v <= yMax; v += yMinorStep) {
        final y = toY(v);
        final isMajor = (v / yStep).abs() % 1 < 0.001 || (v / yStep).abs() % 1 > 0.999;
        canvas.drawLine(Offset(0, y), Offset(w, y), isMajor ? majorPaint : minorPaint);
      }
    }

    if (xMin <= 0 && xMax >= 0) {
      final x0 = toX(0);
      canvas.drawLine(Offset(x0, 0), Offset(x0, h), axisPaint);
    }
    if (yMin <= 0 && yMax >= 0) {
      final y0 = toY(0);
      canvas.drawLine(Offset(0, y0), Offset(w, y0), axisPaint);
    }

    final textStyle = const TextStyle(color: Colors.white60, fontSize: 10);
    for (double v = (xMin / xStep).ceil() * xStep; v <= xMax; v += xStep) {
      if (v.abs() < 0.001) continue;
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(toX(v) - tp.width / 2, toY(0) + 4));
    }
    for (double v = (yMin / yStep).ceil() * yStep; v <= yMax; v += yStep) {
      if (v.abs() < 0.001) continue;
      final tp = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(toX(0) + 4, toY(v) - tp.height / 2));
    }
  }

  static double _niceStep(double range) {
    final raw = range / 10;
    final mag = pow(10, (log(raw) / ln10).floor()).toDouble();
    final norm = raw / mag;
    if (norm < 1.5) return mag;
    if (norm < 3.5) return 2 * mag;
    if (norm < 7.5) return 5 * mag;
    return 10 * mag;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FunctionPainter extends CustomPainter {
  final String expression;
  final Color color;
  final double lineWidth;
  final double xMin, xMax, yMin, yMax;
  final double Function(String, double) eval;

  _FunctionPainter({
    required this.expression,
    required this.color,
    required this.lineWidth,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.eval,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    double toX(double v) => (v - xMin) / (xMax - xMin) * w;
    double toY(double v) => h - (v - yMin) / (yMax - yMin) * h;

    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool moved = false;
    final steps = (w * 1.5).toInt().clamp(200, 1000);
    final dx = (xMax - xMin) / steps;
    double? prevY;

    for (int i = 0; i <= steps; i++) {
      final x = xMin + i * dx;
      final y = eval(expression, x);
      if (y.isNaN || y.isInfinite) {
        moved = false;
        prevY = null;
        continue;
      }
      final screenY = toY(y);
      if (screenY < -5000 || screenY > h + 5000) {
        moved = false;
        prevY = null;
        continue;
      }
      if (prevY != null && (screenY - prevY).abs() > h * 0.8) {
        moved = false;
      }
      if (!moved) {
        path.moveTo(toX(x), screenY);
        moved = true;
      } else {
        path.lineTo(toX(x), screenY);
      }
      prevY = screenY;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
