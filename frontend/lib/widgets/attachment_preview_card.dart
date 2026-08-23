import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

enum AttachmentStatus { uploading, ready, processing, error }

class AttachmentPreviewCard extends StatelessWidget {
  final String filename;
  final String? filePath;
  final int? sizeBytes;
  final AttachmentStatus status;
  final String? error;
  final VoidCallback? onRemove;
  final VoidCallback? onView;

  AttachmentPreviewCard({
    super.key,
    required this.filename,
    this.filePath,
    this.sizeBytes,
    this.status = AttachmentStatus.ready,
    this.error,
    this.onRemove,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: status == AttachmentStatus.error
              ? context.colors.error
              : context.colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(),
          SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  filename,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _getStatusColor(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          if (status == AttachmentStatus.ready && onView != null)
            _actionBtn(Icons.visibility_rounded, onView!),
          if (status != AttachmentStatus.uploading && onRemove != null)
            _actionBtn(Icons.close_rounded, onRemove!),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;
    final ext = p.extension(filename).toLowerCase();
    switch (ext) {
      case '.pdf':
        icon = Icons.picture_as_pdf_rounded;
        color = AppColors.error;
        break;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.webp':
        icon = Icons.image_rounded;
        color = AppColors.teal;
        break;
      case '.doc':
      case '.docx':
        icon = Icons.article_rounded;
        color = AppColors.info;
        break;
      case '.xls':
      case '.xlsx':
      case '.csv':
        icon = Icons.table_chart_rounded;
        color = AppColors.success;
        break;
      case '.mp3':
      case '.wav':
      case '.m4a':
      case '.aac':
      case '.ogg':
        icon = Icons.audio_file_rounded;
        color = AppColors.warning;
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        color = AppColors.textSecondary;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  String _getStatusText() {
    switch (status) {
      case AttachmentStatus.uploading:
        return 'Uploading...';
      case AttachmentStatus.ready:
        if (sizeBytes != null) {
          return 'Ready ${_formatSize(sizeBytes!)}';
        }
        return 'Ready for analysis';
      case AttachmentStatus.processing:
        return 'Processing...';
      case AttachmentStatus.error:
        return error ?? 'Error';
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case AttachmentStatus.uploading:
        return AppColors.warning;
      case AttachmentStatus.ready:
        return AppColors.success;
      case AttachmentStatus.processing:
        return AppColors.info;
      case AttachmentStatus.error:
        return AppColors.error;
    }
  }

  Widget _actionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.surfaceHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: AppColors.textSecondary),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '($bytes B)';
    if (bytes < 1024 * 1024) return '(${(bytes / 1024).toStringAsFixed(1)} KB)';
    return '(${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB)';
  }
}
