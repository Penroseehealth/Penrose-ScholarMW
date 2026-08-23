import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../core/theme/theme_colors.dart';

class LanguageReading extends StatefulWidget {
  LanguageReading({super.key});
  @override
  State<LanguageReading> createState() => _LanguageReadingState();
}

class _LanguageReadingState extends State<LanguageReading> {
  final LanguageService _service = LanguageService();
  List<dynamic> _vocabulary = [];
  List<dynamic> _grammar = [];
  bool _loading = true;
  bool _didLoad = false;
  int _selectedLevel = 0;

  String get _slug =>
      GoRouterState.of(context).pathParameters['slug'] ?? 'english';

  List<String> get _levels {
    final themes = _vocabulary
        .map((v) => (v['theme'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    return ['All', ...themes.take(8)];
  }

  List<dynamic> get _filtered {
    if (_selectedLevel == 0) return _vocabulary;
    final theme = _levels[_selectedLevel];
    return _vocabulary.where((v) => v['theme']?.toString() == theme).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getVocabulary(_slug),
        _service.getGrammar(_slug),
      ]);
      if (!mounted) return;
      setState(() {
        _vocabulary = results[0];
        _grammar = results[1];
        _loading = false;
      });
    } catch (e) {
      debugPrint('[LANGUAGE READING] Load error for $_slug: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildLevelTabs(),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) => _passageCard(_filtered[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios, color: context.colors.textPrimary, size: 20),
          ),
          Icon(Icons.menu_book, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reading', style: TextStyle(
                  color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
                )),
                Text('${_filtered.length} words to read', style: TextStyle(
                  color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 11,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTabs() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _levels.length,
        itemBuilder: (ctx, i) {
          final selected = _selectedLevel == i;
          final label = _levels[i].replaceAll('_', ' ');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedLevel = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : context.colors.surfaceHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? AppColors.primary : context.colors.divider),
                ),
                child: Text(label, style: TextStyle(
                  color: selected ? Colors.white : context.colors.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w500,
                )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 48,
            color: context.colors.textSecondary.withValues(alpha: 0.4)),
          SizedBox(height: 12),
          Text('No passages at this level', style: TextStyle(
            color: context.colors.textSecondary.withValues(alpha: 0.6), fontSize: 14,
          )),
        ],
      ),
    );
  }

  Widget _passageCard(dynamic item) {
    final word = (item['word'] ?? '').toString();
    final translation = (item['translation'] ?? '').toString();
    final example = (item['example_sentence'] ?? '').toString();
    final pos = (item['part_of_speech'] ?? '').toString();
    final theme = (item['theme'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(word, style: TextStyle(
                  color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold,
                )),
              ),
              if (pos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(pos, style: TextStyle(
                    color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600,
                  )),
                ),
            ],
          ),
          SizedBox(height: 6),
          Text(translation, style: TextStyle(
            color: context.colors.textSecondary.withValues(alpha: 0.8), fontSize: 14,
          )),
          if (example.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(example, style: TextStyle(
                color: context.colors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic, height: 1.5,
              )),
            ),
          ],
          if (theme.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.surfaceHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(theme.replaceAll('_', ' '), style: TextStyle(
                color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 11,
              )),
            ),
          ],
        ],
      ),
    );
  }
}
