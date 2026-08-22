import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';

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
      debugPrint('[LANGUAGE LEARNING PATH] Load error for ${_slug}: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Learning Path'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
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
                    final isActive = i == 0;

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
                                    : AppColors.surfaceElevated,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isFirst
                                        ? AppColors.primary
                                        : AppColors.border),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isFirst
                                        ? Colors.white
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 50,
                                color: AppColors.border,
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isFirst
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : AppColors.border,
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
                                              : AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(desc,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textMuted)),
                                const SizedBox(height: 8),
                                Text('$lessonCount lessons',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isFirst
                                            ? AppColors.primary
                                            : AppColors.textSecondary)),
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
          Icon(Icons.route, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('No learning path available',
              style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
