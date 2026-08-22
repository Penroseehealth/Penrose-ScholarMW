import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class LanguageOffline extends StatelessWidget {
  const LanguageOffline({super.key});

  @override
  Widget build(BuildContext context) {
    final slug = GoRouterState.of(context).pathParameters['slug'] ?? 'english';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Offline Downloads'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.download_done_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Offline Mode',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Download content for offline access',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Available Downloads'),
          const SizedBox(height: 12),
          _buildDownloadCard('Vocabulary Lists', '81 words', '12 MB', Icons.translate_rounded,
              const Color(0xFF2196F3), false),
          _buildDownloadCard('Grammar Rules', '15 rules', '8 MB', Icons.rule_rounded,
              const Color(0xFF9C27B0), false),
          _buildDownloadCard('Audio Lessons', '24 lessons', '45 MB', Icons.headphones_rounded,
              const Color(0xFF4CAF50), false),
          _buildDownloadCard('Reading Passages', '18 passages', '6 MB', Icons.menu_book_rounded,
              const Color(0xFFFF9800), false),
          const SizedBox(height: 28),
          _buildSectionHeader('Downloaded'),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Icon(Icons.cloud_download_outlined, size: 40, color: AppColors.textMuted),
                const SizedBox(height: 8),
                const Text('No content downloaded yet',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ],
    );
  }

  static Widget _buildDownloadCard(String title, String count, String size,
      IconData icon, Color color, bool downloaded) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('$count · $size',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              downloaded ? Icons.check_circle_rounded : Icons.download_rounded,
              color: downloaded ? AppColors.success : AppColors.primary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
