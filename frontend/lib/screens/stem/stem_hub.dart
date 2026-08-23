import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/stem_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../modules/subject_module.dart';
import '../../core/theme/theme_colors.dart';

class StemHub extends StatefulWidget {
  StemHub({super.key});

  @override
  State<StemHub> createState() => _StemHubState();
}

class _StemHubState extends State<StemHub> {
  final StemService _stemService = StemService();
  List<dynamic> _subjects = [];
  bool _loading = true;
  String? _error;

  static const _languageHubs = [
    {'name': 'English', 'slug': 'english', 'colorHex': 0xFF2563EB, 'desc': 'Complete English learning from foundation to academic proficiency'},
    {'name': 'Chinese', 'slug': 'chinese', 'colorHex': 0xFFDC2626, 'desc': 'Progressive Chinese learning aligned with HSK standards'},
    {'name': 'Arabic', 'slug': 'arabic', 'colorHex': 0xFF059669, 'desc': 'Structured Arabic from alphabet mastery to academic proficiency'},
  ];

  static const _languageIcons = <String, IconData>{
    'english': Icons.abc_rounded,
    'chinese': Icons.translate,
    'arabic': Icons.menu_book_rounded,
  };

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() { _loading = true; _error = null; });
    try {
      final subjects = await _stemService.getSubjects();
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  IconData _getIcon(String? slug) {
    final module = SubjectModule.fromSlug(slug ?? '');
    if (module != null) return module.icon;

    return Icons.school_outlined;
  }

  Color _getAccentColor(String? slug) {
    final module = SubjectModule.fromSlug(slug ?? '');
    if (module != null) return module.color;

    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _loadSubjects,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            expandedHeight: 90,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'STEM Intelligence',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryMuted],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildQuickStats(),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.translate_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Language Hubs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildLanguageCard(_languageHubs[index]),
                childCount: _languageHubs.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'STEM Subjects',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(child: ErrorState(message: 'Failed to load subjects', details: _error, onRetry: _loadSubjects))
          else if (_loading)
            SliverToBoxAdapter(child: ShimmerLoading.grid(count: 6))
          else if (_subjects.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.school_outlined,
                title: 'No subjects available',
                subtitle: 'STEM subjects will appear here',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildSubjectCard(_subjects[index]),
                  childCount: _subjects.length,
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final enabledCount = SubjectModule.values.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _buildStatChip('$enabledCount Subjects', AppColors.primary),
          SizedBox(width: 8),
          _buildStatChip('Independent Modules', context.colors.teal),
          SizedBox(width: 8),
          _buildStatChip('AI-Powered', context.colors.info),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(dynamic subject) {
    final slug = subject['slug'] ?? subject['subject_slug'] ?? '';
    final module = SubjectModule.fromSlug(slug);
    final accentColor = module?.color ?? _getAccentColor(slug);
    final iconData = module?.icon ?? _getIcon(slug);

    return GestureDetector(
      onTap: () {
        final title = subject['name'] ?? subject['title'] ?? module?.title ?? 'Subject';
        context.push('/stem-subject/$slug?title=${Uri.encodeComponent(title)}');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: double.infinity,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: accentColor, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject['title'] ?? subject['name'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    subject['description'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(Map<String, dynamic> hub) {
    final accentColor = Color(hub['colorHex'] as int);
    final slug = hub['slug'] as String;
    final iconData = _languageIcons[slug] ?? Icons.language_rounded;
    return GestureDetector(
      onTap: () => context.push('/language/${hub['slug']}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: double.infinity,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: accentColor, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hub['name']! as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    hub['desc']! as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
