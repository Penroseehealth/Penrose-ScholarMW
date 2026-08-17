import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../providers/auth_provider.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  final ApiService _api = ApiService();
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final isLecturer = auth.userRole == 'lecturer';
      final endpoint = isLecturer
          ? '/api/v1/analytics/lecturer/overview'
          : '/api/v1/analytics/student/dashboard';
      final response = await _api.get(endpoint);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _data = body;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load analytics data';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLecturer = auth.userRole == 'lecturer';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            isLecturer
                                ? 'Lecturer Analytics'
                                : 'Learning Analytics',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLecturer
                                ? 'Class performance & insights'
                                : 'Your academic intelligence',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_data == null || (_data! as Map).isEmpty) {
      return _buildEmptyState();
    }

    final auth = context.read<AuthProvider>();
    final isLecturer = auth.userRole == 'lecturer';

    return isLecturer ? _buildLecturerView() : _buildStudentView();
  }

  Widget _buildStudentView() {
    final overallProgress =
        (_data!['overall_progress'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> courses = _data!['courses'] ?? [];
    final List<dynamic> weakAreas = _data!['weak_areas'] ?? [];
    final String recommendation = _data!['recommendation'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Overall Progress'),
        const SizedBox(height: 8),
        _buildOverallProgress(overallProgress),
        const SizedBox(height: 20),
        _buildSectionHeader('Course Performance'),
        const SizedBox(height: 8),
        if (courses.isEmpty)
          _buildEmptyCard('No course data yet')
        else
          ...courses.map((c) => _buildCoursePerformanceCard(c)),
        const SizedBox(height: 20),
        _buildSectionHeader('AI Identified Weak Areas'),
        const SizedBox(height: 8),
        if (weakAreas.isEmpty)
          _buildEmptyCard('No weak areas identified')
        else
          ...weakAreas.map((w) => _buildWeakAreaChip(w)),
        const SizedBox(height: 20),
        _buildSectionHeader('Recommended Action'),
        const SizedBox(height: 8),
        _buildRecommendationCard(recommendation),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start AI Revision Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLecturerView() {
    final classAverage = (_data!['class_average'] as num?)?.toDouble() ?? 0.0;
    final attendanceRate =
        (_data!['attendance_rate'] as num?)?.toDouble() ?? 0.0;
    final assignmentCompletion =
        (_data!['assignment_completion'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> difficultTopics = _data!['difficult_topics'] ?? [];
    final List<dynamic> studentsNeedingSupport =
        _data!['students_requiring_support'] ?? [];
    final String aiInsights = _data!['ai_insights'] ?? '';
    final List<dynamic> engagementTrends = _data!['engagement_trends'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Class Statistics'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            final stats = [
              _buildStatCard(
                label: 'Class Average',
                value: '${classAverage.toStringAsFixed(1)}%',
                color: AppColors.primary,
                icon: Icons.analytics_outlined,
              ),
              _buildStatCard(
                label: 'Attendance',
                value: '${attendanceRate.toStringAsFixed(1)}%',
                color: AppColors.info,
                icon: Icons.how_to_reg_outlined,
              ),
              _buildStatCard(
                label: 'Assignments',
                value: '${assignmentCompletion.toStringAsFixed(1)}%',
                color: AppColors.secondary,
                icon: Icons.assignment_turned_in_outlined,
              ),
            ];
            if (isWide) {
              return Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(child: stats[i]),
                    if (i < stats.length - 1) const SizedBox(width: 8),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  stats[i],
                  if (i < stats.length - 1) const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Difficult Topics'),
        const SizedBox(height: 8),
        if (difficultTopics.isEmpty)
          _buildEmptyCard('No difficult topics detected')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: difficultTopics.map((t) {
              final topic = t is String ? t : (t['topic'] ?? t.toString());
              return Chip(
                avatar: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 18),
                label: Text(topic, style: const TextStyle(fontSize: 13)),
                backgroundColor: AppColors.error.withOpacity(0.08),
                side: BorderSide(color: AppColors.error.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 20),
        _buildSectionHeader('Students Requiring Support'),
        const SizedBox(height: 8),
        if (studentsNeedingSupport.isEmpty)
          _buildEmptyCard('No students flagged')
        else
          ...studentsNeedingSupport.map((s) => _buildSupportStudentCard(s)),
        const SizedBox(height: 20),
        _buildSectionHeader('AI Generated Insights'),
        const SizedBox(height: 8),
        _buildInsightsCard(aiInsights),
        const SizedBox(height: 20),
        _buildSectionHeader('Engagement Trends'),
        const SizedBox(height: 8),
        if (engagementTrends.isEmpty)
          _buildEmptyCard('No engagement data yet')
        else
          _buildEngagementTrends(engagementTrends),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildOverallProgress(double progress) {
    final clamped = progress.clamp(0.0, 100.0);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progress',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${clamped.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: clamped / 100,
                minHeight: 10,
                backgroundColor: AppColors.divider,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursePerformanceCard(dynamic course) {
    final name = course['name'] ?? course['title'] ?? '';
    final score = (course['score'] as num?)?.toDouble() ?? 0.0;
    final trend = course['trend'] ?? 'neutral';

    IconData trendIcon;
    Color trendColor;
    if (trend == 'up') {
      trendIcon = Icons.trending_up;
      trendColor = AppColors.success;
    } else if (trend == 'down') {
      trendIcon = Icons.trending_down;
      trendColor = AppColors.error;
    } else {
      trendIcon = Icons.trending_flat;
      trendColor = AppColors.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.book_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Score: ${score.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(trendIcon, color: trendColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWeakAreaChip(dynamic weakArea) {
    final topic =
        weakArea is String ? weakArea : (weakArea['topic'] ?? weakArea.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Chip(
        avatar:
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
        label: Text(topic, style: const TextStyle(fontSize: 13)),
        backgroundColor: AppColors.warning.withOpacity(0.08),
        side: BorderSide(color: AppColors.warning.withOpacity(0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(String text) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.secondary.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline,
                color: AppColors.secondary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text.isNotEmpty
                    ? text
                    : 'No recommendation available yet. Complete more activities to receive AI suggestions.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportStudentCard(dynamic student) {
    final name = student['name'] ?? student['full_name'] ?? 'Unknown';
    final reason = student['reason'] ?? student['issue'] ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.error.withOpacity(0.1),
          child: const Icon(Icons.person_outline,
              color: AppColors.error, size: 20),
        ),
        title: Text(name,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: reason.isNotEmpty
            ? Text(reason,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis)
            : null,
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }

  Widget _buildInsightsCard(String insights) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.accent.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome,
                color: AppColors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                insights.isNotEmpty
                    ? insights
                    : 'AI is analysing class data. Insights will appear shortly.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementTrends(List<dynamic> trends) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < trends.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _engagementColor(i),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        trends[i]['label'] ?? trends[i]['period'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${(trends[i]['value'] ?? 0)}%',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _engagementColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.info,
      AppColors.success,
    ];
    return colors[index % colors.length];
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.analytics_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No analytics data',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('Data will appear once you start engaging with courses',
                style:
                    TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
