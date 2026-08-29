import 'package:flutter/material.dart';

import '../math_viz/ai_visual_parser.dart';
import '../math_viz/ai_visual_renderer.dart';
import '../stem_text.dart';
import 'raw_code_sanitizer.dart';
import 'svg_render_widget.dart';
import 'visual_content_extractor.dart';

/// Routes extracted visuals and raw text to the correct renderer widget.
/// This is the main entry point for the visual rendering pipeline.
class VisualResponseRenderer extends StatelessWidget {
  final String responseText;
  final bool isUser;

  const VisualResponseRenderer({
    super.key,
    required this.responseText,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final extraction = VisualContentExtractor.extract(responseText);
    final structuredVisuals = AIVisualParser.parseFromResponse(extraction.cleanText);
    final cleanForStructured = AIVisualParser.removeVisualBlocks(extraction.cleanText);

    final hasAnyVisuals = extraction.visuals.isNotEmpty || structuredVisuals.isNotEmpty;

    if (!hasAnyVisuals) {
      final sanitized = RawCodeSanitizer.sanitize(responseText);
      if (sanitized != responseText) {
        return _buildTextBubble(sanitized);
      }
      return _buildTextBubble(responseText);
    }

    final widgets = <Widget>[];

    final textBefore = RawCodeSanitizer.sanitize(cleanForStructured);
    if (textBefore.isNotEmpty) {
      widgets.add(_buildTextBubble(textBefore));
    }

    for (final extracted in extraction.visuals) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _buildExtractedVisual(extracted),
      ));
    }

    for (final sv in structuredVisuals) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: AIVisualRenderer(visual: sv),
      ));
    }

    if (widgets.isEmpty) {
      return _buildTextBubble(responseText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildExtractedVisual(ExtractedVisual visual) {
    switch (visual.type) {
      case ExtractedVisualType.svg:
        return SvgRenderWidget(svgString: visual.code);
      case ExtractedVisualType.mermaid:
        return _buildMermaidPlaceholder(visual.code);
      case ExtractedVisualType.html:
        return _buildHtmlPlaceholder(visual.code);
      case ExtractedVisualType.latexBlock:
        return _buildLatexBlock(visual.code);
      case ExtractedVisualType.codeBlock:
        return _buildCodeBlock(visual.code);
    }
  }

  Widget _buildMermaidPlaceholder(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyanAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_rounded, size: 18, color: Colors.cyanAccent.withAlpha(200)),
              const SizedBox(width: 8),
              const Text('Diagram',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(60),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              code.trim(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mermaid diagrams render on the web platform',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildHtmlPlaceholder(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orangeAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.html_rounded, size: 18, color: Colors.orangeAccent.withAlpha(200)),
              const SizedBox(width: 8),
              const Text('HTML Visual',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(60),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              code.length > 300 ? '${code.substring(0, 300)}...' : code,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatexBlock(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purpleAccent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.functions_rounded, size: 18, color: Colors.purpleAccent.withAlpha(200)),
              const SizedBox(width: 8),
              const Text('Equation',
                  style: TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          StemText(
            code.trim(),
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
            selectable: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: SelectableText(
        code.trim(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextBubble(String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF3D5AFE) : const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StemText(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        selectable: true,
      ),
    );
  }
}

/// Lightweight wrapper that detects raw visual code in text
/// and either extracts+renders visuals or falls back to text.
class SmartVisualRenderer extends StatelessWidget {
  final String content;
  final bool isUser;

  const SmartVisualRenderer({
    super.key,
    required this.content,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!RawCodeSanitizer.containsRawVisualCode(content) && !AIVisualRenderer.hasVisuals(content)) {
      return StemText(
        content,
        style: TextStyle(color: isUser ? Colors.white : const Color(0xFFE0E0E0), fontSize: 14, height: 1.5),
        selectable: true,
      );
    }

    return VisualResponseRenderer(responseText: content, isUser: isUser);
  }
}
