import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

class MathBlock extends StatelessWidget {
  final String latex;
  final TextStyle? textStyle;

  const MathBlock({super.key, required this.latex, this.textStyle});

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = textStyle ??
        TextStyle(
          color: context.colors.textPrimary,
          fontSize: 16,
        );

    try {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Center(
          child: Math.tex(
            latex,
            textStyle: effectiveStyle,
            mathStyle: MathStyle.display,
            onErrorFallback: (error) => _buildError(latex, effectiveStyle),
          ),
        ),
      );
    } catch (_) {
      return _buildError(latex, effectiveStyle);
    }
  }

  Widget _buildError(String tex, TextStyle style) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tex,
        style: style.copyWith(
          color: AppColors.error,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }
}
