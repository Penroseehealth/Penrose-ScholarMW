import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../core/theme/theme_colors.dart';

class ChineseHubDashboard extends StatefulWidget {
  final String slug;
  const ChineseHubDashboard({super.key, this.slug = 'chinese'});

  @override
  State<ChineseHubDashboard> createState() => _ChineseHubDashboardState();
}

class _ChineseHubDashboardState extends State<ChineseHubDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  final LanguageService _service = LanguageService();
  Map<String, dynamic> _language = {};
  List<dynamic> _vocabThemes = [];
  bool _loading = true;

  static const Color _chineseRed = Color(0xFFDC2626);
  static const Color _chineseGold = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getLanguage(widget.slug);
      final themes = await _service.getVocabularyThemes(widget.slug);
      if (!mounted) return;
      setState(() {
        _language = data;
        _vocabThemes = themes;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[CHINESE HUB] Load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _nativeName =>
      (_language['native_name'] as String?) ?? '中文 (Zhōngwén)';

  List<Map<String, dynamic>> get _levels {
    final apiLevels = _language['levels'];
    if (apiLevels is List && apiLevels.isNotEmpty) {
      return apiLevels.map<Map<String, dynamic>>((lv) {
        return {
          'id': lv['id'],
          'name': (lv['name'] ?? '').toString(),
          'slug': (lv['slug'] ?? '').toString(),
          'form': (lv['form_mapping'] ?? '').toString(),
          'proficiency': (lv['proficiency_label'] ?? '').toString(),
          'description': (lv['description'] ?? '').toString(),
        };
      }).toList();
    }
    return [];
  }

  int get _totalVocab {
    var count = 0;
    for (final t in _vocabThemes) {
      count += (t['count'] as num?)?.toInt() ?? 0;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _chineseRed))
            : RefreshIndicator(
                color: _chineseRed,
                backgroundColor: context.colors.surface,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildPlacementCard(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Chinese Labs', '🔬'),
                          const SizedBox(height: 14),
                          _buildLabGrid(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Your Learning Path', '🗺️'),
                          const SizedBox(height: 14),
                          _buildLevelsList(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Vocabulary Themes', '📚'),
                          const SizedBox(height: 14),
                          _buildThemesGrid(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Quick Actions', '⚡'),
                          const SizedBox(height: 14),
                          _buildQuickActions(),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
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
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _chineseRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _chineseRed.withValues(alpha: 0.25)),
                  ),
                  child: const Text('🇨🇳', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chinese Hub',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary,
                              letterSpacing: -0.3)),
                      Text(_nativeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: context.colors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatBadge('$_totalVocab', 'Words', Icons.abc_rounded, _chineseRed),
        const SizedBox(width: 10),
        _buildStatBadge(
            '${_levels.length}', 'Levels', Icons.stairs_rounded, _chineseGold),
        const SizedBox(width: 10),
        _buildStatBadge(
            '${_vocabThemes.length}', 'Themes', Icons.category_rounded, context.colors.teal),
        const SizedBox(width: 10),
        _buildStatBadge('6', 'Tones', Icons.graphic_eq_rounded, AppColors.primary),
      ],
    );
  }

  Widget _buildStatBadge(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: context.colors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacementCard() {
    return GestureDetector(
      onTap: () => context.push('/language/${widget.slug}/practice'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _chineseRed.withValues(alpha: 0.3),
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
                  Text('START LEARNING',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.75),
                          letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  const Text('Continue Your Chinese Journey',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(
                      _levels.isNotEmpty
                          ? '${_levels.first['form']} · ${_levels.first['name']}'
                          : 'Form 1 · Foundation',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String emoji) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _chineseRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                  letterSpacing: -0.3)),
        ),
        Text(emoji, style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  Widget _buildLabGrid() {
    final labs = [
      _LabItem('🔤', 'Pinyin Lab', 'Master initials, finals & tones',
          '/language/${widget.slug}/pinyin-lab', _chineseRed),
      _LabItem('🎵', 'Tone Lab', 'Practice the 4 tones + neutral',
          '/language/${widget.slug}/tone-lab', _chineseGold),
      _LabItem('✍️', 'Character Lab', 'Stroke order, radicals & components',
          '/language/${widget.slug}/character-lab', context.colors.teal),
      _LabItem('🧩', 'Sentence Builder', 'Construct sentences with word bank',
          '/language/${widget.slug}/sentence-builder', AppColors.primary),
      _LabItem('📝', 'Placement Test', 'Adaptive HSK level assessment',
          '/language/${widget.slug}/placement-test', const Color(0xFF8B5CF6)),
      _LabItem('🔄', 'SRS Review', 'Spaced repetition flashcards',
          '/language/${widget.slug}/srs-review', const Color(0xFF10B981)),
      _LabItem('Rad', 'Radical Lab', 'Explore radicals & components',
          '/language/${widget.slug}/radical-lab', const Color(0xFFEC4899)),
    ];

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
      itemCount: labs.length,
      itemBuilder: (ctx, i) => _buildLabCard(labs[i]),
    );
  }

  Widget _buildLabCard(_LabItem lab) {
    return GestureDetector(
      onTap: () => context.push(lab.route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
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
                    color: lab.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: lab.color.withValues(alpha: 0.2)),
                  ),
                  child: Text(lab.emoji, style: const TextStyle(fontSize: 17)),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: context.colors.textMuted),
              ],
            ),
            const Spacer(),
            Text(lab.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary)),
            Text(lab.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10, color: context.colors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelsList() {
    if (_levels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('No levels available yet',
              style: TextStyle(color: context.colors.textMuted)),
        ),
      );
    }

    return Column(
      children: _levels.map((level) {
        final idx = _levels.indexOf(level);
        final icons = ['🌱', '🌿', '🌳', '🏔️', '🎓', '🏆'];
        final icon = idx < icons.length ? icons[idx] : '📘';
        return GestureDetector(
          onTap: () =>
              context.push('/language/${widget.slug}/levels/${level['slug']}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _chineseRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(level['form'].toString().toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: _chineseRed)),
                      const SizedBox(height: 2),
                      Text(level['name'],
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(level['description'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: context.colors.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: context.colors.textMuted),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildThemesGrid() {
    if (_vocabThemes.isEmpty) return const SizedBox.shrink();

    final themeIcons = <String, String>{
      'pinyin': '🔤',
      'tones': '🎵',
      'numbers': '🔢',
      'greetings': '👋',
      'self_intro': '🙋',
      'characters': '✍️',
      'radicals': '🧩',
      'family': '👨‍👩‍👧‍👦',
      'food': '🍜',
      'drink': '🍵',
      'body': '🫀',
      'school': '🏫',
      'time': '⏰',
      'colors': '🎨',
      'directions': '🧭',
      'shopping': '🛒',
      'weather': '🌤️',
      'hobbies': '⚽',
      'travel': '✈️',
      'health': '💊',
      'work': '💼',
      'emotions': '😊',
      'transport': '🚌',
      'animals': '🐾',
      'clothes': '👔',
      'nature': '🌸',
    };

    final display = _vocabThemes.length > 8
        ? _vocabThemes.sublist(0, 8)
        : _vocabThemes;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: display.map((theme) {
        final name = (theme['theme'] ?? '').toString();
        final count = theme['count'] ?? 0;
        final icon = themeIcons[name] ?? '📝';
        return GestureDetector(
          onTap: () =>
              context.push('/language/${widget.slug}/vocabulary?theme=$name'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Text(name.replaceAll('_', ' '),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _chineseRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$count',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _chineseRed)),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction('📝', 'Vocabulary', '/language/${widget.slug}/vocabulary'),
      _QuickAction('📐', 'Grammar', '/language/${widget.slug}/grammar'),
      _QuickAction('🎧', 'Listening', '/language/${widget.slug}/listening'),
      _QuickAction('🗣️', 'Speaking', '/language/${widget.slug}/speaking'),
      _QuickAction('📖', 'Reading', '/language/${widget.slug}/reading'),
      _QuickAction('✍️', 'Writing', '/language/${widget.slug}/writing'),
      _QuickAction('🤖', 'AI Tutor', '/language/${widget.slug}/ai-tutor'),
      _QuickAction('📓', 'Notebook', '/language/${widget.slug}/notebook'),
      _QuickAction('🌍', 'Culture', '/language/${widget.slug}/culture'),
      _QuickAction('📊', 'Progress', '/language/${widget.slug}/progress'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((action) {
        return GestureDetector(
          onTap: () => context.push(action.route),
          child: Container(
            width: (MediaQuery.of(context).size.width - 42) / 2,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Text(action.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(action.label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary)),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: context.colors.textMuted),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LabItem {
  final String emoji;
  final String title;
  final String subtitle;
  final String route;
  final Color color;
  const _LabItem(this.emoji, this.title, this.subtitle, this.route, this.color);
}

class _QuickAction {
  final String emoji;
  final String label;
  final String route;
  const _QuickAction(this.emoji, this.label, this.route);
}
