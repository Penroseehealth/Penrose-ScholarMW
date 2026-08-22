import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';

const Color _langBlue = Color(0xFF2563EB);
const Color _langRed = Color(0xFFDC2626);
const Color _langGreen = Color(0xFF059669);

class LanguagesHub extends StatefulWidget {
  const LanguagesHub({super.key});

  @override
  State<LanguagesHub> createState() => _LanguagesHubState();
}

class _LanguagesHubState extends State<LanguagesHub>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final LanguageService _languageService = LanguageService();
  List<dynamic> _languages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadLanguages();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLanguages() async {
    try {
      final langs = await _languageService.getLanguages();
      if (!mounted) return;
      setState(() {
        _languages = langs;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[LANGUAGES HUB] Load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Color _colorForSlug(String? slug) {
    switch (slug) {
      case 'english':
        return _langBlue;
      case 'chinese':
        return _langRed;
      case 'arabic':
        return _langGreen;
      default:
        return AppColors.primary;
    }
  }

  List<String> get _heroFlags {
    final flags = _languages
        .map((l) => l is Map<String, dynamic>
            ? (l['icon']?.toString() ?? '')
            : '')
        .where((f) => f.isNotEmpty)
        .toList();
    if (flags.length >= 3) return flags.sublist(0, 3);
    const fallbacks = ['🇬🇧', '🇨🇳', '🇸🇦'];
    return [...flags, ...fallbacks.skip(flags.length)];
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        content: Text(
          '$feature — choose a language above to get started',
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 32 : 16, vertical: 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHero(),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Choose Your Language'),
                        const SizedBox(height: 14),
                        _buildLanguageGrid(isDesktop),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Your Progress'),
                        const SizedBox(height: 14),
                        _buildProgressStats(isDesktop),
                        const SizedBox(height: 28),
                        _buildSectionTitle('Language Features'),
                        const SizedBox(height: 14),
                        _buildFeatureGrid(isDesktop),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.go('/student'),
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
                color: AppColors.primaryGlow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.translate_rounded,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Language Hubs',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  Text('English · Chinese · Arabic',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningMuted,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Text('BETA',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.warning)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    final flags = _heroFlags;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _langBlue.withValues(alpha: 0.16),
            _langRed.withValues(alpha: 0.10),
            _langGreen.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _langBlue.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < flags.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(flags[i],
                      style: const TextStyle(fontSize: 22)),
                ),
              ],
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 14, color: AppColors.primaryLight),
                    SizedBox(width: 6),
                    Text('3 Languages',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryLight)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('AI-Powered Language Learning',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4)),
          const SizedBox(height: 8),
          const Text(
            'Master English, Chinese and Arabic with adaptive lessons, '
            'spaced-repetition vocabulary and an AI tutor that speaks your language.',
            style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3)),
      ],
    );
  }

  Widget _buildLanguageGrid(bool isDesktop) {
    if (_loading) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const CircularProgressIndicator(
            strokeWidth: 2.5, color: AppColors.primary),
      );
    }
    if (_languages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.language_rounded,
                size: 32, color: AppColors.textMuted),
            SizedBox(height: 10),
            Text('No languages available yet',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            SizedBox(height: 4),
            Text('Check back soon — new languages are on the way.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isDesktop ? 1.15 : 1.45,
      ),
      itemCount: _languages.length,
      itemBuilder: (ctx, i) =>
          _buildLanguageCard(_languages[i] as Map<String, dynamic>),
    );
  }

  Widget _buildLanguageCard(Map<String, dynamic> lang) {
    final slug = lang['slug']?.toString() ?? '';
    final color = _colorForSlug(slug);
    final flag = lang['icon']?.toString() ?? '';
    final name = lang['name']?.toString() ?? 'Language';
    final nativeName = lang['native_name']?.toString() ?? '';
    final levelSystem = lang['level_system']?.toString() ?? '';
    final vocabCount = lang['vocabulary_count']?.toString() ?? '0';
    final grammarCount = lang['grammar_count']?.toString() ?? '0';
    final levelCount = lang['level_count']?.toString() ?? '0';

    return Semantics(
      button: true,
      label: 'Open $name language hub',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go('/language/$slug'),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.16),
                  color.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(flag,
                          style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3)),
                          if (nativeName.isNotEmpty)
                            Text(nativeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: color),
                  ],
                ),
                const SizedBox(height: 12),
                if (levelSystem.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(levelSystem,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                        child: _buildLangStat(
                            vocabCount, 'Vocabulary', color)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildLangStat(grammarCount, 'Grammar', color)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildLangStat(levelCount, 'Levels', color)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLangStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildProgressStats(bool isDesktop) {
    return GridView.count(
      crossAxisCount: isDesktop ? 3 : 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 2.2 : 3.4,
      children: [
        _buildStatCard('0', 'Day Streak', Icons.local_fire_department_rounded,
            AppColors.warning, 'Start learning to build your streak'),
        _buildStatCard('0', 'Mastered Words', Icons.check_circle_rounded,
            AppColors.success, 'Across all your languages'),
        _buildStatCard('0h', 'Study Time', Icons.schedule_rounded,
            AppColors.info, 'Time spent practising this week'),
      ],
    );
  }

  Widget _buildStatCard(
      String value, String label, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: -0.4)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final _features = [
    _LangFeature(Icons.smart_toy_rounded, 'AI Tutor',
        'Chat with an AI tutor in your target language'),
    _LangFeature(Icons.graphic_eq_rounded, 'Pronunciation Lab',
        'Train your accent with instant feedback'),
    _LangFeature(Icons.forum_rounded, 'Conversation Practice',
        'Real-life dialogues and roleplay scenarios'),
    _LangFeature(Icons.style_rounded, 'Vocabulary Engine',
        'Spaced-repetition flashcards and word themes'),
    _LangFeature(Icons.edit_note_rounded, 'Writing Workspace',
        'Guided writing tasks with AI corrections'),
    _LangFeature(Icons.fact_check_rounded, 'Placement Test',
        'Find your perfect starting level in minutes'),
  ];

  Widget _buildFeatureGrid(bool isDesktop) {
    return GridView.count(
      crossAxisCount: isDesktop ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 2.0 : 1.55,
      children: [
        for (var i = 0; i < _features.length; i++)
          _buildFeatureCard(_features[i], i),
      ],
    );
  }

  Widget _buildFeatureCard(_LangFeature feature, int index) {
    final accents = [
      AppColors.primary,
      _langRed,
      _langGreen,
      _langBlue,
      AppColors.teal,
      AppColors.warning,
    ];
    final color = accents[index % accents.length];

    return Semantics(
      button: true,
      label: feature.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showComingSoon(feature.title),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(feature.icon, size: 19, color: color),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('SOON',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.textMuted)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(feature.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(feature.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangFeature {
  final IconData icon;
  final String title;
  final String description;
  const _LangFeature(this.icon, this.title, this.description);
}
