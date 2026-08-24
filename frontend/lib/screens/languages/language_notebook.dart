import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/language_service.dart';

class LanguageNotebook extends StatefulWidget {
  const LanguageNotebook({super.key});
  @override
  State<LanguageNotebook> createState() => _LanguageNotebookState();
}

class _LanguageNotebookState extends State<LanguageNotebook> with SingleTickerProviderStateMixin {
  final LanguageService _service = LanguageService();
  List<dynamic> _vocabulary = [];
  List<dynamic> _grammar = [];
  bool _loading = true;
  bool _didLoad = false;
  late TabController _tabController;

  final List<Map<String, dynamic>> _customNotes = [];

  String get _slug => GoRouterState.of(context).pathParameters['slug'] ?? 'english';

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
      debugPrint('[LANGUAGE NOTEBOOK] Load error for $_slug: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                          _buildSavedWordsTab(),
                          _buildGrammarNotesTab(),
                          _buildCustomNotesTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showAddNoteDialog();
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      );

  Widget _buildHeader() => Container(
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
            const Icon(Icons.note, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Language Notebook',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                  Text('${_vocabulary.length} saved words \u00b7 ${_grammar.length} grammar notes',
                      style: TextStyle(
                        color: context.colors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 11,
                      )),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildTabBar() => Container(
        color: context.colors.surface,
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.colors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Saved Words'),
            Tab(text: 'Grammar Notes'),
            Tab(text: 'Custom Notes'),
          ],
        ),
      );

  Widget _buildSavedWordsTab() {
    if (_vocabulary.isEmpty) return _emptyTab('No saved words yet');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vocabulary.length,
      itemBuilder: (ctx, i) {
        final w = _vocabulary[i];
        final word = (w['word'] ?? '').toString();
        final translation = (w['translation'] ?? '').toString();
        final pos = (w['part_of_speech'] ?? '').toString();
        return _noteCard(
          title: word,
          subtitle: '$translation${pos.isNotEmpty ? ' ($pos)' : ''}',
          date: (w['theme'] ?? '').toString().replaceAll('_', ' '),
          icon: Icons.bookmark,
        );
      },
    );
  }

  Widget _buildGrammarNotesTab() {
    if (_grammar.isEmpty) return _emptyTab('No grammar notes yet');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _grammar.length,
      itemBuilder: (ctx, i) {
        final n = _grammar[i];
        final title = (n['title'] ?? '').toString();
        final rule = (n['rule'] ?? n['explanation'] ?? '').toString();
        return _noteCard(
          title: title,
          subtitle: rule,
          date: (n['level'] ?? '').toString(),
          icon: Icons.rule,
        );
      },
    );
  }

  Widget _buildCustomNotesTab() {
    if (_customNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_add_outlined, size: 48, color: context.colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No custom notes yet',
                style: TextStyle(
                  color: context.colors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                )),
            const SizedBox(height: 8),
            Text('Tap + to add a note',
                style: TextStyle(
                  color: context.colors.textSecondary.withValues(alpha: 0.4),
                  fontSize: 12,
                )),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _customNotes.length,
      itemBuilder: (ctx, i) {
        final n = _customNotes[i];
        return _noteCard(
          title: n['title'] ?? 'Note',
          subtitle: n['content'] ?? '',
          date: 'Custom',
          icon: Icons.sticky_note_2,
        );
      },
    );
  }

  Widget _emptyTab(String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_add_outlined, size: 48, color: context.colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(msg,
                style: TextStyle(
                  color: context.colors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 14,
                )),
          ],
        ),
      );

  Widget _noteCard({
    required String title,
    required String subtitle,
    required String date,
    required IconData icon,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 12,
                        )),
                ],
              ),
            ),
            if (date.isNotEmpty)
              Text(date,
                  style: TextStyle(
                    color: context.colors.textSecondary.withValues(alpha: 0.5),
                    fontSize: 11,
                  )),
          ],
        ),
      );

  void _showAddNoteDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Add Custom Note', style: TextStyle(color: context.colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: context.colors.textSecondary.withValues(alpha: 0.5)),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Note content...',
                hintStyle: TextStyle(color: context.colors.textSecondary.withValues(alpha: 0.5)),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                setState(() {
                  _customNotes.add({
                    'title': titleCtrl.text,
                    'content': contentCtrl.text,
                  });
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
