import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Typesets a single line of mathematics.
///
/// Uses flutter_math_fork so work is always rendered as real mathematics, never
/// as raw LaTeX. Any expression the renderer cannot parse degrades to readable
/// monospace text rather than an error box.
class MathTex extends StatelessWidget {
  const MathTex(
    this.latex, {
    super.key,
    this.fontSize = 18,
    this.color,
    this.display = true,
  });

  final String latex;
  final double fontSize;
  final Color? color;
  final bool display;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: fontSize,
      color: color ?? scheme.onSurface,
      height: 1.3,
    );
    final fallback = SelectableText(
      _plain(latex),
      style: style.copyWith(fontFamily: 'monospace'),
    );

    try {
      return Math.tex(
        latex,
        textStyle: style,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        onErrorFallback: (_) => fallback,
      );
    } catch (_) {
      return fallback;
    }
  }

  /// Best-effort readable form when the renderer cannot parse the input.
  static String _plain(String latex) => plainText(latex);

  /// LaTeX reduced to characters that can be written or typeset directly.
  ///
  /// Shared with the handwriting engine, which has no LaTeX support and needs
  /// the same readable form this fallback uses.
  static String plainText(String latex) => latex
      .replaceAll('\\times', '\u00d7')
      .replaceAll('\\div', '\u00f7')
      .replaceAll('\\cdot', '\u00b7')
      .replaceAll('\\pm', '\u00b1')
      .replaceAll('\\frac', ' / ')
      .replaceAll('\\sqrt', '\u221a')
      .replaceAll('\\leq', '\u2264')
      .replaceAll('\\geq', '\u2265')
      .replaceAll('\\pi', '\u03c0')
      .replaceAll('\\theta', '\u03b8')
      .replaceAll('\\infty', '\u221e')
      .replaceAll('\\%', '%')
      .replaceAll('\\quad', '  ')
      .replaceAll('\\left', '')
      .replaceAll('\\right', '')
      .replaceAll('\\text', '')
      .replaceAll('\\mathrm', '')
      .replaceAll('{', '')
      .replaceAll('}', '')
      .replaceAll('\\', '');
}
