import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ExportService {
  static Future<void> exportTextToFile(String content, String filename) async {
    final bytes = Uint8List.fromList(content.codeUnits);
    _downloadBytes(bytes, '$filename.txt', 'text/plain');
  }

  static Future<void> exportMarkdownToFile(String content, String filename) async {
    final bytes = Uint8List.fromList(content.codeUnits);
    _downloadBytes(bytes, '$filename.md', 'text/markdown');
  }

  static Future<void> exportHtmlToFile(String htmlContent, String filename) async {
    final bytes = Uint8List.fromList(htmlContent.codeUnits);
    _downloadBytes(bytes, '$filename.html', 'text/html');
  }

  static Future<void> exportSvgToFile(String svgContent, String filename) async {
    final bytes = Uint8List.fromList(svgContent.codeUnits);
    _downloadBytes(bytes, '$filename.svg', 'image/svg+xml');
  }

  static void exportBytesToFile(List<int> bytes, String filename, String mimeType) {
    _downloadBytes(bytes, filename, mimeType);
  }

  static Future<void> exportWidgetToImage(GlobalKey key, String filename) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      _downloadBytes(byteData.buffer.asUint8List(), '$filename.png', 'image/png');
    }
  }

  static void _downloadBytes(List<int> bytes, String filename, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static String buildFormulaSheetHtml(List<Map<String, dynamic>> formulas) {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html><html><head><title>Formula Sheet</title>');
    buffer.writeln('<style>');
    buffer.writeln('body{font-family:sans-serif;max-width:800px;margin:0 auto;padding:20px;color:#333}');
    buffer.writeln('h1{color:#1a237e;border-bottom:2px solid #1a237e;padding-bottom:8px}');
    buffer.writeln('.formula-card{border:1px solid #ddd;border-radius:8px;padding:12px;margin-bottom:12px}');
    buffer.writeln('.formula-title{font-weight:700;color:#1a237e}');
    buffer.writeln('.formula-text{font-size:18px;font-family:monospace;color:#4a148c;margin:8px 0;text-align:center}');
    buffer.writeln('.formula-desc{font-size:12px;color:#666}');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<h1>Penrose ScholarMW — Formula Sheet</h1>');

    for (final f in formulas) {
      buffer.writeln('<div class="formula-card">');
      buffer.writeln('<div class="formula-title">${f['title'] ?? ''}</div>');
      buffer.writeln('<div class="formula-text">${f['formula_text'] ?? f['formula'] ?? ''}</div>');
      buffer.writeln('<div class="formula-desc">${f['description'] ?? ''}</div>');
      buffer.writeln('</div>');
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  static String buildNotesHtml(String title, String content) => '''<!DOCTYPE html>
<html><head><title>$title</title>
<style>
body{font-family:sans-serif;max-width:800px;margin:0 auto;padding:20px;color:#333;line-height:1.6}
h1{color:#1a237e}
.note-content{white-space:pre-wrap;font-size:14px}
</style></head><body>
<h1>$title</h1>
<div class="note-content">$content</div>
<p style="margin-top:40px;font-size:11px;color:#999">Exported from Penrose ScholarMW</p>
</body></html>''';

  static String buildVisualHtml({
    required String title,
    required String type,
    required String spec,
  }) =>
      '''<!DOCTYPE html>
<html><head><title>$title</title>
<style>
body{font-family:sans-serif;max-width:800px;margin:0 auto;padding:20px;color:#333}
h1{color:#1a237e;border-bottom:2px solid #1a237e;padding-bottom:8px}
.meta{font-size:12px;color:#666;margin-bottom:16px}
.spec{background:#f5f5f5;border:1px solid #ddd;border-radius:8px;padding:16px;
  font-family:monospace;white-space:pre-wrap;font-size:13px}
</style></head><body>
<h1>$title</h1>
<div class="meta">Type: $type | Format: HTML | Exported from Penrose ScholarMW</div>
<div class="spec">$spec</div>
</body></html>''';
}
