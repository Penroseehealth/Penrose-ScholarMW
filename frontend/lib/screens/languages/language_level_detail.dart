import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../core/theme/theme_colors.dart';

class LanguageLevelDetail extends StatefulWidget {
  LanguageLevelDetail({super.key});

  @override
  State<LanguageLevelDetail> createState() => _LanguageLevelDetailState();
}

class _LanguageLevelDetailState extends State<LanguageLevelDetail> {
  final LanguageService _service = LanguageService();
  Map<String, dynamic> _level = {};
  List<dynamic> _units = [];
  bool _loading = true;
  bool _didLoad = false;

  String get _slug =>
      GoRouterState.of(context).pathParameters['slug'] ?? 'english';

  String get _levelSlug =>
      GoRouterState.of(context).pathParameters['levelSlug'] ?? '';

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
      final data = await _service.getLevel(_slug, _levelSlug);
      if (!mounted) return;
      setState(() {
        _level = data;
        _units = data['units'] ?? [];
        _loading = false;
      });
    } catch (e) {
      debugPrint('[LANGUAGE LEVEL DETAIL] Load error for $_slug/$_levelSlug: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(_level['name'] ?? 'Level Detail'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _units.isEmpty
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final name = (_level['name'] ?? '').toString();
    final form = (_level['form_mapping'] ?? '').toString();
    final desc = (_level['description'] ?? '').toString();
    final prof = (_level['proficiency_label'] ?? '').toString();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (form.isNotEmpty)
                  Text(form.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      )),
                SizedBox(height: 6),
                Text(name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    )),
                if (desc.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Text(desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMuted,
                        height: 1.5,
                      )),
                ],
                if (prof.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(prof,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        )),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildUnitCard(_units[i], i),
              childCount: _units.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitCard(dynamic unit, int index) {
    final unitName = (unit['name'] ?? 'Unit ${index + 1}').toString();
    final unitDesc = (unit['description'] ?? '').toString();
    final lessonCount = unit['lesson_count'] ?? 0;
    final vocabCount = unit['vocab_count'] ?? 0;
    final isOpen = index == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen
              ? AppColors.primary.withValues(alpha: 0.3)
              : context.colors.border,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          initiallyExpanded: isOpen,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isOpen
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('${index + 1}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isOpen ? AppColors.primary : context.colors.textMuted,
                  )),
            ),
          ),
          title: Text(unitName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              )),
          subtitle: Text(
            '$lessonCount lessons \u00b7 $vocabCount words',
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
          trailing: Icon(
            isOpen ? Icons.keyboard_arrow_up_rounded : Icons.chevron_right_rounded,
            color: context.colors.textMuted,
            size: 20,
          ),
          children: [
            if (unitDesc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(unitDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                      height: 1.5,
                    )),
              ),
            ...List.generate(lessonCount, (li) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      li == 0
                          ? Icons.play_circle_filled
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: li == 0 ? AppColors.primary : context.colors.textMuted,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Lesson ${li + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          )),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: context.colors.textMuted),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 48, color: context.colors.textMuted),
          SizedBox(height: 12),
          Text('No units available',
              style: TextStyle(fontSize: 16, color: context.colors.textMuted)),
        ],
      ),
    );
  }
}
