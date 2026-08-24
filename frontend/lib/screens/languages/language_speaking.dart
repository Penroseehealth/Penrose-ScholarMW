import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../core/theme/theme_colors.dart';

class LanguageSpeaking extends StatefulWidget {
  const LanguageSpeaking({super.key});
  @override
  State<LanguageSpeaking> createState() => _LanguageSpeakingState();
}

class _LanguageSpeakingState extends State<LanguageSpeaking>
    with SingleTickerProviderStateMixin {
  final LanguageService _service = LanguageService();
  List<dynamic> _vocabulary = [];
  List<dynamic> _grammar = [];
  bool _loading = true;
  bool _didLoad = false;
  late TabController _tabController;
  bool _isRecording = false;

  String get _slug =>
      GoRouterState.of(context).pathParameters['slug'] ?? 'english';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      debugPrint('[LANGUAGE SPEAKING] Load error for $_slug: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _phrases =>
      _vocabulary.where((v) {
        final example = (v['example_sentence'] ?? '').toString();
        final pos = (v['part_of_speech'] ?? '').toString();
        return example.isNotEmpty &&
            (pos == 'excl' || pos == 'phrase' || example.contains('?') || example.length < 60);
      }).toList().cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _pronunciationAreas {
    final themes = _vocabulary
        .map((v) => (v['theme'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    return themes.take(6).map((t) {
      final count = _vocabulary.where((v) => v['theme']?.toString() == t).length;
      return {'label': t.replaceAll('_', ' '), 'desc': '$count words to practice', 'progress': 0.0};
    }).toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildConversationTab(),
                        _buildPronunciationTab(),
                        _buildRolePlayTab(),
                      ],
                    ),
            ),
            _buildRecordButton(),
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
          const Icon(Icons.mic, color: AppColors.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Speaking & Pronunciation', style: TextStyle(
                  color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
                )),
                Text('${_phrases.length} phrases \u00b7 ${_grammar.length} grammar rules',
                    style: TextStyle(
                      color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 11,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: context.colors.surface,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: context.colors.textSecondary,
        indicatorColor: AppColors.primary,
        tabs: [
          const Tab(text: 'Phrases'),
          const Tab(text: 'Pronunciation'),
          const Tab(text: 'Role Play'),
        ],
      ),
    );
  }

  Widget _buildConversationTab() {
    final items = _phrases.isNotEmpty ? _phrases : _vocabulary.take(20).toList();
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48,
              color: context.colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No phrases available', style: TextStyle(
              color: context.colors.textSecondary.withValues(alpha: 0.6), fontSize: 14,
            )),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final word = (item['word'] ?? '').toString();
        final example = (item['example_sentence'] ?? item['translation'] ?? '').toString();
        final pos = (item['part_of_speech'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconForPos(pos), color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word, style: TextStyle(
                      color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
                    )),
                    Text(example, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 12,
                      )),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.colors.textSecondary.withValues(alpha: 0.5), size: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPronunciationTab() {
    final areas = _pronunciationAreas;
    if (areas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.record_voice_over, size: 48,
              color: context.colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No pronunciation areas yet', style: TextStyle(
              color: context.colors.textSecondary.withValues(alpha: 0.6), fontSize: 14,
            )),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: areas.length,
      itemBuilder: (ctx, i) {
        final p = areas[i];
        final progress = (0.1 + (i * 0.15)).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
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
                    child: Text(p['label'], style: TextStyle(
                      color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
                    )),
                  ),
                  Text('${(progress * 100).toInt()}%', style: const TextStyle(
                    color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600,
                  )),
                ],
              ),
              const SizedBox(height: 4),
              Text(p['desc'], style: TextStyle(
                color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 12,
              )),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: context.colors.surfaceHighest,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRolePlayTab() {
    if (_grammar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.record_voice_over, size: 48,
              color: context.colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('Role Play', style: TextStyle(
              color: context.colors.textSecondary.withValues(alpha: 0.6),
              fontSize: 16, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Practice grammar rules through AI-powered role play scenarios.',
                style: TextStyle(
                  color: context.colors.textSecondary.withValues(alpha: 0.5), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _grammar.length,
      itemBuilder: (ctx, i) {
        final g = _grammar[i];
        final title = (g['title'] ?? '').toString();
        final rule = (g['rule'] ?? g['explanation'] ?? '').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
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
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.record_voice_over, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: TextStyle(
                      color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600,
                    )),
                  ),
                  Icon(Icons.chevron_right, color: context.colors.textSecondary.withValues(alpha: 0.5)),
                ],
              ),
              if (rule.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(rule, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecordButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.divider)),
      ),
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _isRecording = !_isRecording),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _isRecording ? const Color(0xFFEF4444) : AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? const Color(0xFFEF4444) : AppColors.primary)
                      .withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: _isRecording ? 4 : 0,
                ),
              ],
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.mic,
              color: Colors.white, size: 28,
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForPos(String pos) {
    switch (pos) {
      case 'n': return Icons.book;
      case 'v': return Icons.flash_on;
      case 'adj': return Icons.format_italic;
      case 'adv': return Icons.speed;
      case 'prep': return Icons.account_tree;
      case 'conj': return Icons.link;
      case 'pron': return Icons.person;
      case 'det': return Icons.filter_list;
      case 'num': return Icons.tag;
      case 'excl': return Icons.record_voice_over;
      case 'phrase': return Icons.chat_bubble;
      default: return Icons.category;
    }
  }
}
