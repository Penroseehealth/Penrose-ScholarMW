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
  final bool isEditing;
  final bool canEdit;
  final VoidCallback? onEditToggle;

  const VisualActionControls({
    super.key,
    required this.visual,
    this.visualKey,
    this.onRegenerate,
    this.chatContext,
    this.isEditing = false,
    this.canEdit = true,
    this.onEditToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (canEdit)
            _ActionChip(
              icon: isEditing ? Icons.check_rounded : Icons.edit_rounded,
              label: isEditing ? 'Done' : 'Edit',
              onTap: onEditToggle,
              colors: colors,
              isActive: isEditing,
            ),
          _ActionChip(
            icon: Icons.refresh_rounded,
            label: 'Regenerate',
            onTap: onRegenerate,
            colors: colors,
          ),
          _ActionChip(
            icon: Icons.copy_rounded,
            label: 'Copy',
            onTap: () => _copyVisual(context),
            colors: colors,
          ),
          _ActionChip(
            icon: Icons.save_rounded,
            label: 'Save',
            onTap: () => _saveVisual(context),
            colors: colors,
          ),
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
  final bool isActive;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
    required this.colors,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withAlpha(30) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? AppColors.primaryLight : AppColors.primaryLight,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.primaryLight : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
