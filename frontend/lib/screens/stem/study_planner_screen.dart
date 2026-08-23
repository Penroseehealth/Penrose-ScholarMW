import 'package:flutter/material.dart';
import '../../services/stem_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../core/theme/theme_colors.dart';

class StudyPlannerScreen extends StatefulWidget {
  StudyPlannerScreen({super.key});

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  final StemService _stemService = StemService();
  List<dynamic> _dailyTasks = [];
  Map<String, dynamic> _overview = {};
  List<dynamic> _subjects = [];
  bool _loading = true;
  String? _error;

  String _selectedSubjectSlug = '';
  double _dailyMinutes = 60;
  int _daysAhead = 14;
  bool _generating = false;

  final Set<int> _completedTasks = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _stemService.getDailyStudyPlan(),
        _stemService.getStudyPlanOverview(),
        _stemService.getSubjects(),
      ]);
      if (mounted) {
        setState(() {
          _dailyTasks = List<dynamic>.from(results[0] as List);
          _overview = Map<String, dynamic>.from(results[1] as Map);
          _subjects = List<dynamic>.from(results[2] as List);
          if (_subjects.isNotEmpty && _selectedSubjectSlug.isEmpty) {
            _selectedSubjectSlug = _subjects[0]['slug'] ?? '';
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _generatePlan() async {
    if (_selectedSubjectSlug.isEmpty || _generating) return;
    setState(() { _generating = true; });
    try {
      await _stemService.generateStudyPlan(
        _selectedSubjectSlug,
        dailyMinutes: _dailyMinutes.round(),
        daysAhead: _daysAhead,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Study plan generated!'), backgroundColor: context.colors.success),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate plan: $e'), backgroundColor: context.colors.error),
        );
      }
    } finally {
      if (mounted) setState(() { _generating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100,
              pinned: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colors.textPrimary, size: 18),
                onPressed: () => Navigator.maybePop(context),
              ),
              backgroundColor: AppColors.primaryDark,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Study Planner',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
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
            if (_error != null)
              SliverToBoxAdapter(child: ErrorState(message: 'Failed to load', details: _error, onRetry: _loadData))
            else if (_loading)
              SliverToBoxAdapter(child: ShimmerLoading.list(count: 5))
            else ...[
              SliverToBoxAdapter(child: _buildTodaysTasks()),
              SliverToBoxAdapter(child: _buildGeneratePlan()),
              SliverToBoxAdapter(child: _buildPlanOverview()),
              SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTodaysTasks() {
    final tasks = _dailyTasks;
    final activeTasks = tasks.whereType<Map<String, dynamic>>().toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Today\'s Study Tasks', Icons.calendar_today_outlined),
            SizedBox(height: 14),
            if (activeTasks.isEmpty)
              EmptyState(
                icon: Icons.task_alt_rounded,
                title: 'No tasks for today',
                subtitle: 'Generate a study plan to get started!',
                padding: EdgeInsets.symmetric(vertical: 16),
              )
            else
              ...activeTasks.asMap().entries.map((entry) => _buildTaskItem(entry.value, entry.key)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, int index) {
    final conceptTitle = task['concept_title'] ?? task['title'] ?? 'Untitled';
    final topicName = task['topic_title'] ?? task['topic'] ?? '';
    final mastery = (task['mastery_level'] as num?)?.toDouble() ?? 0;
    final priority = (task['priority'] ?? 'medium').toString().toLowerCase();
    final minutes = task['estimated_minutes'] ?? task['minutes'] ?? 0;
    final taskId = task['id'] ?? task['concept_id'] ?? index;
    final isDone = _completedTasks.contains(taskId);

    final priorityColor = switch (priority) {
      'high' => context.colors.error,
      'review' => context.colors.success,
      _ => context.colors.warning,
    };
    final priorityLabel = switch (priority) {
      'high' => 'High',
      'review' => 'Review',
      _ => 'Medium',
    };

    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: EdgeInsets.only(bottom: index < _dailyTasks.length - 1 ? 8 : 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDone ? context.colors.success.withValues(alpha: 0.05) : context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDone ? context.colors.success.withValues(alpha: 0.2) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  if (_completedTasks.contains(taskId)) {
                    _completedTasks.remove(taskId);
                  } else {
                    _completedTasks.add(taskId);
                  }
                });
              },
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDone ? context.colors.success.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDone ? context.colors.success : context.colors.border,
                    width: 1.5,
                  ),
                ),
                child: isDone
                    ? Icon(Icons.check_rounded, size: 14, color: context.colors.success)
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conceptTitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDone ? context.colors.textMuted : context.colors.textPrimary,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (topicName.isNotEmpty) ...[
                    SizedBox(height: 2),
                    Text(
                      topicName,
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8),
            _MiniMasteryRing(mastery: mastery, color: priorityColor),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priorityLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                    ),
                  ),
                ),
                if (minutes > 0) ...[
                  SizedBox(height: 4),
                  Text(
                    '${minutes}m',
                    style: TextStyle(fontSize: 10, color: context.colors.textMuted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratePlan() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Generate Study Plan', Icons.auto_awesome_outlined),
            SizedBox(height: 14),
            if (_subjects.isNotEmpty) ...[
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _subjects.length,
                  separatorBuilder: (_, __) => SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final s = _subjects[i];
                    final slug = s['slug'] ?? '';
                    final title = s['title'] ?? s['name'] ?? slug;
                    final selected = slug == _selectedSubjectSlug;
                    return GestureDetector(
                      onTap: () => setState(() { _selectedSubjectSlug = slug; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary.withValues(alpha: 0.2) : context.colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppColors.primary.withValues(alpha: 0.4) : context.colors.border,
                          ),
                        ),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? AppColors.primary : context.colors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Minutes',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
                ),
                Text(
                  '${_dailyMinutes.round()} min',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: context.colors.surfaceHighest,
                thumbColor: AppColors.primary,
                overlayColor: context.colors.primaryGlow,
                trackHeight: 4,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _dailyMinutes,
                min: 30,
                max: 120,
                divisions: 6,
                onChanged: (v) => setState(() { _dailyMinutes = v; }),
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Duration',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _daysAhead,
                      dropdownColor: context.colors.surfaceHighest,
                      style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
                      isDense: true,
                      items: [
                        DropdownMenuItem(value: 7, child: Text('7 days')),
                        DropdownMenuItem(value: 14, child: Text('14 days')),
                        DropdownMenuItem(value: 21, child: Text('21 days')),
                        DropdownMenuItem(value: 28, child: Text('28 days')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() { _daysAhead = v; });
                      },
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _generating ? null : _generatePlan,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: _generating
                        ? LinearGradient(
                            colors: [AppColors.primary.withValues(alpha: 0.4), AppColors.primaryMuted.withValues(alpha: 0.4)],
                          )
                        : LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _generating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textOnPrimary),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome_outlined, color: AppColors.textOnPrimary, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Generate Plan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textOnPrimary,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanOverview() {
    final plans = _overview['plans'] as List? ?? [];
    final stats = _overview['stats'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Plan Overview', Icons.bar_chart_rounded),
            SizedBox(height: 14),
            _buildOverviewStats(stats),
            if (plans.isNotEmpty) ...[
              SizedBox(height: 16),
              ...plans.asMap().entries.map((entry) => _buildPlanCard(entry.value, entry.key, plans.length)),
            ] else
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No plans yet. Generate one above!',
                    style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStats(Map<String, dynamic> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final totalPlans = stats['total_plans'] ?? 0;
    final activePlans = stats['active_plans'] ?? 0;
    final completedPlans = stats['completed_plans'] ?? 0;
    final totalItems = stats['total_items'] ?? 0;

    return Row(
      children: [
        _buildStatChip('$totalPlans', 'Plans', context.colors.info),
        SizedBox(width: 8),
        _buildStatChip('$activePlans', 'Active', context.colors.warning),
        SizedBox(width: 8),
        _buildStatChip('$completedPlans', 'Done', context.colors.success),
        SizedBox(width: 8),
        _buildStatChip('$totalItems', 'Items', context.colors.lavender),
      ],
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, int index, int total) {
    final title = plan['title'] ?? 'Untitled Plan';
    final subject = plan['subject_title'] ?? plan['subject_slug'] ?? '';
    final completed = plan['completed_items'] ?? 0;
    final totalItems = plan['total_items'] ?? plan['items_count'] ?? 1;
    final status = (plan['status'] ?? 'active').toString().toLowerCase();
    final progress = totalItems > 0 ? completed / totalItems : 0.0;
    final progressPercent = (progress * 100).round();

    final statusColor = switch (status) {
      'completed' => context.colors.success,
      'active' => context.colors.info,
      'paused' => context.colors.warning,
      _ => context.colors.textMuted,
    };

    return GestureDetector(
      onTap: () => _showPlanDetail(plan),
      child: Container(
        margin: EdgeInsets.only(bottom: index < total - 1 ? 8 : 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subject.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(subject, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: context.colors.surfaceHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 6,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '$completed/$totalItems ($progressPercent%)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlanDetail(Map<String, dynamic> plan) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlanDetailSheet(plan: plan),
    );
  }
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
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanDetailSheet extends StatefulWidget {
  final Map<String, dynamic> plan;
  const _PlanDetailSheet({required this.plan});

  @override
  State<_PlanDetailSheet> createState() => _PlanDetailSheetState();
}

class _PlanDetailSheetState extends State<_PlanDetailSheet> {
  final StemService _stemService = StemService();
  Map<String, dynamic>? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final planId = widget.plan['id'];
    if (planId == null) {
      if (mounted) setState(() { _loading = false; });
      return;
    }
    try {
      final data = await _stemService.getStudyPlanDetail(planId);
      if (mounted) setState(() { _detail = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.plan['title'] ?? 'Plan Details';
    final items = _detail?['items'] as List? ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              SizedBox(height: 16),
              Center(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                ),
              ),
              SizedBox(height: 20),
              if (_loading)
                Center(child: CircularProgressIndicator(color: AppColors.primary))
              else if (items.isEmpty)
                Center(
                  child: Text('No items in this plan', style: TextStyle(color: context.colors.textMuted)),
                )
              else
                ...items.asMap().entries.map((entry) => _buildDetailItem(entry.value, entry.key, items.length)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(Map<String, dynamic> item, int index, int total) {
    final conceptTitle = item['concept_title'] ?? item['title'] ?? 'Untitled';
    final completed = item['is_completed'] == true || item['completed'] == true;
    final scheduledDate = item['scheduled_date'] ?? item['date'] ?? '';
    final minutes = item['estimated_minutes'] ?? item['minutes'] ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: index < total - 1 ? 8 : 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed ? context.colors.success.withValues(alpha: 0.05) : context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: completed ? context.colors.success.withValues(alpha: 0.2) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: completed ? context.colors.success.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: completed ? context.colors.success : context.colors.border,
                width: 1.5,
              ),
            ),
            child: completed
                ? Icon(Icons.check_rounded, size: 14, color: context.colors.success)
                : Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.colors.textMuted),
                    ),
                  ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conceptTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: completed ? context.colors.textMuted : context.colors.textPrimary,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (scheduledDate.toString().isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    '${scheduledDate.toString().length > 10 ? scheduledDate.toString().substring(0, 10) : scheduledDate}',
                    style: TextStyle(fontSize: 11, color: context.colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (minutes > 0)
            Text('${minutes}m', style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
        ],
      ),
    );
  }
}
