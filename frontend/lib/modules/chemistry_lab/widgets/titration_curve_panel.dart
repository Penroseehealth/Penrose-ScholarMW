import 'package:flutter/material.dart';

import '../../../core/theme/theme_colors.dart';
import '../chemistry/stoichiometry.dart';
import '../experiments/titration_acid_base.dart';
import '../simulation/titration_controller.dart';

/// Calculated titration curve: pH against titrant volume delivered.
///
/// Every point is computed live from [titrationPh] (strong acid/strong base
/// mole balances) — the same function the live readout and the endpoint
/// detection use, so the curve can never disagree with the numbers on
/// screen. Marks the theoretical equivalence volume and the current position
/// of the run. Pure Flutter, no charting dependency.
class TitrationCurvePanel extends StatelessWidget {
  final TitrationController controller;

  const TitrationCurvePanel({super.key, required this.controller});

  static const double _maxVolumeMl = 40.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<void>(
      stream: controller.changes,
      builder: (context, _) {
        final analyteMoles = AcidBaseTitration.analyteConcentration * mLtoDm3(AcidBaseTitration.analyteVolumeMl);
        const titrantC = AcidBaseTitration.titrantConcentration;
        const totalMl = AcidBaseTitration.analyteVolumeMl + _maxVolumeMl;

        double phAt(double deliveredMl) {
          final titrantMoles = titrantC * mLtoDm3(deliveredMl);
          return titrationPh(
            analyteMoles: analyteMoles,
            titrantMolesAdded: titrantMoles,
            totalVolumeDm3: mLtoDm3(totalMl),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Titration curve (calculated)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'pH against volume of NaOH added — the jump marks the equivalence point',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _TitrationCurvePainter(
                  phAt: phAt,
                  equivalenceMl: AcidBaseTitration.expectedTitreMl,
                  currentMl: controller.deliveredMl,
                  maxVolumeMl: _maxVolumeMl,
                  lineColor: colors.primary,
                  gridColor: colors.textSecondary.withValues(alpha: 0.25),
                  labelColor: colors.textSecondary,
                  markerColor: colors.error,
                  currentColor: colors.success,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TitrationCurvePainter extends CustomPainter {
  _TitrationCurvePainter({
    required this.phAt,
    required this.equivalenceMl,
    required this.currentMl,
    required this.maxVolumeMl,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.markerColor,
    required this.currentColor,
  });

  final double Function(double ml) phAt;
  final double equivalenceMl;
  final double currentMl;
  final double maxVolumeMl;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color markerColor;
  final Color currentColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0; // pH axis gutter
    const bottom = 22.0; // volume axis gutter
    final plotW = size.width - left - 8;
    final plotH = size.height - bottom - 8;
    if (plotW <= 0 || plotH <= 0) return;

    Offset x(double ml) =>
        Offset(left + (ml / maxVolumeMl) * plotW, size.height - bottom - 8 - (phAt(ml) / 14.0) * plotH);

    // Grid + axis labels.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final label = TextStyle(color: labelColor, fontSize: 9);
    for (int ph = 0; ph <= 14; ph += 2) {
      final y = size.height - bottom - 8 - (ph / 14.0) * plotH;
      canvas.drawLine(Offset(left, y), Offset(left + plotW, y), grid);
      if (ph % 7 == 0) {
        _label(canvas, '$ph', Offset(left - 24, y - 5), label);
      }
    }
    for (int ml = 0; ml <= maxVolumeMl.toInt(); ml += 10) {
      final px = x(ml.toDouble()).dx;
      canvas.drawLine(Offset(px, 8), Offset(px, size.height - bottom - 8), grid);
      _label(canvas, '$ml', Offset(px - 6, size.height - bottom + 2), label);
    }
    _label(canvas, 'mL', Offset(left + plotW - 14, size.height - bottom + 2), label);

    // Curve — dense near the equivalence jump so the vertical is captured.
    final path = Path()..moveTo(x(0).dx, x(0).dy);
    double prev = 0;
    for (double ml = 0; ml <= maxVolumeMl; ml += 0.1) {
      // Adaptive step: fine near equivalence, coarse elsewhere.
      final nearJump = (ml - equivalenceMl).abs() < 1.5;
      if (!nearJump && ml - prev < 0.4) continue;
      prev = ml;
      path.lineTo(x(ml).dx, x(ml).dy);
    }
    path.lineTo(x(maxVolumeMl).dx, x(maxVolumeMl).dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Equivalence marker.
    final eqX = x(equivalenceMl).dx;
    final eqPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(eqX, 8), Offset(eqX, size.height - bottom - 8), eqPaint);
    _label(
      canvas,
      'eq ${equivalenceMl.toStringAsFixed(1)}',
      Offset(eqX - 26, 0),
      TextStyle(color: markerColor, fontSize: 9),
    );

    // Current position of the run.
    if (currentMl > 0 && currentMl <= maxVolumeMl) {
      final p = x(currentMl);
      canvas.drawCircle(p, 4, Paint()..color = currentColor);
      _label(
        canvas,
        currentMl.toStringAsFixed(1),
        Offset(p.dx - 12, p.dy + 6),
        TextStyle(color: currentColor, fontSize: 9),
      );
    }
  }

  void _label(Canvas canvas, String text, Offset at, TextStyle style) {
    final textPainter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)
      ..layout()
      ..paint(canvas, at);
    textPainter.dispose();
  }

  @override
  bool shouldRepaint(_TitrationCurvePainter old) => old.currentMl != currentMl || old.equivalenceMl != equivalenceMl;
}
