import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class LanguageCulture extends StatelessWidget {
  const LanguageCulture({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Culture & Context'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Cultural Notes'),
          const SizedBox(height: 12),
          _buildCultureCard(
              'Greetings & Etiquette',
              'Learn how people greet each other in formal and informal settings',
              '👋', const Color(0xFF2196F3)),
          _buildCultureCard(
              'Idioms & Expressions',
              'Common sayings that don\'t translate literally',
              '💬', const Color(0xFF9C27B0)),
          _buildCultureCard(
              'Holidays & Festivals',
              'Traditional celebrations and cultural events',
              '🎉', const Color(0xFFFF9800)),
          _buildCultureCard(
              'Food & Dining',
              'Table manners, common dishes, and food-related expressions',
              '🍽️', const Color(0xFF4CAF50)),
          const SizedBox(height: 28),
          _buildSectionHeader('Social Context'),
          const SizedBox(height: 12),
          _buildCultureCard(
              'Formal vs Informal',
              'When to use formal language and when casual is appropriate',
              '👔', const Color(0xFF607D8B)),
          _buildCultureCard(
              'Making Requests',
              'Polite ways to ask for things in different situations',
              '🙏', const Color(0xFF795548)),
          _buildCultureCard(
              'Expressing Opinions',
              'How to share your views respectfully',
              '💭', const Color(0xFF3F51B5)),
          const SizedBox(height: 28),
          _buildSectionHeader('Regional Varieties'),
          const SizedBox(height: 12),
          _buildCultureCard(
              'British vs American',
              'Key differences in vocabulary, spelling, and pronunciation',
              '🇬🇧', const Color(0xFFD32F2F)),
          _buildCultureCard(
              'Common Slang',
              'Informal words used in everyday conversation',
              '😎', const Color(0xFFFF5722)),
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

  static Widget _buildCultureCard(String title, String desc, String emoji, Color color) {
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
            width: 48, height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
