import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/error_state.dart';

class StemAnalyticsScreen extends StatefulWidget {
  const StemAnalyticsScreen({super.key});

  @override
  State<StemAnalyticsScreen> createState() => _StemAnalyticsScreenState();
}

class _StemAnalyticsScreenState extends State<StemAnalyticsScreen> {
  final StemService _stemService = StemService();

  Map<String, dynamic> _summary = {};
  List<dynamic> _subjects = [];
  List<dynamic> _weakest = [];
  List<dynamic> _heatmap = [];
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
        _stemService.getStudySummary(),
        _stemService.getSubjectComparison(),
        _stemService.getWeakestConcepts(),
        _stemService.getHeatmap(),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>;
          _subjects = results[1] as List<dynamic>;
          _weakest = results[2] as List<dynamic>;
          _heatmap = results[3] as List<dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 90,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'STEM Analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
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
            SliverToBoxAdapter(
              child: ErrorState(
                message: 'Failed to load analytics',
                details: _error,
                onRetry: _loadData,
              ),
            )
          else if (_loading)
            SliverToBoxAdapter(child: ShimmerLoading.list(count: 3))
          else ...[
            SliverToBoxAdapter(child: _buildSummaryGrid()),
            SliverToBoxAdapter(child: _buildWeeklyActivity()),
            SliverToBoxAdapter(child: _buildSubjectProgress()),
            SliverToBoxAdapter(child: _buildWeakestConcepts()),
            SliverToBoxAdapter(child: _buildHeatmap()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final totalHours = ((_summary['total_minutes'] ?? 0) as num) / 60.0;
    final streak = _summary['current_streak'] ?? 0;
    final mastered = _subjects.fold<int>(0, (sum, s) => sum + ((s['concepts_mastered'] ?? 0) as int));
    final avgMastery = _subjects.isEmpty
        ? 0.0
        : _subjects.fold<double>(0, (sum, s) => sum + ((s['mastery_avg'] ?? 0) as double)) / _subjects.length;

    final cards = [
      _StatData('Total Study Hours', totalHours.toStringAsFixed(1), Icons.schedule_rounded, AppColors.primary),
      _StatData('Current Streak', '$streak days', Icons.local_fire_department_rounded, AppColors.warning),
      _StatData('Concepts Mastered', '$mastered', Icons.check_circle_rounded, AppColors.success),
      _StatData('Average Mastery', '${(avgMastery * 100).round()}%', Icons.insights_rounded, AppColors.accent),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
        ),
        itemCount: 4,
        itemBuilder: (context, i) {
          final c = cards[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(c.icon, size: 20, color: c.color),
                const SizedBox(height: 8),
                Text(
                  c.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyActivity() {
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayMinutes = List.filled(7, 0);
    for (final day in _heatmap) {
      final dateStr = day['date'] as String? ?? '';
      if (dateStr.isEmpty) continue;
      try {
        final dt = DateTime.parse(dateStr);
        final idx = (dt.weekday - 1) % 7;
        dayMinutes[idx] += (day['study_minutes'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    final maxMin = dayMinutes.reduce(max).toDouble();
    final hasData = maxMin > 0;

    return _section(
      title: 'Weekly Activity',
      icon: Icons.bar_chart_rounded,
      child: Column(
        children:         hasData ? List.generate(7, (i) {
          final frac = dayMinutes[i] / maxMin;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    dayLabels[i],
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                ),
                Expanded(
                  child: FractionallySizedBox(
                    widthFactor: frac.clamp(0.05, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${dayMinutes[i]}m',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }) : [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No activity data yet. Start studying to see your weekly activity!', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectProgress() {
    if (_subjects.isEmpty) return const SizedBox.shrink();
    return _section(
      title: 'Subject Progress',
      icon: Icons.pie_chart_rounded,
      child: Column(
        children: _subjects.map((s) {
          final mastery = ((s['mastery_avg'] ?? 0) as double).clamp(0.0, 1.0);
          final masteredCount = s['concepts_mastered'] ?? 0;
          final totalCount = s['concepts_total'] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        s['subject_title'] ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$masteredCount / $totalCount',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: mastery,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceHighest,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeakestConcepts() {
    if (_weakest.isEmpty) return const SizedBox.shrink();
    return _section(
      title: 'Weakest Concepts',
      icon: Icons.warning_amber_rounded,
      child: Column(
        children: _weakest.map((c) {
          final mastery = ((c['mastery_level'] ?? 0) as num) * 100;
          final Color badgeColor;
          if (mastery < 30) {
            badgeColor = AppColors.error;
          } else if (mastery < 60) {
            badgeColor = AppColors.warning;
          } else {
            badgeColor = AppColors.success;
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c['subject_slug'] ?? '',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${mastery.round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeatmap() {
    if (_heatmap.isEmpty) return const SizedBox.shrink();
    return _section(
      title: 'Study Heatmap',
      icon: Icons.grid_view_rounded,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: _heatmap.map((h) {
          final minutes = (h['study_minutes'] ?? 0) as int;
          final Color cellColor;
          if (minutes == 0) {
            cellColor = AppColors.surfaceHighest;
          } else if (minutes < 15) {
            cellColor = AppColors.primaryDark.withValues(alpha: 0.4);
          } else if (minutes < 30) {
            cellColor = AppColors.primaryDark.withValues(alpha: 0.65);
          } else if (minutes < 60) {
            cellColor = AppColors.primary;
          } else {
            cellColor = AppColors.primaryLight;
          }
          return Tooltip(
            message: '${h['date'] ?? ''}\n$minutes min',
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: cellColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _section({required String title, required IconData icon, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        width: double.infinity,
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
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _StatData(this.label, this.value, this.icon, this.color);
}
