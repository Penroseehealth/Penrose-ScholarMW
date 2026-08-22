import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class StemText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool selectable;
  final bool cleanMarkdown;

  const StemText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.selectable = false,
    this.cleanMarkdown = true,
  });

  String _stripMarkdown(String s) {
    s = s.replaceAllMapped(RegExp(r'^#{1,6}\s+', multiLine: true), (_) => '');
    s = s.replaceAll(RegExp(r'\*{3}(.+?)\*{3}'), r'\1');
    s = s.replaceAll(RegExp(r'\*{2}(.+?)\*{2}'), r'\1');
    s = s.replaceAll(RegExp(r'\*{1}(.+?)\*{1}'), r'\1');
    s = s.replaceAll(RegExp(r'_{3}(.+?)_{3}'), r'\1');
    s = s.replaceAll(RegExp(r'_{2}(.+?)_{2}'), r'\1');
    s = s.replaceAll(RegExp(r'_{1}(.+?)_{1}'), r'\1');
    s = s.replaceAll(RegExp(r'`([^`]+)`'), r'\1');
    s = s.replaceAll(RegExp(r'^-{3,}$', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\*\s+', multiLine: true), '• ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

  @override
  Widget build(BuildContext context) {
    final displayText = cleanMarkdown ? _stripMarkdown(text) : text;
    final segments = _parseSegments(displayText);
    final defaultStyle = style ?? DefaultTextStyle.of(context).style;

    final widgets = <InlineSpan>[];
    for (final seg in segments) {
      if (seg.isMath) {
        widgets.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _MathInline(
            latex: seg.content,
            textStyle: defaultStyle,
          ),
        ));
      } else {
        widgets.add(TextSpan(
          text: seg.content,
          style: defaultStyle,
        ));
      }
    }

    if (selectable) {
      return SelectableText.rich(
        TextSpan(children: widgets, style: defaultStyle),
        textAlign: textAlign,
      );
    }
    return RichText(
      text: TextSpan(children: widgets, style: defaultStyle),
      textAlign: textAlign ?? TextAlign.start,
    );
  }

  static List<_Segment> _parseSegments(String input) {
    final segments = <_Segment>[];
    final buffer = StringBuffer();

    int i = 0;
    while (i < input.length) {
      // Block math: \[ ... \]
      if (i + 1 < input.length && input[i] == '\\' && input[i + 1] == '[') {
        if (buffer.isNotEmpty) {
          segments.add(_Segment(buffer.toString(), false));
          buffer.clear();
        }
        final end = input.indexOf('\\]', i + 2);
        if (end != -1) {
          segments.add(_Segment(input.substring(i + 2, end), true));
          i = end + 2;
          continue;
        }
      }

      // Inline math: \( ... \)
      if (i + 1 < input.length && input[i] == '\\' && input[i + 1] == '(') {
        if (buffer.isNotEmpty) {
          segments.add(_Segment(buffer.toString(), false));
          buffer.clear();
        }
        final end = input.indexOf('\\)', i + 2);
        if (end != -1) {
          segments.add(_Segment(input.substring(i + 2, end), true));
          i = end + 2;
          continue;
        }
      }

      // Block math: $$ ... $$
      if (i + 1 < input.length && input[i] == '\$' && input[i + 1] == '\$') {
        if (buffer.isNotEmpty) {
          segments.add(_Segment(buffer.toString(), false));
          buffer.clear();
        }
        final end = input.indexOf('\$\$', i + 2);
        if (end != -1) {
          segments.add(_Segment(input.substring(i + 2, end), true));
          i = end + 2;
          continue;
        }
      }

      // Inline math: $ ... $ (single dollar, non-greedy)
      if (input[i] == '\$' &&
          (i == 0 || input[i - 1] != '\\') &&
          i + 1 < input.length &&
          input[i + 1] != ' ' &&
          input.substring(i).contains(RegExp(r'\$[^$]'))) {
        if (buffer.isNotEmpty) {
          segments.add(_Segment(buffer.toString(), false));
          buffer.clear();
        }
        final end = input.indexOf('\$', i + 1);
        if (end != -1 && end > i + 1) {
          segments.add(_Segment(input.substring(i + 1, end), true));
          i = end + 1;
          continue;
        }
      }

      buffer.write(input[i]);
      i++;
    }

    if (buffer.isNotEmpty) {
      segments.add(_Segment(buffer.toString(), false));
    }

    if (segments.isEmpty) {
      segments.add(_Segment(input, false));
    }

    return segments;
  }
}

class _Segment {
  final String content;
  final bool isMath;
  _Segment(this.content, this.isMath);
}

class _MathInline extends StatelessWidget {
  final String latex;
  final TextStyle textStyle;

  const _MathInline({required this.latex, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    try {
      return Math.tex(
        latex,
        textStyle: textStyle,
        mathStyle: MathStyle.text,
        onErrorFallback: (error) => Text(
          latex,
          style: textStyle.copyWith(
            color: Colors.red.shade300,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } catch (_) {
      return Text(
        latex,
        style: textStyle.copyWith(
          color: Colors.red.shade300,
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }
}
