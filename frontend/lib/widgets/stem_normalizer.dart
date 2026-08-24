class StemNormalizer {
  StemNormalizer._();

  static final _unicodeSuperscript = {
    '⁰': '0',
    '¹': '1',
    '²': '2',
    '³': '3',
    '⁴': '4',
    '⁵': '5',
    '⁶': '6',
    '⁷': '7',
    '⁸': '8',
    '⁹': '9',
    'ⁿ': 'n',
    'ⁱ': 'i',
  };

  static final _unicodeSubscript = {
    '₀': '0',
    '₁': '1',
    '₂': '2',
    '₃': '3',
    '₄': '4',
    '₅': '5',
    '₆': '6',
    '₇': '7',
    '₈': '8',
    '₉': '9',
    'ₐ': 'a',
    'ₑ': 'e',
    'ₒ': 'o',
    'ₓ': 'x',
    'ₙ': 'n',
  };

  static String normalizePlainText(String text) {
    var result = text;

    result = _normalizeUnicodeScript(result);

    result = _normalizeAsciiPatterns(result);

    return result;
  }

  static String _normalizeUnicodeScript(String text) {
    final buffer = StringBuffer();
    int i = 0;
    while (i < text.length) {
      final ch = text[i];

      if (_unicodeSuperscript.containsKey(ch)) {
        final sup = StringBuffer(ch);
        while (i + 1 < text.length && _unicodeSuperscript.containsKey(text[i + 1])) {
          i++;
          sup.write(text[i]);
        }
        final digits = sup.toString().split('').map((c) => _unicodeSuperscript[c] ?? c).join();
        buffer.write('^{$digits}');
        i++;
        continue;
      }

      if (_unicodeSubscript.containsKey(ch)) {
        final sub = StringBuffer(ch);
        while (i + 1 < text.length && _unicodeSubscript.containsKey(text[i + 1])) {
          i++;
          sub.write(text[i]);
        }
        final digits = sub.toString().split('').map((c) => _unicodeSubscript[c] ?? c).join();
        buffer.write('_{$digits}');
        i++;
        continue;
      }

      buffer.write(ch);
      i++;
    }
    return buffer.toString();
  }

  static final _sqrtPattern = RegExp(r'sqrt\(([^)]+)\)', caseSensitive: false);
  static final _fracPattern = RegExp(r'(\w+)/(\w+)');
  static final _superscriptPattern = RegExp(r'(\w)\^(\{[^}]+\}|\w)');

  static String _normalizeAsciiPatterns(String text) {
    var result = text;
    result = result.replaceAllMapped(_sqrtPattern, (m) => '\\sqrt{${m.group(1)}}');
    result = result.replaceAllMapped(_fracPattern, (m) => '\\frac{${m.group(1)}}{${m.group(2)}}');
    result = result.replaceAllMapped(_superscriptPattern, (m) {
      final base = m.group(1)!;
      final exp = m.group(2)!;
      return '$base^{$exp}';
    });
    return result;
  }
}
