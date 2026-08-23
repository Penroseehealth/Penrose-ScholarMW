import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import 'stem_text.dart';
import '../core/theme/theme_colors.dart';

class CompleteResponseRenderer extends StatelessWidget {
  final String content;
  final List<String>? sources;
  final VoidCallback? onListen;
  final VoidCallback? onCopy;
  final VoidCallback? onRegenerate;
  final Function(bool)? onFeedback;
  final VoidCallback? onSave;

  CompleteResponseRenderer({
    super.key,
    required this.content,
    this.sources,
    this.onListen,
    this.onCopy,
    this.onRegenerate,
    this.onFeedback,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StemText(
          content,
          style: TextStyle(
            fontSize: 14,
            color: context.colors.textPrimary,
            height: 1.6,
          ),
          selectable: true,
        ),
        if (sources != null && sources!.isNotEmpty) ...[
          SizedBox(height: 12),
          _buildSources(),
        ],
        SizedBox(height: 10),
        _buildActions(),
      ],
    );
  }

  Widget _buildSources() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.source_rounded, size: 12, color: AppColors.textMuted),
              SizedBox(width: 4),
              Text(
                'Sources',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          ...sources!.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $s',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (onListen != null)
          _actionChip(Icons.volume_up_rounded, 'Listen', onListen!),
        _actionChip(Icons.copy_rounded, 'Copy', () {
          Clipboard.setData(ClipboardData(text: content));
        }),
        if (onRegenerate != null)
          _actionChip(Icons.refresh_rounded, 'Regenerate', onRegenerate!),
        if (onSave != null)
          _actionChip(Icons.bookmark_add_rounded, 'Save', onSave!),
        if (onFeedback != null) ...[
          _actionChip(
            Icons.thumb_up_outlined,
            '',
            () => onFeedback!(true),
            tooltip: 'Helpful',
          ),
          _actionChip(
            Icons.thumb_down_outlined,
            '',
            () => onFeedback!(false),
            tooltip: 'Not helpful',
          ),
        ],
      ],
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap,
      {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppColors.textSecondary),
              if (label.isNotEmpty) ...[
                SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
