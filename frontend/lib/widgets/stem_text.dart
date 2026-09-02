import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Unicode subscript/superscript mappings for chemistry rendering.
const _kSubscripts = {
  '0': '₀',
  '1': '₁',
  '2': '₂',
  '3': '₃',
  '4': '₄',
  '5': '₅',
  '6': '₆',
  '7': '₇',
  '8': '₈',
  '9': '₉',
  '+': '₊',
  '-': '₋',
  '=': '₌',
  '(': '₍',
  ')': '₎',
  'a': 'ₐ',
  'e': 'ₑ',
  'o': 'ₒ',
  'x': 'ₓ',
  'n': 'ₙ',
};

const _kSuperscripts = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  '+': '⁺',
  '-': '⁻',
  '=': '⁼',
  '(': '⁽',
  ')': '⁾',
  'n': 'ⁿ',
  'i': 'ⁱ',
};

class StemText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final bool selectable;
  final bool cleanMarkdown;
  final bool enableChemistry;

  const StemText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.selectable = false,
    this.cleanMarkdown = true,
    this.enableChemistry = true,
  });

  String _stripMarkdownPreservingMath(String s) {
    final parts = _splitIntoSegments(s);
    final buf = StringBuffer();
    for (final part in parts) {
      if (part.isMath) {
        buf.write('\\(${part.content}\\)');
      } else {
        buf.write(_stripMarkdown(part.content));
      }
    }
    return buf.toString();
  }

  String _stripMarkdown(String s) {
    s = s.replaceAllMapped(RegExp(r'^#{1,6}\s+', multiLine: true), (_) => '');
    s = s.replaceAll(RegExp(r'\*{3}(.+?)\*{3}'), r'\1');
    s = s.replaceAll(RegExp(r'\*{2}(.+?)\*{2}'), r'\1');
    s = s.replaceAll(RegExp(r'\*{1}(.+?)\*{1}'), r'\1');
    s = s.replaceAll(RegExp(r'`([^`]+)`'), r'\1');
    s = s.replaceAll(RegExp(r'^-{3,}$', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^\*\s+', multiLine: true), '• ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    s = _normalizeLists(s);
    return s.trim();
  }

  /// Clean stray/duplicated numeric list markers (e.g. ':0:', '\\.1:',
  /// '1. 1:') so ordered content renders as plain numbered lists.
  static String _normalizeLists(String s) {
    final lines = s.split('\n');
    final out = <String>[];
    for (var line in lines) {
      // Drop standalone cloze-style markers like ':0:', ':1:' at start of line.
      line = line.replaceFirst(RegExp(r'^[\\]*:\d+\:\s*'), '');
      // Drop escaped numeric markers like '\.1:' at line start.
      line = line.replaceFirst(RegExp(r'^\\\.\d+\:\s*'), '');
      // Collapse a duplicated leading number, e.g. '1. 1: Item' -> '1. Item'.
      line = line.replaceFirstMapped(
        RegExp(r'^(\d+)\.[\s]*\1[\s]*[:\.]?\s*'),
        (m) => '${m.group(1)}. ',
      );
      out.add(line);
    }
    return out.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    String displayText = text;
    if (cleanMarkdown) {
      displayText = _stripMarkdownPreservingMath(displayText);
    }

    final allSegments = _splitIntoSegments(displayText);
    final processedSegments = <_Segment>[];

    for (final seg in allSegments) {
      if (seg.isMath) {
        processedSegments.add(seg);
      } else {
        final plain = _convertBareLatex(seg.content);
        final withChem = enableChemistry ? _convertChemicalFormulas(plain) : plain;
        processedSegments.add(_Segment(withChem, false));
      }
    }

    final defaultStyle = style ?? DefaultTextStyle.of(context).style;
    final widgets = <InlineSpan>[];

    for (final seg in processedSegments) {
      if (seg.isMath) {
        widgets.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _MathInline(latex: seg.content, textStyle: defaultStyle),
          ),
        );
      } else {
        widgets.add(TextSpan(text: seg.content, style: defaultStyle));
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

  // ── Segment splitting ──────────────────────────────────────────────

  static List<_Segment> _splitIntoSegments(String input) {
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
      if (i + 1 < input.length && input[i] == r'$' && input[i + 1] == r'$') {
        if (buffer.isNotEmpty) {
          segments.add(_Segment(buffer.toString(), false));
          buffer.clear();
        }
        final end = input.indexOf(r'$$', i + 2);
        if (end != -1) {
          segments.add(_Segment(input.substring(i + 2, end), true));
          i = end + 2;
          continue;
        }
      }

      // Inline math: $ ... $ (single dollar, non-greedy)
      if (input[i] == r'$' &&
          (i == 0 || input[i - 1] != r'\') &&
          i + 1 < input.length &&
          input[i + 1] != ' ' &&
          input.substring(i).contains(RegExp(r'\$[^$]'))) {
        if (buffer.isNotEmpty) {
          segments.add(_Segment(buffer.toString(), false));
          buffer.clear();
        }
        final end = input.indexOf(r'$', i + 1);
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

  // ── Bare LaTeX command → Unicode ────────────────────────────────────

  static final _latexCommands = RegExp(
      r'\\(?:rightarrow|to|longrightarrow|leftrightarrow|Rightarrow|Leftarrow|leftrightarrow|iff|longrightarrow|leftarrow|cdot|times|div|pm|mp|leq|geq|neq|approx|equiv|propto|infty|partial|nabla|forall|exists|nexists|therefore|because|implies|text\{([^}]*)\}|mathrm\{([^}]*)\}|mathrm\{([^}]*)\}|operatorname\{([^}]*)\})');

  static String _convertBareLatex(String s) {
    final buf = StringBuffer();
    int pos = 0;

    for (final match in _latexCommands.allMatches(s)) {
      if (match.start > pos) {
        buf.write(s.substring(pos, match.start));
      }
      final full = match.group(0)!;
      if (full.startsWith(r'\text{') || full.startsWith(r'\mathrm{') || full.startsWith(r'\operatorname{')) {
        buf.write(match.group(1) ?? match.group(2) ?? match.group(3) ?? '');
      } else {
        switch (full) {
          case r'\rightarrow' || r'\to':
            buf.write(' → ');
          case r'\longrightarrow':
            buf.write(' ⟶ ');
          case r'\leftarrow':
            buf.write(' ← ');
          case r'\leftrightarrow':
            buf.write(' ↔ ');
          case r'\Rightarrow':
            buf.write(' ⇒ ');
          case r'\Leftarrow':
            buf.write(' ⇐ ');
          case r'\iff':
            buf.write(' ⟺ ');
          case r'\cdot':
            buf.write('·');
          case r'\times':
            buf.write('×');
          case r'\div':
            buf.write('÷');
          case r'\pm':
            buf.write('±');
          case r'\mp':
            buf.write('∓');
          case r'\leq':
            buf.write('≤');
          case r'\geq':
            buf.write('≥');
          case r'\neq':
            buf.write('≠');
          case r'\approx':
            buf.write('≈');
          case r'\equiv':
            buf.write('≡');
          case r'\propto':
            buf.write('∝');
          case r'\infty':
            buf.write('∞');
          case r'\partial':
            buf.write('∂');
          case r'\nabla':
            buf.write('∇');
          case r'\forall':
            buf.write('∀');
          case r'\exists':
            buf.write('∃');
          case r'\nexists':
            buf.write('∄');
          case r'\therefore':
            buf.write('∴');
          case r'\because':
            buf.write('∵');
          case r'\implies':
            buf.write(' ⟹ ');
          default:
            buf.write(full);
        }
      }
      pos = match.end;
    }
    if (pos < s.length) {
      buf.write(s.substring(pos));
    }
    return buf.toString();
  }

  // ── Bare chemical subscripts → Unicode ──────────────────────────────

  static final _bareChemSubscript = RegExp(r'([A-Za-z\)])(_(?:\{([^}]+)\}|([0-9]+)))');
  static final _bareChemSuperscript = RegExp(r'([A-Za-z\)])(\^\{?([0-9+\-]+)\}?)');

  static String _convertChemicalFormulas(String s) {
    s = s.replaceAllMapped(_bareChemSubscript, (m) {
      final prefix = m.group(1)!;
      final digits = m.group(3) ?? m.group(4)!;
      final sub = digits.split('').map((c) => _kSubscripts[c] ?? c).join();
      return '$prefix$sub';
    });

    s = s.replaceAllMapped(_bareChemSuperscript, (m) {
      final prefix = m.group(1)!;
      final digits = m.group(3)!;
      final sup = digits.split('').map((c) => _kSuperscripts[c] ?? c).join();
      return '$prefix$sup';
    });

    return s;
  }

  // ── Public static helpers for external use ──────────────────────────

  /// Convert a full string (e.g., AI response) through the same pipeline.
  static String preprocessResponse(String raw) {
    var s = raw;
    // Wrap bare LaTeX in delimiters if possible
    s = _wrapBareLatexInDelimiters(s);
    // Convert remaining bare commands
    s = _convertBareLatex(s);
    // Convert chemical subscripts/superscripts
    s = _convertChemicalFormulas(s);
    return s;
  }

  static final _bareFraction = RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}');
  static final _bareSqrt = RegExp(r'\\sqrt\{([^}]+)\}');
  static final _bareSuperscript = RegExp(r'([a-zA-Z0-9\)])\^\{([^}]+)\}');
  static final _bareSubscript = RegExp(r'([a-zA-Z0-9\)])_\{([^}]+)\}');

  static String _wrapBareLatexInDelimiters(String s) {
    // Don't double-wrap if already inside \(...\) or $$...$$
    if (s.contains(r'\(') || s.contains(r'$$')) return s;

    s = s.replaceAllMapped(_bareFraction, (m) => r'\(\frac{' + m.group(1)! + '}{' + m.group(2)! + r'}\)');
    s = s.replaceAllMapped(_bareSqrt, (m) => r'\(\sqrt{' + m.group(1)! + r'}\)');
    s = s.replaceAllMapped(_bareSuperscript, (m) {
      final base = m.group(1)!;
      final exp = m.group(2)!;
      return r'\(' + base + '^{' + exp + r'}\)';
    });
    s = s.replaceAllMapped(_bareSubscript, (m) {
      final base = m.group(1)!;
      final sub = m.group(2)!;
      return r'\(' + base + '_{' + sub + r'}\)';
    });

    return s;
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
