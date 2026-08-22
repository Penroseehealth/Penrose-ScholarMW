import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../core/theme/app_colors.dart';

class AttachmentPicker extends StatelessWidget {
  final Function(PlatformFile) onFileSelected;

  const AttachmentPicker({super.key, required this.onFileSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload to ScholarAI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a file to analyze with ScholarAI',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            _buildOption(
              context,
              icon: Icons.picture_as_pdf_rounded,
              label: 'PDF Document',
              subtitle: '.pdf — Summarize, extract, analyze',
              color: AppColors.error,
              type: 'pdf',
            ),
            _buildOption(
              context,
              icon: Icons.image_rounded,
              label: 'Image',
              subtitle: '.png, .jpg, .jpeg, .webp — OCR, equation recognition',
              color: AppColors.teal,
              type: 'image',
            ),
            _buildOption(
              context,
              icon: Icons.article_rounded,
              label: 'Word Document',
              subtitle: '.doc, .docx — Summarize, extract headings',
              color: AppColors.info,
              type: 'doc',
            ),
            _buildOption(
              context,
              icon: Icons.table_chart_rounded,
              label: 'Excel / Spreadsheet',
              subtitle: '.xls, .xlsx, .csv — Analyze data, trends',
              color: AppColors.success,
              type: 'spreadsheet',
            ),
            _buildOption(
              context,
              icon: Icons.audio_file_rounded,
              label: 'Audio / Voice',
              subtitle: '.mp3, .wav, .m4a, .aac, .ogg — Transcribe',
              color: AppColors.warning,
              type: 'audio',
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required String type,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _pickFile(context, type),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 20,
                  color: color.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile(BuildContext context, String type) async {
    List<String> extensions;
    switch (type) {
      case 'pdf':
        extensions = ['pdf'];
        break;
      case 'image':
        extensions = ['png', 'jpg', 'jpeg', 'webp'];
        break;
      case 'doc':
        extensions = ['doc', 'docx'];
        break;
      case 'spreadsheet':
        extensions = ['xls', 'xlsx', 'csv'];
        break;
      case 'audio':
        extensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg'];
        break;
      default:
        extensions = [];
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      if (context.mounted) Navigator.pop(context);
      onFileSelected(result.files.first);
    }
  }
}
