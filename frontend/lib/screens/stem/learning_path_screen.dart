import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/stem_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/error_state.dart';
import '../../modules/subject_module.dart';

class LearningPathScreen extends StatefulWidget {
  final String slug;
  final String title;

  const LearningPathScreen({super.key, required this.slug, required this.title});

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  final StemService _stemService = StemService();
  Map<String, dynamic>? _path;
  List<dynamic> _dueReviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _stemService.getLearningPath(widget.slug),
        _stemService.getDueReviews(),
      ]);
      if (mounted) {
        setState(() {
          _path = results[0];
          _dueReviews = results[1];
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: accentColor,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
                onPressed: () => Navigator.maybePop(context),
              ),
              backgroundColor: AppColors.primaryDark,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  '${widget.title} Learning Path',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
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
            if (_error != null)
              SliverToBoxAdapter(child: ErrorState(message: 'Failed to load', details: _error, onRetry: _loadData))
            else if (_loading)
              SliverToBoxAdapter(child: ShimmerLoading.list(count: 5))
            else ...[
              if (_dueReviews.isNotEmpty)
                SliverToBoxAdapter(child: _buildDueReviews(accentColor)),
              SliverToBoxAdapter(child: _buildSummary(accentColor)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'All Concepts',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
              ),
              _buildStepsList(accentColor),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDueReviews(Color accent) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_dueReviews.length} concept${_dueReviews.length == 1 ? '' : 's'} due for review',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...(_dueReviews.take(3).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => context.push('/stem-concept/${r['concept_id']}?title=${Uri.encodeComponent(r['concept_title'] ?? '')}'),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r['concept_title'] ?? '',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${((r['mastery_level'] as num?)?.toDouble() ?? 0 * 100).round()}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                ],
              ),
            ),
          ))),
        ],
      ),
    );
  }

  Widget _buildSummary(Color accent) {
    if (_path == null) return const SizedBox.shrink();
    final completed = _path!['completed_steps'] ?? 0;
    final inProgress = _path!['in_progress_steps'] ?? 0;
    final notStarted = _path!['not_started_steps'] ?? 0;
    final total = _path!['total_steps'] ?? 0;
    final minutes = _path!['estimated_total_minutes'] ?? 0;
    final progress = total > 0 ? completed / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progress', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceHighest,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildMiniStat('Completed', '$completed', AppColors.success),
                const SizedBox(width: 12),
                _buildMiniStat('In Progress', '$inProgress', AppColors.info),
                const SizedBox(width: 12),
                _buildMiniStat('Not Started', '$notStarted', AppColors.textMuted),
                const SizedBox(width: 12),
                _buildMiniStat('Est.', '~${minutes}m', AppColors.lavender),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStepsList(Color accent) {
    final steps = (_path?['steps'] as List?) ?? [];
    if (steps.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Text('No concepts found', style: TextStyle(color: AppColors.textMuted)),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildStepItem(steps[index], accent),
          childCount: steps.length,
        ),
      ),
    );
  }

  Widget _buildStepItem(Map<String, dynamic> step, Color accent) {
    final conceptId = step['concept_id'];
    final title = step['concept_title'] ?? '';
    final topicTitle = step['topic_title'] ?? '';
    final masteryLevel = (step['mastery_level'] as num?)?.toDouble() ?? 0;
    final status = step['status'] ?? 'not_started';
    final est = step['estimated_minutes'] ?? 15;
    final stepNum = step['step_number'] ?? 0;
    final priority = step['priority'] ?? 'medium';

    final isCompleted = status == 'completed';
    final isInProgress = status == 'in_progress';
    final color = isCompleted
        ? AppColors.success
        : isInProgress
            ? AppColors.info
            : AppColors.textMuted;

    return GestureDetector(
      onTap: () => context.push('/stem-concept/$conceptId?title=${Uri.encodeComponent(title)}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInProgress ? accent.withValues(alpha: 0.3) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check_rounded, color: color, size: 16)
                    : Text(
                        '$stepNum',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (topicTitle.isNotEmpty) ...[
                        Text(topicTitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(width: 8),
                      ],
                      Text('~${est}m', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (masteryLevel > 0)
              SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: masteryLevel / 100,
                      strokeWidth: 3,
                      backgroundColor: AppColors.surfaceHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                    Center(
                      child: Text(
                        '${masteryLevel.round()}',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
              )
            else if (priority == 'high')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Start', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.warning)),
              ),
          ],
        ),
      ),
    );
  }
}
