import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';

class LanguageVocabulary extends StatefulWidget {
  const LanguageVocabulary({super.key});

  @override
  State<LanguageVocabulary> createState() => _LanguageVocabularyState();
}

class _LanguageVocabularyState extends State<LanguageVocabulary> {
  String? _slug;
  String? _selectedTheme;
  bool _loading = true;
  List<dynamic> _vocabulary = [];
  List<dynamic> _themes = [];
  String _search = '';
  int? _expandedIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final slug = GoRouterState.of(context).pathParameters['slug'];
    if (slug != _slug) {
      _slug = slug;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (_slug == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        LanguageService().getVocabulary(_slug!),
        LanguageService().getVocabularyThemes(_slug!),
      ]);
      if (mounted) {
        setState(() {
          _vocabulary = results[0] as List<dynamic>? ?? [];
          _themes = results[1] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filteredVocab {
    var list = _vocabulary;
    if (_selectedTheme != null) {
      list = list.where((v) => v['theme'] == _selectedTheme).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((v) {
        final word = (v['word'] ?? '').toString().toLowerCase();
        final trans = (v['translation'] ?? '').toString().toLowerCase();
        return word.contains(q) || trans.contains(q);
      }).toList();
    }
    return list;
  }

  Map<String, int> get _masteryStats {
    int mastered = 0, learning = 0, newWords = 0;
    for (final v in _vocabulary) {
      final stage = (v['difficulty'] ?? 'new').toString();
      if (stage == 'mastered') {
        mastered++;
      } else if (stage == 'learning' || stage == 'practicing' || stage == 'familiar') {
        learning++;
      } else {
        newWords++;
      }
    }
    return {'mastered': mastered, 'learning': learning, 'new': newWords};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMasteryBar(),
            _buildThemeChips(),
            _buildSearchBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredVocab.isEmpty
                      ? _buildEmpty()
                      : _buildVocabList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          ),
          const Icon(Icons.book, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Vocabulary', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
            )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${_vocabulary.length} words', style: const TextStyle(
              color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildMasteryBar() {
    final stats = _masteryStats;
    final total = _vocabulary.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface,
      child: Column(
        children: [
          Row(
            children: [
              _statChip('Mastered', stats['mastered']!, AppColors.success),
              const SizedBox(width: 8),
              _statChip('Learning', stats['learning']!, AppColors.warning),
              const SizedBox(width: 8),
              _statChip('New', stats['new']!, AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? stats['mastered']! / total : 0,
              backgroundColor: AppColors.surfaceHighest,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.bold,
            )),
            Text(label, style: TextStyle(
              color: color.withValues(alpha: 0.8), fontSize: 10,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChips() {
    if (_themes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _themeChip(null, 'All'),
          ..._themes.map((t) => _themeChip(
            t['theme']?.toString(), t['theme']?.toString() ?? '',
          )),
        ],
      ),
    );
  }

  Widget _themeChip(String? theme, String label) {
    final selected = _selectedTheme == theme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedTheme = theme),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Text(label, style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12, fontWeight: FontWeight.w500,
          )),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search vocabulary...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6)),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          filled: true,
          fillColor: AppColors.surfaceHighest,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No vocabulary found', style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 14,
          )),
        ],
      ),
    );
  }

  Widget _buildVocabList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredVocab.length,
        itemBuilder: (ctx, i) => _vocabCard(_filteredVocab[i], i),
      ),
    );
  }

  Widget _vocabCard(dynamic vocab, int index) {
    final expanded = _expandedIndex == index;
    final word = vocab['word'] ?? '';
    final translation = vocab['translation'] ?? '';
    final pronunciation = vocab['pronunciation'] ?? '';
    final pos = vocab['part_of_speech'] ?? '';
    final example = vocab['example_sentence'] ?? '';
    final exampleTrans = vocab['example_translation'] ?? '';
    final theme = vocab['theme'] ?? '';

    return GestureDetector(
      onTap: () => setState(() => _expandedIndex = expanded ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: expanded ? AppColors.primary.withValues(alpha: 0.4) : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word, style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
                      )),
                      if (pronunciation.isNotEmpty)
                        Text(pronunciation, style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 13,
                        )),
                    ],
                  ),
                ),
                if (pos.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(pos, style: const TextStyle(
                      color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600,
                    )),
                  ),
                const SizedBox(width: 8),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary, size: 20,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(translation, style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14,
            )),
            if (theme.toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(theme.toString(), style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 10,
                )),
              ),
            ],
            if (expanded && example.toString().isNotEmpty) ...[
              const Divider(color: AppColors.divider, height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Example:', style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 11,
                    )),
                    const SizedBox(height: 4),
                    Text(example.toString(), style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, fontStyle: FontStyle.italic,
                    )),
                    if (exampleTrans.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(exampleTrans.toString(), style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 12,
                      )),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
