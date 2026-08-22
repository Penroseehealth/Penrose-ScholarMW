import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

const Color _langTeal = Color(0xFF2DD4BF);
const Color _langTealDark = Color(0xFF14B8A6);
const Color _langTealGlow = Color(0x222DD4BF);

class LanguageProgressScreen extends StatefulWidget {
  final String slug;

  const LanguageProgressScreen({super.key, required this.slug});

  @override
  State<LanguageProgressScreen> createState() => _LanguageProgressScreenState();
}

class _LanguageProgressScreenState extends State<LanguageProgressScreen> {
  static const _skills = [
    ('Vocabulary', AppColors.lavender, 72),
    ('Grammar', _langTeal, 58),
    ('Listening', AppColors.info, 44),
    ('Speaking', AppColors.error, 38),
    ('Reading', AppColors.success, 66),
    ('Writing', AppColors.warning, 51),
    ('Pronunciation', AppColors.accent, 41),
  ];

  static final List<Map<String, dynamic>> _recommendations = [
    {
      'icon': Icons.headphones_rounded,
      'title': 'Boost your Listening score',
      'body':
          'Listening is your weakest skill (44%). Try two short dictation sessions this week — even 10 minutes daily helps.',
    },
    {
      'icon': Icons.record_voice_over_rounded,
      'title': 'Practice Speaking aloud',
      'body':
          'Your pronunciation accuracy improves fastest with role play. Start a Restaurant scenario conversation today.',
    },
    {
      'icon': Icons.rule_rounded,
      'title': 'Review past-tense grammar',
      'body':
          'You missed past-tense questions twice recently. A quick Grammar drill will lock it in.',
    },
  ];

  static const _weeklyMinutes = [35, 20, 45, 0, 30, 55, 25];
  static const _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  int get _streak => 12;
  double get _overallMastery {
    var total = 0;
    for (final s in _skills) {
      total += s.$3 as int;
    }
    return total / _skills.length / 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverallMastery(),
                  const SizedBox(height: 24),
                  const Text('Skill Breakdown',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  ..._skills.map(_buildSkillBar),
                  const SizedBox(height: 24),
                  const Text('AI Recommendations',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  ..._recommendations.map(_buildRecommendationCard),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _buildStreakCard()),
                      const SizedBox(width: 12),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Study Time This Week',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  _buildStudyTimeChart(),
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border:
            Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
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
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: AppColors.textSecondary),
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
              child: const Icon(Icons.insights_rounded,
                  color: _langTeal, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_languageTitle(widget.slug)} Progress',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const Text('Mastery analytics & insights',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallMastery() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _langTeal.withValues(alpha: 0.10),
          _langTealDark.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _langTeal.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _overallMastery,
                  strokeWidth: 11,
                  backgroundColor: AppColors.surfaceHighest,
                  strokeCap: StrokeCap.round,
                  valueColor: const AlwaysStoppedAnimation<Color>(_langTeal),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${(_overallMastery * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary)),
                      const Text('overall mastery',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniStat('Lessons', '86', AppColors.lavender),
              _buildMiniStat('Words', '1,240', AppColors.info),
              _buildMiniStat('Accuracy', '78%', AppColors.success),
              _buildMiniStat('Level', 'A2', AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _buildSkillBar((String, Color, int) skill) {
    final title = skill.$1;
    final color = skill.$2;
    final value = skill.$3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              Text('$value%',
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
              value: value / 100,
              backgroundColor: AppColors.surfaceHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.primary.withValues(alpha: 0.08),
          AppColors.accent.withValues(alpha: 0.04),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(rec['icon'] as IconData,
                color: AppColors.primaryLight, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec['title'] as String,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(rec['body'] as String,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.error.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: AppColors.warning, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: '$_streak',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warning),
                    children: const [
                      TextSpan(
                        text: ' day streak',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Practice today to keep it burning!',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyTimeChart() {
    final maxMinutes =
        _weeklyMinutes.reduce((a, b) => a > b ? a : b).toDouble();
    final total = _weeklyMinutes.fold<int>(0, (a, b) => a + b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Minutes per day',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _langTealGlow,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text('$total min total',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _langTeal)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart placeholder: simple weekly bar visual
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < _weeklyMinutes.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('${_weeklyMinutes[i]}',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _weeklyMinutes[i] == 0
                                      ? AppColors.textMuted
                                      : _langTeal)),
                          const SizedBox(height: 4),
                          Container(
                            height: maxMinutes == 0
                                ? 6
                                : 70 *
                                    (_weeklyMinutes[i] / maxMinutes)
                                        .clamp(0.06, 1.0),
                            decoration: BoxDecoration(
                              color: _weeklyMinutes[i] == 0
                                  ? AppColors.surfaceHighest
                                  : _langTeal.withValues(alpha: 0.75),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_weekDays[i],
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Row(
              children: [
                Icon(Icons.show_chart_rounded,
                    size: 15, color: AppColors.primaryLight),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Detailed time-series chart coming soon — trends, comparisons and goals.',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ),
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
