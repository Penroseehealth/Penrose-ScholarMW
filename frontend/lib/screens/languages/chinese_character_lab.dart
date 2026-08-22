import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';

class ChineseCharacterLab extends StatefulWidget {
  const ChineseCharacterLab({super.key});

  @override
  State<ChineseCharacterLab> createState() => _ChineseCharacterLabState();
}

class _ChineseCharacterLabState extends State<ChineseCharacterLab>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  final LanguageService _service = LanguageService();
  List<dynamic> _characters = [];
  bool _loading = true;
  bool _showDetail = false;
  Map<String, dynamic>? _selectedChar;

  static const Color _accent = Color(0xFF2DD4BF);

  String get _slug =>
      GoRouterState.of(context).pathParameters['slug'] ?? 'chinese';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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
      final data = await _service.getVocabulary(_slug, theme: 'characters');
      final radicals =
          await _service.getVocabulary(_slug, theme: 'radicals');
      final combined = [...data, ...radicals];
      if (!mounted) return;
      setState(() {
        _characters = combined;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[CHARACTER LAB] Load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Character Lab'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.abc_rounded,
                      size: 14, color: _accent),
                  const SizedBox(width: 6),
                  Text('${_characters.length}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _accent)),
                ],
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _accent))
            : _showDetail && _selectedChar != null
                ? _buildDetailView()
                : _buildGridView(),
      ),
    );
  }

  Widget _buildGridView() {
    if (_characters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.abc_rounded,
                size: 64, color: AppColors.textMuted.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('No characters found',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 8),
            const Text('Start learning to build your character library',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildStatsBar()),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildCharacterTile(_characters[i]),
              childCount: _characters.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    final radicals =
        _characters.where((c) => c['part_of_speech'] == 'rad').length;
    final characters =
        _characters.where((c) => c['part_of_speech'] != 'rad').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildMiniStat('✍️', '$characters', 'Characters'),
          Container(
              width: 1,
              height: 36,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          _buildMiniStat('🧩', '$radicals', 'Radicals'),
          Container(
              width: 1,
              height: 36,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: 12)),
          _buildMiniStat('📖', '${_characters.length}', 'Total'),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildCharacterTile(dynamic char) {
    final word = (char['word'] ?? '').toString();
    final pronunciation = (char['pronunciation'] ?? '').toString();
    final translation = (char['translation'] ?? '').toString();
    final isRadical = char['part_of_speech'] == 'rad';

    return GestureDetector(
      onTap: () => setState(() {
        _selectedChar = char;
        _showDetail = true;
      }),
      child: Container(
        decoration: BoxDecoration(
          color: isRadical
              ? _accent.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color:
                  isRadical ? _accent.withValues(alpha: 0.25) : AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(word,
                style: TextStyle(
                    fontSize: word.length > 2 ? 24 : 32,
                    fontWeight: FontWeight.w500,
                    color: isRadical ? _accent : AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(pronunciation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isRadical
                        ? _accent.withValues(alpha: 0.8)
                        : AppColors.textMuted)),
            if (translation.isNotEmpty)
              Text(translation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    final char = _selectedChar!;
    final word = (char['word'] ?? '').toString();
    final pronunciation = (char['pronunciation'] ?? '').toString();
    final translation = (char['translation'] ?? '').toString();
    final example = (char['example_sentence'] ?? '').toString();
    final exampleTrans = (char['example_translation'] ?? '').toString();
    final pos = (char['part_of_speech'] ?? '').toString();
    final isRadical = pos == 'rad';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() {
              _showDetail = false;
              _selectedChar = null;
            }),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: isRadical
                    ? _accent.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: isRadical
                        ? _accent.withValues(alpha: 0.3)
                        : AppColors.border,
                    width: 2),
                boxShadow: [
                  BoxShadow(
                    color: (isRadical ? _accent : AppColors.primary)
                        .withValues(alpha: 0.1),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(word,
                    style: TextStyle(
                        fontSize: word.length > 2 ? 56 : 72,
                        fontWeight: FontWeight.w400,
                        color: isRadical ? _accent : AppColors.textPrimary)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(pronunciation,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(isRadical ? 'Radical' : 'Character',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _accent)),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Meaning',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(translation,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (example.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Example',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(example,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary)),
                        if (exampleTrans.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(exampleTrans,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                    'Back to Grid', Icons.grid_view_rounded, _accent, () {
                  setState(() {
                    _showDetail = false;
                    _selectedChar = null;
                  });
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionBtn(
                    'Save to Notebook', Icons.bookmark_add_rounded, AppColors.primary,
                    () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Saved to notebook'),
                        backgroundColor: AppColors.success),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
