import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';

const Color _pathGreen = Color(0xFF22C55E);
const Color _pathGreenDark = Color(0xFF15803D);
const Color _pathGreenGlow = Color(0x2222C55E);

class LanguageDashboard extends StatefulWidget {
  final String? slug;

  const LanguageDashboard({super.key, this.slug});

  @override
  State<LanguageDashboard> createState() => _LanguageDashboardState();
}

class _LanguageDashboardState extends State<LanguageDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final LanguageService _service = LanguageService();
  Map<String, dynamic> _language = {};
  bool _loading = true;
  bool _didLoad = false;

  static const Map<String, Color> _accentBySlug = {
    'chinese': Color(0xFFEF6C4D),
    'french': Color(0xFF60A5FA),
    'spanish': Color(0xFFF4C95D),
    'german': Color(0xFFFBBF24),
    'portuguese': Color(0xFF818CF8),
    'italian': Color(0xFF34D399),
    'japanese': Color(0xFFF472B6),
    'korean': Color(0xFFA78BFA),
    'arabic': Color(0xFF2DD4BF),
    'swahili': Color(0xFF4ADE80),
    'chichewa': Color(0xFF78D65C),
    'hindu': Color(0xFFFB923C),
    'hindi': Color(0xFFFB923C),
    'russian': Color(0xFF94A3B8),
  };

  static const List<Map<String, String>> _defaultLevels = [
    {
      'form': 'Form 1',
      'name': 'Foundation',
      'desc': 'Greetings, numbers & basics',
      'icon': '🌱',
    },
    {
      'form': 'Form 2',
      'name': 'Elementary',
      'desc': 'Everyday conversations',
      'icon': '🌿',
    },
    {
      'form': 'Form 3',
      'name': 'Intermediate',
      'desc': 'Fluency & expression',
      'icon': '🌳',
    },
    {
      'form': 'Form 4',
      'name': 'Advanced',
      'desc': 'Mastery & exam readiness',
      'icon': '🏔️',
    },
  ];

  List<Map<String, String>> get _levels {
    final apiLevels = _language['levels'];
    if (apiLevels is List && apiLevels.isNotEmpty) {
      return apiLevels.map<Map<String, String>>((lv) {
        final name = (lv['name'] ?? '').toString();
        final form = (lv['form_mapping'] ?? '').toString();
        final desc = (lv['description'] ?? '').toString();
        final slug = (lv['slug'] ?? '').toString();
        return {
          'form': form.isNotEmpty ? form : name,
          'name': name,
          'desc': desc.isNotEmpty ? desc : form,
          'icon': '📘',
          'slug': slug,
        };
      }).toList();
    }
    return _defaultLevels;
  }

  static final List<double> _defaultLevelProgress = [0.72, 0.45, 0.20, 0.05, 0.0, 0.0];

  static final List<_LangModule> _modules = [
    _LangModule('🏠', 'Dashboard', '/language/%SLUG%'),
    _LangModule('🗺️', 'Learning Path', '/language/%SLUG%/path'),
    _LangModule('📚', 'Levels', '/language/%SLUG%/levels'),
    _LangModule('🧠', 'Vocabulary', '/language/%SLUG%/vocabulary'),
    _LangModule('📝', 'Grammar', '/language/%SLUG%/grammar'),
    _LangModule('💬', 'Conversation', '/language/%SLUG%/conversation'),
    _LangModule('🎧', 'Listening', '/language/%SLUG%/listening'),
    _LangModule('🗣️', 'Speaking', '/language/%SLUG%/speaking'),
    _LangModule('📖', 'Reading', '/language/%SLUG%/reading'),
    _LangModule('✍️', 'Writing', '/language/%SLUG%/writing'),
    _LangModule('🔤', 'Pronunciation', '/language/%SLUG%/pronunciation'),
    _LangModule('🤖', 'AI Tutor', '/language/%SLUG%/ai-tutor'),
    _LangModule('🧩', 'Practice', '/language/%SLUG%/practice'),
    _LangModule('🎯', 'Assessments', '/language/%SLUG%/assessment'),
    _LangModule('🔁', 'Revision', '/language/%SLUG%/revision'),
    _LangModule('📊', 'Progress', '/language/%SLUG%/progress'),
    _LangModule('📓', 'Notebook', '/language/%SLUG%/notebook'),
    _LangModule('🌍', 'Culture', '/language/%SLUG%/culture'),
    _LangModule('📥', 'Offline', '/language/%SLUG%/offline'),
    _LangModule('⚙️', 'Settings', '/language/%SLUG%/settings'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant LanguageDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug && widget.slug != null) {
      _load();
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  String get _slug {
    if (widget.slug != null && widget.slug!.isNotEmpty) return widget.slug!;
    return GoRouterState.of(context).pathParameters['slug'] ?? 'chichewa';
  }

  Color get _accent {
    final extra = GoRouterState.of(context).extra;
    if (extra is Color) return extra;
    return _accentBySlug[_slug] ?? AppColors.primary;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getLanguage(_slug);
      if (!mounted) return;
      setState(() {
        _language = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[LANGUAGE DASHBOARD] Load error for ${_slug}: $e');
      if (!mounted) return;
      setState(() {
        _language = {};
        _loading = false;
      });
    }
  }

  String get _langName =>
      (_language['name'] as String?) ?? _titleCase(_slug);

  String get _nativeName => (_language['native_name'] as String?) ?? '';

  String get _langIcon => (_language['icon'] as String?) ?? '🗣️';

  List<double> get _levelProgress {
    final raw = _language['level_progress'];
    if (raw is List && raw.length >= _levels.length) {
      return raw.map((v) => (v is num) ? v.toDouble() : 0.0).toList();
    }
    return _defaultLevelProgress;
  }

  double get _overallProgress {
    final p = _levelProgress;
    if (p.isEmpty) return 0;
    return p.fold<double>(0, (a, b) => a + b) / p.length;
  }

  String get _lastLevelName {
    final last = _language['last_level'];
    if (last is Map<String, dynamic>) {
      final form = last['form'] as String?;
      final name = last['name'] as String?;
      if (form != null && name != null) return '$form · $name';
      if (name != null) return name;
    }
    return 'Form 1 · Foundation';
  }

  String get _lastLesson {
    final lesson = _language['last_lesson'] as String?;
    return lesson ?? 'Greetings & Introductions';
  }

  double get _lastLessonProgress {
    final v = _language['last_lesson_progress'];
    return (v is num) ? v.toDouble().clamp(0.0, 1.0) : 0.72;
  }

  static String _titleCase(String slug) {
    if (slug.isEmpty) return slug;
    return slug
        .split(RegExp(r'[-_]'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                color: accent,
                backgroundColor: AppColors.surface,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(accent)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildContinueLearning(),
                          const SizedBox(height: 28),
                          _buildSectionTitle(
                              'Learning Path', '🗺️', accent),
                          const SizedBox(height: 14),
                          _buildLearningPath(accent),
                          const SizedBox(height: 28),
                          _buildSectionTitle(
                              'Modules & Quick Actions', '⚡', accent),
                          const SizedBox(height: 14),
                          _buildModuleGrid(accent),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(Color accent) {
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
              onTap: () => context.pop(),
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
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Text(_langIcon,
                  style: const TextStyle(fontSize: 24, height: 1.1)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_langName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  Text(
                    _nativeName.isEmpty ? 'Language Dashboard' : _nativeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: _overallProgress,
                      strokeWidth: 2.5,
                      color: accent,
                      backgroundColor: AppColors.surfaceHighest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(_overallProgress * 100).toInt()}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String emoji, Color accent) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3)),
        ),
        Text(emoji, style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Widget _buildContinueLearning() {
    return Semantics(
      label: 'Continue learning $_langName',
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/language/$_slug/levels'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_pathGreen, _pathGreenDark],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _pathGreenGlow.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONTINUE LEARNING',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.75),
                            letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(_lastLesson,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(_lastLevelName,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _lastLessonProgress,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.25),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${(_lastLessonProgress * 100).toInt()}%',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLearningPath(Color accent) {
    final progress = _levelProgress;
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _levels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) => _buildLevelCard(
          _levels[i],
          i < progress.length ? progress[i] : 0.0,
          accent,
        ),
      ),
    );
  }

  Widget _buildLevelCard(
      Map<String, String> level, double progress, Color accent) {
    final completed = progress >= 1.0;
    final current = progress > 0 && !completed;
    final statusColor =
        completed ? AppColors.success : (current ? accent : AppColors.textSecondary);
    final levelSlug = level['slug'] ?? '';

    return Semantics(
      button: true,
      label: '${level['form']} ${level['name']}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (levelSlug.isNotEmpty) {
              context.push('/language/$_slug/levels/$levelSlug');
            } else {
              context.push('/language/$_slug/levels');
            }
          },
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: current
                    ? accent.withValues(alpha: 0.45)
                    : AppColors.border,
                width: current ? 1.2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(level['icon']!,
                          style: const TextStyle(fontSize: 19)),
                    ),
                    const Spacer(),
                    if (completed)
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.success)
                    else if (current)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('NOW',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: accent)),
                      )
                    else
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: AppColors.textMuted),
                  ],
                ),
                const Spacer(),
                Text(level['form']!,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: statusColor)),
                const SizedBox(height: 3),
                Text(level['name']!,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(level['desc']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.surfaceHighest,
                          color: statusColor,
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(progress * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleGrid(Color accent) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: _modules.length,
      itemBuilder: (ctx, i) => _buildModuleCard(_modules[i], accent),
    );
  }

  Widget _buildModuleCard(_LangModule mod, Color accent) {
    final route = mod.route.replaceAll('%SLUG%', _slug);
    return Semantics(
      button: true,
      label: '${mod.label} module',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.push(route),
          child: Container(
            padding: const EdgeInsets.all(14),
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
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(mod.emoji,
                          style: const TextStyle(fontSize: 17)),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textMuted),
                  ],
                ),
                const Spacer(),
                Text(mod.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LangModule {
  final String emoji;
  final String label;
  final String route;

  const _LangModule(this.emoji, this.label, this.route);
}
