import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/language_service.dart';

class LanguageLevels extends StatefulWidget {
  const LanguageLevels({super.key});

  @override
  State<LanguageLevels> createState() => _LanguageLevelsState();
}

class _LanguageLevelsState extends State<LanguageLevels> {
  final LanguageService _service = LanguageService();
  List<dynamic> _levels = [];
  bool _loading = true;
  bool _didLoad = false;

  String get _slug => GoRouterState.of(context).pathParameters['slug'] ?? 'english';

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
      debugPrint('[LANGUAGE LEVELS] Load error for $_slug: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: const Text('Levels'),
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
                      final name = (level['name'] ?? 'Level ${i + 1}') as String;
                      final form = (level['form_mapping'] ?? '') as String;
                      final desc = (level['description'] ?? '') as String;
                      final unitCount = level['unit_count'] ?? 0;
                      final lessonCount = level['lesson_count'] ?? 0;

                      final levelSlug = (level['slug'] ?? '').toString();
                      return GestureDetector(
                        onTap: levelSlug.isNotEmpty ? () => context.push('/language/$_slug/levels/$levelSlug') : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (form.isNotEmpty)
                                      Text(form.toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.0,
                                              color: AppColors.primary)),
                                    const SizedBox(height: 2),
                                    Text(name,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: context.colors.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(desc,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                children: [
                                  _statChip('$unitCount', 'Units'),
                                  const SizedBox(height: 4),
                                  _statChip('$lessonCount', 'Lessons'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      );

  Widget _statChip(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$value $label', style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 48, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text('No levels available', style: TextStyle(fontSize: 16, color: context.colors.textMuted)),
          ],
        ),
      );
}
