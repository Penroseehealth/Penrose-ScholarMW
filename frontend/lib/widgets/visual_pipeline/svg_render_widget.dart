import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgRenderWidget extends StatelessWidget {
  final String svgString;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? colorFilter;

  const SvgRenderWidget({
    super.key,
    required this.svgString,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.colorFilter,
  });

  static bool isValidSvg(String text) {
    final trimmed = text.trim();
    return trimmed.startsWith('<svg') || trimmed.startsWith('<?xml');
  }

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: SvgPicture.string(
          svgString,
          fit: fit,
          colorFilter: colorFilter != null ? ColorFilter.mode(colorFilter!, BlendMode.srcIn) : null,
          placeholderBuilder: (context) => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
            ),
          ),
          errorBuilder: (context, error, stackTrace) => _buildErrorFallback(error.toString()),
        ),
      );

  Widget _buildErrorFallback(String error) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade700.withAlpha(80)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red.shade300),
                const SizedBox(width: 8),
                Text(
                  'SVG render error',
                  style: TextStyle(color: Colors.red.shade300, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              svgString.length > 200 ? '${svgString.substring(0, 200)}...' : svgString,
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}
