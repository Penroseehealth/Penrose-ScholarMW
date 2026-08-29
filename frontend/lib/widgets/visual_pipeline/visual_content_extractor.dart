/// Extracts raw SVG, Mermaid, HTML, and LaTeX code blocks from text
/// and converts them to structured [ExtractedVisual] objects.
class ExtractedVisual {
  final ExtractedVisualType type;
  final String code;
  final int startIndex;
  final int endIndex;

  const ExtractedVisual({
    required this.type,
    required this.code,
    required this.startIndex,
    required this.endIndex,
  });
}

enum ExtractedVisualType { svg, mermaid, html, latexBlock, codeBlock }

class ExtractionResult {
  final String cleanText;
  final List<ExtractedVisual> visuals;

  const ExtractionResult({required this.cleanText, required this.visuals});
}

class VisualContentExtractor {
  static final RegExp _svgBlockExp = RegExp(
    r'(<svg[\s\S]*?</svg>)',
    dotAll: true,
  );

  static final RegExp _htmlBlockExp = RegExp(
    r'(<(?:div|span|table|p|img|canvas|iframe|figure)[\s\S]*?</(?:div|span|table|p|img|canvas|iframe|figure)>)',
    dotAll: true,
  );

  static final RegExp _mermaidFenced = RegExp(
    r'```(?:mermaid|mmd)\s*\n([\s\S]*?)```',
    dotAll: true,
  );

  static final RegExp _latexFencedBlock = RegExp(
    r'```(?:latex|tex|math)\s*\n([\s\S]*?)```',
    dotAll: true,
  );

  static final RegExp _codeFencedBlock = RegExp(
    r'```(\w+)?\s*\n([\s\S]*?)```',
    dotAll: true,
  );

  static ExtractionResult extract(String text) {
    final visuals = <ExtractedVisual>[];
    var remaining = text;

    final svgMatches = _svgBlockExp.allMatches(remaining).toList();
    for (final match in svgMatches) {
      visuals.add(ExtractedVisual(
        type: ExtractedVisualType.svg,
        code: match.group(1)!,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }
    remaining = remaining.replaceAll(_svgBlockExp, '\n[VISUAL_PLACEHOLDER]\n');

    final htmlMatches = _htmlBlockExp.allMatches(remaining).toList();
    for (final match in htmlMatches) {
      visuals.add(ExtractedVisual(
        type: ExtractedVisualType.html,
        code: match.group(1)!,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }
    remaining = remaining.replaceAll(_htmlBlockExp, '\n[VISUAL_PLACEHOLDER]\n');

    final mermaidMatches = _mermaidFenced.allMatches(remaining).toList();
    for (final match in mermaidMatches) {
      visuals.add(ExtractedVisual(
        type: ExtractedVisualType.mermaid,
        code: match.group(1)!,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }
    remaining = remaining.replaceAll(_mermaidFenced, '\n[VISUAL_PLACEHOLDER]\n');

    final latexMatches = _latexFencedBlock.allMatches(remaining).toList();
    for (final match in latexMatches) {
      visuals.add(ExtractedVisual(
        type: ExtractedVisualType.latexBlock,
        code: match.group(1)!,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }
    remaining = remaining.replaceAll(_latexFencedBlock, '\n[VISUAL_PLACEHOLDER]\n');

    final codeMatches = _codeFencedBlock.allMatches(remaining).toList();
    for (final match in codeMatches) {
      final lang = match.group(1) ?? '';
      if (_isVisualLanguage(lang)) {
        visuals.add(ExtractedVisual(
          type: _codeLangToType(lang),
          code: match.group(2)!,
          startIndex: match.start,
          endIndex: match.end,
        ));
      }
    }

    final codeReplaceBuffer = StringBuffer();
    int lastEnd = 0;
    for (final match in _codeFencedBlock.allMatches(remaining)) {
      codeReplaceBuffer.write(remaining.substring(lastEnd, match.start));
      final lang = match.group(1) ?? '';
      if (_isVisualLanguage(lang)) {
        codeReplaceBuffer.write('\n[VISUAL_PLACEHOLDER]\n');
      } else {
        codeReplaceBuffer.write(match.group(0)!);
      }
      lastEnd = match.end;
    }
    codeReplaceBuffer.write(remaining.substring(lastEnd));
    remaining = codeReplaceBuffer.toString();

    final clean = _cleanText(remaining);

    return ExtractionResult(cleanText: clean, visuals: visuals);
  }

  static bool hasAnyVisualCode(String text) =>
      _svgBlockExp.hasMatch(text) ||
      _htmlBlockExp.hasMatch(text) ||
      _mermaidFenced.hasMatch(text) ||
      _latexFencedBlock.hasMatch(text);

  static bool _isVisualLanguage(String lang) {
    const visualLangs = {'svg', 'mermaid', 'mmd', 'latex', 'tex', 'math', 'html', 'diagram', 'chart'};
    return visualLangs.contains(lang.toLowerCase());
  }

  static ExtractedVisualType _codeLangToType(String lang) => switch (lang.toLowerCase()) {
        'svg' => ExtractedVisualType.svg,
        'mermaid' || 'mmd' || 'diagram' => ExtractedVisualType.mermaid,
        'latex' || 'tex' || 'math' => ExtractedVisualType.latexBlock,
        'html' => ExtractedVisualType.html,
        _ => ExtractedVisualType.codeBlock,
      };

  static String _cleanText(String text) {
    var s = text;
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    s = s.replaceAll(RegExp(r'^\s*\[VISUAL_PLACEHOLDER\]\s*$', multiLine: true), '');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }
}
