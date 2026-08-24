import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

const Color _langTeal = Color(0xFF2DD4BF);
const Color _langTealDark = Color(0xFF14B8A6);
const Color _langTealGlow = Color(0x222DD4BF);

class LanguageAssessmentScreen extends StatefulWidget {
  final String slug;

  const LanguageAssessmentScreen({super.key, required this.slug});

  @override
  State<LanguageAssessmentScreen> createState() =>
      _LanguageAssessmentScreenState();
}

class _LanguageAssessmentScreenState extends State<LanguageAssessmentScreen> {
  bool _assessing = false;

  static const _modules = [
    ('Vocabulary', Icons.menu_book_rounded, AppColors.lavender, 72),
    ('Grammar', Icons.rule_rounded, _langTeal, 58),
    ('Listening', Icons.headphones_rounded, AppColors.info, 44),
    ('Reading', Icons.auto_stories_rounded, AppColors.success, 66),
    ('Writing', Icons.edit_note_rounded, AppColors.warning, 51),
    ('Speaking', Icons.record_voice_over_rounded, AppColors.error, 38),
  ];

  static final List<Map<String, dynamic>> _resultsHistory = [
    {
      'label': 'Full Placement Test',
      'date': '2 weeks ago',
      'score': 61,
      'level': 'A2 → B1',
      'delta': 8,
    },
    {
      'label': 'Vocabulary Check-in',
      'date': '1 month ago',
      'score': 64,
      'level': 'B1',
      'delta': 5,
    },
    {
      'label': 'Grammar Diagnostic',
      'date': '2 months ago',
      'score': 49,
      'level': 'A2',
      'delta': -2,
    },
    {
      'label': 'Full Placement Test',
      'date': '3 months ago',
      'score': 53,
      'level': 'A2',
      'delta': 11,
    },
  ];

  String get _currentLevel => 'A2';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentLevel(),
                  const SizedBox(height: 24),
                  Text('Assessment Modules',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                      'Each module adapts to your responses and updates your level.',
                      style:
                          TextStyle(fontSize: 12, color: context.colors.textMuted)),
                  const SizedBox(height: 12),
                  ..._modules.map(_buildModuleCard),
                  const SizedBox(height: 20),
                  _buildStartButton(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Results History',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textPrimary)),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text('Export',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _langTeal)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._resultsHistory.map(_buildHistoryTile),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border:
            Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: context.colors.textSecondary),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _langTealGlow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.assignment_turned_in_rounded,
                  color: _langTeal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_languageTitle(widget.slug)} Assessment',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary)),
                  Text('Placement & level checks',
                      style:
                          TextStyle(fontSize: 12, color: context.colors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLevel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _langTeal.withValues(alpha: 0.12),
          _langTealDark.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _langTeal.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _langTeal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _langTeal.withValues(alpha: 0.5), width: 2),
            ),
            child: Center(
              child: Text(_currentLevel,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: _langTeal)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current CEFR Level',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textSecondary)),
                const SizedBox(height: 4),
                Text('Elementary — A2',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.45,
                    backgroundColor: context.colors.surfaceHighest,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_langTeal),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text('45% of the way to B1 · keep going!',
                    style:
                        TextStyle(fontSize: 11, color: context.colors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard((String, IconData, Color, int) module) {
    final title = module.$1;
    final icon = module.$2;
    final color = module.$3;
    final score = module.$4;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary)),
                    Text('$score%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: context.colors.surfaceHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _assessing ? null : () => setState(() => _assessing = true),
        icon: _assessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.play_arrow_rounded, size: 22),
        label: Text(
          _assessing ? 'Preparing assessment…' : 'Start Full Assessment',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _langTeal,
          foregroundColor: const Color(0xFF062B27),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          disabledBackgroundColor: context.colors.surfaceHighest,
          disabledForegroundColor: context.colors.textMuted,
        ),
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> result) {
    final delta = result['delta'] as int;
    final deltaColor =
        delta >= 0 ? context.colors.success : context.colors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _langTealGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('${result['score']}%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _langTeal)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result['label'] as String,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary)),
                const SizedBox(height: 2),
                Text('${result['date']} · Level ${result['level']}',
                    style: TextStyle(
                        fontSize: 11, color: context.colors.textMuted)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(delta >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 13, color: deltaColor),
                const SizedBox(width: 3),
                Text('$delta',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: deltaColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _languageTitle(String slug) {
  if (slug.isEmpty) return 'Language';
  return slug[0].toUpperCase() + slug.substring(1);
}
