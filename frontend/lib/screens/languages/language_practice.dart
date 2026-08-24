import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

const Color _langTeal = Color(0xFF2DD4BF);
const Color _langTealDark = Color(0xFF14B8A6);
const Color _langTealGlow = Color(0x222DD4BF);

class LanguagePracticeScreen extends StatefulWidget {
  final String slug;

  const LanguagePracticeScreen({super.key, required this.slug});

  @override
  State<LanguagePracticeScreen> createState() => _LanguagePracticeScreenState();
}

class _LanguagePracticeScreenState extends State<LanguagePracticeScreen> {
  static const _practiceTypes = [
    ('Flashcards', Icons.style_rounded, AppColors.lavender, 'Flip through vocabulary with spaced repetition'),
    ('Fill-in-blank', Icons.edit_square, _langTeal, 'Complete sentences with the right word'),
    ('Multiple Choice', Icons.checklist_rounded, AppColors.info, 'Pick the correct translation or usage'),
    ('Matching', Icons.compare_arrows_rounded, AppColors.warning, 'Pair words with their meanings'),
    ('Dictation', Icons.keyboard_voice_rounded, AppColors.error, 'Listen and type what you hear'),
    ('Translation', Icons.translate_rounded, AppColors.success, 'Translate phrases both directions'),
  ];

  static final List<Map<String, dynamic>> _recentSessions = [
    {
      'type': 'Flashcards',
      'topic': 'Food & Dining',
      'score': 0.92,
      'items': 20,
      'when': 'Today · 08:30',
    },
    {
      'type': 'Fill-in-blank',
      'topic': 'Present Tense Verbs',
      'score': 0.78,
      'items': 15,
      'when': 'Yesterday · 19:12',
    },
    {
      'type': 'Dictation',
      'topic': 'Market Conversations',
      'score': 0.65,
      'items': 10,
      'when': '2 days ago · 17:45',
    },
    {
      'type': 'Translation',
      'topic': 'Travel Phrases',
      'score': 0.85,
      'items': 12,
      'when': '3 days ago · 21:03',
    },
    {
      'type': 'Matching',
      'topic': 'Family & Relationships',
      'score': 1.0,
      'items': 16,
      'when': '5 days ago · 07:20',
    },
  ];

  Color _typeColor(String type) {
    for (final t in _practiceTypes) {
      if (t.$1 == type) return t.$3;
    }
    return _langTeal;
  }

  IconData _typeIcon(String type) {
    for (final t in _practiceTypes) {
      if (t.$1 == type) return t.$2;
    }
    return Icons.school_rounded;
  }

  void _startPractice(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.colors.surfaceElevated,
        content: Text(
          'Starting $type session for ${_languageTitle(widget.slug)}…',
          style: TextStyle(color: context.colors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 3 : 2;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: width >= 900 ? 32 : 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBanner(),
                  const SizedBox(height: 24),
                  Text('Practice Types',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: width >= 900 ? 2.4 : 1.55,
                    children: [
                      for (final t in _practiceTypes) _buildPracticeCard(t.$1, t.$2, t.$3, t.$4),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Recent Sessions',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text('View all',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _langTeal)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._recentSessions.map(_buildSessionTile),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
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
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.colors.textSecondary),
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
                child: const Icon(Icons.fitness_center_rounded, color: _langTeal, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_languageTitle(widget.slug)} Practice',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                    Text('Skill drills & exercises', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _langTealGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('6 modes',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _langTeal)),
              ),
            ],
          ),
        ),
      );

  Widget _buildBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            _langTeal.withValues(alpha: 0.12),
            _langTealDark.withValues(alpha: 0.05),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _langTeal.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _langTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.bolt_rounded, color: _langTeal, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Practice Goal',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Complete one session today to keep your streak alive and unlock XP.',
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildPracticeCard(String title, IconData icon, Color color, String description) => GestureDetector(
        onTap: () => _startPractice(title),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Flexible(
                child: Text(description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.colors.textMuted, height: 1.35)),
              ),
            ],
          ),
        ),
      );

  Widget _buildSessionTile(Map<String, dynamic> session) {
    final color = _typeColor(session['type'] as String);
    final score = session['score'] as double? ?? 0.0;
    final scoreColor = score >= 0.85
        ? context.colors.success
        : score >= 0.7
            ? context.colors.warning
            : context.colors.error;

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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon(session['type'] as String), color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${session['type']} · ${session['topic']}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${session['items']} items · ${session['when']}',
                    style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${(score * 100).round()}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scoreColor)),
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
