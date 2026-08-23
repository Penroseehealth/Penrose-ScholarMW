import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../core/theme/theme_colors.dart';

class LanguageWriting extends StatefulWidget {
  LanguageWriting({super.key});
  @override
  State<LanguageWriting> createState() => _LanguageWritingState();
}

class _LanguageWritingState extends State<LanguageWriting> {
  final LanguageService _service = LanguageService();
  final _textController = TextEditingController();
  bool _showFeedback = false;
  bool _didLoad = false;
  List<dynamic> _vocabulary = [];
  List<dynamic> _grammar = [];

  String get _slug =>
      GoRouterState.of(context).pathParameters['slug'] ?? 'english';

  List<Map<String, dynamic>> get _prompts {
    final themes = _vocabulary
        .map((v) => (v['theme'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    final levels = ['Beginner', 'Elementary', 'Intermediate', 'Advanced'];
    return themes.take(4).map((t) {
      final idx = themes.indexOf(t);
      final level = levels[idx % levels.length];
      final words = _vocabulary.where((v) => v['theme']?.toString() == t).take(3).map((v) => v['word'] ?? '').join(', ');
      return {
        'title': t.replaceAll('_', ' '),
        'desc': 'Write about ${t.replaceAll('_', ' ')} using: $words',
        'difficulty': level,
        'theme': t,
      };
    }).toList();
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
    try {
      final results = await Future.wait([
        _service.getVocabulary(_slug),
        _service.getGrammar(_slug),
      ]);
      if (!mounted) return;
      setState(() {
        _vocabulary = results[0];
        _grammar = results[1];
      });
    } catch (e) {
      debugPrint('[LANGUAGE WRITING] Load error for $_slug: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWritingArea(),
                    SizedBox(height: 16),
                    _buildActionButtons(),
                    if (_showFeedback) ...[
                      SizedBox(height: 16),
                      _buildFeedbackSection(),
                    ],
                    SizedBox(height: 16),
                    _buildPromptsSection(),
                  ],
                ),
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
          Icon(Icons.edit_note, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Writing Workspace', style: TextStyle(
                  color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
                )),
                Text('${_vocabulary.length} vocabulary words \u00b7 ${_grammar.length} grammar rules', style: TextStyle(
                  color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 11,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWritingArea() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.colors.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.edit, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text('Your Writing', style: TextStyle(
                  color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                )),
                Spacer(),
                Text(
                  '${_textController.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
                  style: TextStyle(
                    color: context.colors.textSecondary.withValues(alpha: 0.6), fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: _textController,
            maxLines: 8, minLines: 5,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 15, height: 1.7),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Start writing here...\n\nYou can write in the target language or your native language. The AI tutor will help correct and improve your writing.',
              hintStyle: TextStyle(color: context.colors.textSecondary.withValues(alpha: 0.4)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _btn('AI Feedback', Icons.auto_awesome, AppColors.primary, () {
            setState(() => _showFeedback = !_showFeedback);
          }),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _btn('Clear', Icons.delete_outline, context.colors.textSecondary, () {
            _textController.clear();
            setState(() => _showFeedback = false);
          }),
        ),
      ],
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w600,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    final hasText = _textController.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
              SizedBox(width: 6),
              Text('AI Feedback', style: TextStyle(
                color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600,
              )),
            ],
          ),
          SizedBox(height: 10),
          Text(
            hasText
                ? 'Your writing shows good structure. You have used ${_textController.text.split(RegExp(r"\s+")).length} words. Consider using more descriptive adjectives and vary your sentence patterns.'
                : 'Write something to get feedback on your grammar, vocabulary, and style.',
            style: TextStyle(
              color: context.colors.textSecondary, fontSize: 13, height: 1.5,
            ),
          ),
          if (hasText && _grammar.isNotEmpty) ...[
            SizedBox(height: 10),
            Text('Grammar rules to review:', style: TextStyle(
              color: context.colors.textPrimary.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600,
            )),
            SizedBox(height: 4),
            ...(_grammar.take(3).map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('\u2022 ${(g['title'] ?? '').toString()}',
                style: TextStyle(color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
            ))),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptsSection() {
    final prompts = _prompts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Writing Prompts', style: TextStyle(
          color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold,
        )),
        SizedBox(height: 10),
        if (prompts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.divider),
            ),
            child: Text('No vocabulary themes available for prompts yet.',
              style: TextStyle(color: context.colors.textSecondary.withValues(alpha: 0.6), fontSize: 13)),
          )
        else
          ...prompts.map((p) => GestureDetector(
            onTap: () {
              _textController.clear();
              setState(() {
                _showFeedback = false;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['title'], style: TextStyle(
                          color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                        )),
                        SizedBox(height: 2),
                        Text(p['desc'], maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 12,
                          )),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(p['difficulty'], style: TextStyle(
                      color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 10,
                    )),
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }
}
