import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/stem_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/error_state.dart';
import '../../modules/subject_module.dart';
import '../../core/theme/theme_colors.dart';

class SubjectDashboardScreen extends StatefulWidget {
  final String slug;
  final String title;

  SubjectDashboardScreen({
    super.key,
    required this.slug,
    required this.title,
  });

  @override
  State<SubjectDashboardScreen> createState() => _SubjectDashboardScreenState();
}

class _SubjectDashboardScreenState extends State<SubjectDashboardScreen> {
  final StemService _stemService = StemService();
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _stemService.getSubjectDashboard(widget.slug);
      if (mounted) {
        setState(() {
          _dashboard = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final module = SubjectModule.fromSlug(widget.slug);
    final accentColor = module?.color ?? AppColors.primary;

    if (_loading) {
      return _buildScaffold(accentColor, child: const _DashboardLoading());
    }
    if (_error != null) {
      return _buildScaffold(accentColor, child: ErrorState(
        message: 'Failed to load dashboard',
        details: _error,
        onRetry: _loadDashboard,
      ));
    }
    if (_dashboard == null || _dashboard!.isEmpty) {
      return _buildScaffold(accentColor, child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(module?.icon ?? Icons.school_outlined, size: 48, color: context.colors.textMuted),
            SizedBox(height: 12),
            Text('No data available', style: TextStyle(color: context.colors.textMuted)),
          ],
        ),
      ));
    }

    return _buildScaffold(accentColor, child: _buildContent(accentColor));
  }

  Widget _buildScaffold(Color accentColor, {required Widget child}) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: accentColor,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colors.textPrimary, size: 18),
                onPressed: () => Navigator.maybePop(context),
              ),
              backgroundColor: AppColors.primaryDark,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.title.isNotEmpty ? widget.title : (_dashboard?['subject_title'] ?? widget.slug),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor.withValues(alpha: 0.8), accentColor.withValues(alpha: 0.4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Color accentColor) {
    final greeting = _dashboard!['greeting'] ?? '';
    final progress = _dashboard!['progress'] as Map<String, dynamic>? ?? {};
    final currentLearning = _dashboard!['current_learning'] as Map<String, dynamic>?;
    final recommendations = (_dashboard!['recommendations'] as List?) ?? [];
    final recentActivity = _dashboard!['recent_activity'] as Map<String, dynamic>?;
    final totalConcepts = _dashboard!['total_concepts'] ?? 0;
    final masteredConcepts = _dashboard!['mastered_concepts'] ?? 0;
    final inProgressConcepts = _dashboard!['in_progress_concepts'] ?? 0;
    final totalAttempts = _dashboard!['total_practice_attempts'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          _buildGreeting(greeting),
          SizedBox(height: 20),
          _buildConceptCounts(totalConcepts, masteredConcepts, inProgressConcepts, totalAttempts, accentColor),
          SizedBox(height: 20),
          _buildProgressSection(progress, accentColor),
          if (currentLearning != null) ...[
            SizedBox(height: 20),
            _buildCurrentLearning(currentLearning, accentColor),
          ],
          if (recommendations.isNotEmpty) ...[
            SizedBox(height: 20),
            _buildRecommendations(recommendations, accentColor),
          ],
          if (recentActivity != null) ...[
            SizedBox(height: 20),
            _buildRecentActivity(recentActivity, accentColor),
          ],
          SizedBox(height: 20),
          _buildSyllabusButton(accentColor),
          SizedBox(height: 20),
          _buildActionButtons(accentColor),
        ],
      ),
    );
  }

  Widget _buildGreeting(String greeting) {
    return Text(
      greeting,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
      ),
    );
  }

  Widget _buildConceptCounts(int total, int mastered, int inProgress, int attempts, Color accent) {
    return Row(
      children: [
        _buildCountChip('$total', 'Concepts', accent),
        SizedBox(width: 8),
        _buildCountChip('$mastered', 'Mastered', context.colors.success),
        SizedBox(width: 8),
        _buildCountChip('$inProgress', 'In Progress', context.colors.warning),
        SizedBox(width: 8),
        _buildCountChip('$attempts', 'Practices', context.colors.info),
      ],
    );
  }

  Widget _buildCountChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(Map<String, dynamic> progress, Color accent) {
    final items = [
      _ProgressItem('Overall Mastery', (progress['overall_mastery'] as num?)?.toDouble() ?? 0, accent),
      _ProgressItem('Current Topic', (progress['current_topic_mastery'] as num?)?.toDouble() ?? 0, context.colors.info),
      _ProgressItem('Course Completion', (progress['course_completion'] as num?)?.toDouble() ?? 0, context.colors.teal),
      _ProgressItem('Assessment Avg', (progress['assessment_average'] as num?)?.toDouble() ?? 0, context.colors.lavender),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 14),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                    ),
                    Text(
                      '${item.value.round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.value / 100,
                    backgroundColor: context.colors.surfaceHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(item.color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildCurrentLearning(Map<String, dynamic> cl, Color accent) {
    final conceptTitle = cl['concept_title'] ?? '';
    final topicTitle = cl['topic_title'] ?? '';
    final masteryLevel = (cl['mastery_level'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: () {
        final conceptId = cl['concept_id'];
        if (conceptId != null) {
          context.push('/stem-concept/$conceptId?title=${Uri.encodeComponent(conceptTitle)}');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.play_circle_outline_rounded, color: accent, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continue Learning',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textMuted),
                  ),
                  SizedBox(height: 2),
                  Text(
                    conceptTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (topicTitle.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      topicTitle,
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 12),
            _MiniMasteryRing(mastery: masteryLevel, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(List recommendations, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Recommended',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...recommendations.map((r) => _buildRecommendationItem(r, accent)),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(Map<String, dynamic> rec, Color accent) {
    final conceptId = rec['concept_id'];
    final title = rec['concept_title'] ?? '';
    final reason = rec['reason'] ?? '';
    final topicTitle = rec['topic_title'] ?? '';
    final masteryLevel = (rec['mastery_level'] as num?)?.toDouble() ?? 0;

    return GestureDetector(
      onTap: () {
        if (conceptId != null) {
          context.push('/stem-concept/$conceptId?title=${Uri.encodeComponent(title)}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              masteryLevel > 0 ? Icons.trending_up_rounded : Icons.add_circle_outline_rounded,
              color: masteryLevel > 0 ? context.colors.warning : context.colors.info,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    topicTitle.isNotEmpty ? '$reason \u2022 $topicTitle' : reason,
                    style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(Map<String, dynamic> activity, Color accent) {
    final conceptTitle = activity['concept_title'] ?? '';
    final questionType = activity['question_type'] ?? '';
    final masteryLevel = (activity['mastery_level'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: context.colors.info, size: 18),
              SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conceptTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (questionType.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        questionType.toUpperCase(),
                        style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12),
              _MiniMasteryRing(mastery: masteryLevel, color: accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusButton(Color accent) {
    final slug = widget.slug;
    if (slug != 'mathematics' && slug != 'chemistry') {
      return const SizedBox.shrink();
    }
    final route = slug == 'mathematics' ? '/math-syllabus' : '/chem-syllabus';
    final label = slug == 'mathematics' ? 'View Mathematics Syllabus' : 'View Chemistry Syllabus';
    final icon = slug == 'mathematics' ? Icons.calculate_rounded : Icons.science_rounded;

    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Color accent) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.route_rounded,
                label: 'Learning Path',
                color: accent,
                onTap: () => context.push('/learning-path/${widget.slug}?title=${Uri.encodeComponent(widget.title)}'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                icon: Icons.psychology_outlined,
                label: 'Penrose Learning Assistant',
                color: context.colors.teal,
                onTap: () => context.push('/stem-tutor'),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.quiz_outlined,
                label: 'Practice',
                color: context.colors.info,
                onTap: () => context.push('/stem-mastery'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _buildActionButton(
                icon: Icons.timer_outlined,
                label: 'Mock Exam',
                color: context.colors.lavender,
                onTap: () => context.push('/mock-exam'),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.push('/study-planner'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.teal.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined, color: context.colors.teal, size: 16),
                SizedBox(width: 6),
                Text('Study Planner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.teal)),
              ],
            ),
          ),
        ),
        SizedBox(height: 10),
        GestureDetector(
          onTap: () => context.push('/exam-analytics'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.lavender.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.lavender.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, color: context.colors.lavender, size: 16),
                SizedBox(width: 6),
                Text('View Exam Analytics', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.lavender)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressItem {
  final String label;
  final double value;
  final Color color;
  const _ProgressItem(this.label, this.value, this.color);
}

class _MiniMasteryRing extends StatelessWidget {
  final double mastery;
  final Color color;
  const _MiniMasteryRing({required this.mastery, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: mastery / 100,
            strokeWidth: 3.5,
            backgroundColor: context.colors.surfaceHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Center(
            child: Text(
              '${mastery.round()}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 24,
            decoration: BoxDecoration(
              color: context.colors.shimmerBase,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          SizedBox(height: 20),
          ShimmerLoading.grid(count: 4),
          SizedBox(height: 20),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: context.colors.shimmerBase,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}
