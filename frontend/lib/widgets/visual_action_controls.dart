import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';
import 'math_viz/ai_visual_parser.dart';
import 'math_viz/visual_export_dialog.dart';

class VisualActionControls extends StatelessWidget {
  final ParsedVisual visual;
  final GlobalKey? visualKey;
  final VoidCallback? onRegenerate;
  final String? chatContext;

  const VisualActionControls({
    super.key,
    required this.visual,
    this.visualKey,
    this.onRegenerate,
    this.chatContext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          _ActionChip(
            icon: Icons.refresh_rounded,
            label: 'Regenerate',
            onTap: onRegenerate,
            colors: colors,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.copy_rounded,
            label: 'Copy',
            onTap: () => _copyVisual(context),
            colors: colors,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.save_rounded,
            label: 'Save',
            onTap: () => _saveVisual(context),
            colors: colors,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: Icons.download_rounded,
            label: 'Export',
            onTap: () => _exportVisual(context),
            colors: colors,
          ),
        ],
      ),
    );
  }

  void _copyVisual(BuildContext context) {
    final spec = visual.rawSpec ?? visual.title ?? '';
    Clipboard.setData(ClipboardData(text: spec));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visual copied to clipboard'), duration: Duration(seconds: 2)),
    );
  }

  void _saveVisual(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => VisualExportDialog(
        visual: visual,
        visualKey: visualKey,
        action: ExportAction.save,
        chatContext: chatContext,
      ),
    );
  }

  void _exportVisual(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => VisualExportDialog(
        visual: visual,
        visualKey: visualKey,
        action: ExportAction.export,
        chatContext: chatContext,
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final dynamic colors;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryLight),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
