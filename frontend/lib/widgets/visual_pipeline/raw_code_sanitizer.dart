/// Sanitizes raw visual code from text before display.
/// Ensures no SVG, Mermaid, LaTeX code blocks, or HTML tags
/// leak into the chat as raw text.
class RawCodeSanitizer {
  static final RegExp _svgBlockExp = RegExp(
    r'<svg[\s\S]*?</svg>',
    dotAll: true,
  );

  static final RegExp _htmlBlockExp = RegExp(
    r'<(?:div|span|table|p|img|canvas|iframe|figure|section|article|header|footer|nav|main|aside|ul|ol|li|pre|code|blockquote|h[1-6]|br|hr|a|strong|em|b|i|u|small|sub|sup|mark|del|ins|abbr|address|cite|dl|dt|dd)[\s\S]*?(?:/>|>[\s\S]*?</(?:div|span|table|p|img|canvas|iframe|figure|section|article|header|footer|nav|main|aside|ul|ol|li|pre|code|blockquote|h[1-6]|a|strong|em|b|i|u|small|sub|sup|mark|del|ins|abbr|address|cite|dl|dt|dd)>)',
    dotAll: true,
  );

  static final RegExp _mermaidFenced = RegExp(
    r'```(?:mermaid|mmd)\s*\n[\s\S]*?```',
    dotAll: true,
  );

  static final RegExp _latexFenced = RegExp(
    r'```(?:latex|tex|math)\s*\n[\s\S]*?```',
    dotAll: true,
  );

  static final RegExp _visualPlaceholder = RegExp(
    r'\[VISUAL_PLACEHOLDER\]',
  );

  static final RegExp _emptyLines = RegExp(r'\n{3,}');

  /// Strip all visual code patterns from text, returning clean display text.
  static String sanitize(String text) {
    var s = text;
    s = s.replaceAll(_svgBlockExp, '');
    s = s.replaceAll(_htmlBlockExp, '');
    s = s.replaceAll(_mermaidFenced, '');
    s = s.replaceAll(_latexFenced, '');
    s = s.replaceAll(_visualPlaceholder, '');
    s = s.replaceAll(_emptyLines, '\n\n');
    return s.trim();
  }

  /// Check if text contains any raw visual code that should be extracted.
  static bool containsRawVisualCode(String text) =>
      _svgBlockExp.hasMatch(text) ||
      _mermaidFenced.hasMatch(text) ||
      _latexFenced.hasMatch(text) ||
      _visualPlaceholder.hasMatch(text) ||
      _hasSignificantHtmlTags(text);

  /// Detect HTML-like content that looks like visual code (not just inline formatting).
  static bool _hasSignificantHtmlTags(String text) {
    const blockTags = {'div', 'svg', 'table', 'canvas', 'figure', 'section', 'article', 'img'};
    final tagExp = RegExp(r'<(\w+)[\s>]');
    for (final match in tagExp.allMatches(text)) {
      final tag = match.group(1)?.toLowerCase() ?? '';
      if (blockTags.contains(tag)) return true;
    }
    return false;
  }
}
