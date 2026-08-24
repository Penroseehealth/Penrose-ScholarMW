class MarkdownCleaner {
  MarkdownCleaner._();

  static String clean(String text) {
    var s = text;
    s = _stripHeaders(s);
    s = _stripBoldItalic(s);
    s = _stripInlineCode(s);
    s = _stripHorizontalRules(s);
    s = _cleanBlankLines(s);
    return s.trim();
  }

  static String _stripHeaders(String s) => s.replaceAllMapped(
        RegExp(r'^#{1,6}\s+', multiLine: true),
        (m) => '',
      );

  static String _stripBoldItalic(String s) {
    s = s.replaceAll(RegExp(r'\*{3}(.+?)\*{3}'), r'\1');
    s = s.replaceAll(RegExp(r'\*{2}(.+?)\*{2}'), r'\1');
    s = s.replaceAll(RegExp(r'\*{1}(.+?)\*{1}'), r'\1');
    s = s.replaceAll(RegExp(r'_{3}(.+?)_{3}'), r'\1');
    s = s.replaceAll(RegExp(r'_{2}(.+?)_{2}'), r'\1');
    s = s.replaceAll(RegExp(r'_{1}(.+?)_{1}'), r'\1');
    return s;
  }

  static String _stripInlineCode(String s) => s.replaceAll(RegExp(r'`([^`]+)`'), r'\1');

  static String _stripHorizontalRules(String s) => s.replaceAll(RegExp(r'^-{3,}$', multiLine: true), '');

  static String _cleanBlankLines(String s) => s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
}
