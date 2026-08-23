import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class LanguageRevision extends StatelessWidget {
  LanguageRevision({super.key});

  @override
  Widget build(BuildContext context) {
    final slug = GoRouterState.of(context).pathParameters['slug'] ?? 'english';

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Revision'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Spaced Repetition', Icons.memory_rounded),
          SizedBox(height: 12),
          _buildRevisionCard('Vocabulary Review', '24 words due for review', Icons.translate_rounded,
              Color(0xFF2196F3), '12 New · 8 Review · 4 Mastered'),
          _buildRevisionCard('Grammar Rules', '8 rules to revise', Icons.rule_rounded,
              Color(0xFF9C27B0), '3 New · 5 Review'),
          SizedBox(height: 28),
          _buildSectionHeader('Recent Mistakes', Icons.error_outline_rounded),
          SizedBox(height: 12),
          _buildMistakeCard('Their / There / They\'re', 'Confused possessive with location',
              'Their = possessive, There = location, They\'re = they are'),
          _buildMistakeCard('Affect vs Effect', 'Used as noun instead of verb',
              'Affect = verb (to influence), Effect = noun (result)'),
          _buildMistakeCard('Could of → Could have', 'Common contraction error',
              '"Could of" is incorrect; use "could have" or "could\'ve"'),
          SizedBox(height: 28),
          _buildSectionHeader('Quick Quiz', Icons.quiz_rounded),
          SizedBox(height: 12),
          _buildQuizCard('Fill in the Blank', '10 questions · Mixed topics', Icons.edit_note_rounded),
          _buildQuizCard('True or False', '8 questions · Grammar rules', Icons.fact_check_rounded),
          _buildQuizCard('Match the Pairs', '12 pairs · Vocabulary', Icons.compare_arrows_rounded),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12),
        Icon(icon, size: 20, color: AppColors.primary),
        SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
      ],
    );
  }

  static Widget _buildRevisionCard(String title, String subtitle, IconData icon,
      Color color, String detail) {
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
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                SizedBox(height: 4),
                Text(detail,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  static Widget _buildMistakeCard(String title, String subtitle, String explanation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.close_rounded, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                SizedBox(width: 8),
                Expanded(
                  child: Text(explanation,
                      style: TextStyle(fontSize: 11, color: AppColors.success)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildQuizCard(String title, String subtitle, IconData icon) {
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
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Icon(Icons.play_arrow_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}
