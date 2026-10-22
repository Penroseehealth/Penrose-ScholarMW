import 'package:flutter/material.dart';

import '../vtc_theme.dart';

/// Small status pill: a bordered, tinted label such as `TTS OFFLINE` or
/// `3 VOICES`. Shared by the training centre and the voice library so the
/// capability read-out looks identical in both workspaces.
class VtcStatusPill extends StatelessWidget {
  const VtcStatusPill({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(
          text,
          style: VtcType.body(
            context,
          ).copyWith(fontSize: 10.5, letterSpacing: 1.1, color: color, fontWeight: FontWeight.w600),
        ),
      );
}

/// Inline error message. The caller supplies the retry affordance, so the strip
/// never pretends a failed request succeeded.
class VtcErrorStrip extends StatelessWidget {
  const VtcErrorStrip({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: VtcPalette.danger.withValues(alpha: 0.10),
          border: Border.all(color: VtcPalette.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 17, color: VtcPalette.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: VtcType.body(context).copyWith(fontSize: 13, color: VtcPalette.danger)),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: VtcPalette.danger),
                child: const Text('Retry'),
              ),
          ],
        ),
      );
}

/// Dismissible informational note, used for capability explanations and for
/// the results of a user's own actions.
class VtcNoticeStrip extends StatelessWidget {
  const VtcNoticeStrip({
    super.key,
    required this.message,
    this.onDismiss,
    this.margin = const EdgeInsets.fromLTRB(24, 10, 24, 0),
  });

  final String message;

  /// Omitted for a standing fact that cannot be acted on, such as which accents
  /// the engine can actually produce. Showing a close button there would imply
  /// the user could make the problem go away.
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: VtcPalette.electric.withValues(alpha: 0.10),
          border: Border.all(color: VtcPalette.electric.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 17, color: VtcPalette.electricBright),
            const SizedBox(width: 10),
            Expanded(
              child:
                  Text(message, style: VtcType.body(context).copyWith(fontSize: 13, color: VtcPalette.electricBright)),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 16),
                color: VtcPalette.ivoryDim,
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      );
}
