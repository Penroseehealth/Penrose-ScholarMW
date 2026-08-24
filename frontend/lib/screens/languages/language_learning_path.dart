import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../core/theme/theme_colors.dart';

class LanguageLearningPath extends StatefulWidget {
  const LanguageLearningPath({super.key});

  @override
  State<LanguageLearningPath> createState() => _LanguageLearningPathState();
}

class _LanguageLearningPathState extends State<LanguageLearningPath> {
  final LanguageService _service = LanguageService();
  List<dynamic> _levels = [];
  bool _loading = true;
  bool _didLoad = false;

  String get _slug =>
      GoRouterState.of(context).pathParameters['slug'] ?? 'english';

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
      final data = await _service.getLevels(_slug);
      if (!mounted) return;
      setState(() {
        _levels = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[LANGUAGE LEARNING PATH] Load error for $_slug: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Learning Path'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _levels.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _levels.length,
                  itemBuilder: (ctx, i) {
                    final level = _levels[i];
                    final name = level['name'] ?? 'Level ${i + 1}';
                    final form = level['form_mapping'] ?? '';
                    final desc = level['description'] ?? '';
                    final lessonCount = level['lesson_count'] ?? 0;
                    final isFirst = i == 0;
                    final isLast = i == _levels.length - 1;

                    final levelSlug = (level['slug'] ?? '').toString();

                    return GestureDetector(
                      onTap: levelSlug.isNotEmpty
                          ? () => context.push('/language/$_slug/levels/$levelSlug')
                          : null,
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isFirst
                                    ? AppColors.primary
                                    : context.colors.surfaceElevated,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isFirst
                                        ? AppColors.primary
                                        : context.colors.border),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isFirst
                                        ? Colors.white
                                        : context.colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 50,
                                color: context.colors.border,
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isFirst
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : context.colors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (form.isNotEmpty)
                                  Text(form,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.0,
                                          color: isFirst
                                              ? AppColors.primary
                                              : context.colors.textMuted)),
                                const SizedBox(height: 4),
                                Text(name,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(desc,
                                    style: TextStyle(
                                        fontSize: 12, color: context.colors.textMuted)),
                                const SizedBox(height: 8),
                                Text('$lessonCount lessons',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isFirst
                                            ? AppColors.primary
                                            : context.colors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ],
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
          Icon(Icons.route, size: 48, color: context.colors.textMuted),
          const SizedBox(height: 12),
          Text('No learning path available',
              style: TextStyle(fontSize: 16, color: context.colors.textMuted)),
        ],
      ),
    );
  }
}
