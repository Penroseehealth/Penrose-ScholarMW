import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  final List<Map<String, dynamic>> _mockSubjects = [
    {'name': 'Mathematics', 'mastery': 0.72, 'color': Colors.cyanAccent},
    {'name': 'Physics', 'mastery': 0.58, 'color': Colors.orangeAccent},
    {'name': 'Chemistry', 'mastery': 0.81, 'color': Colors.purpleAccent},
    {'name': 'Biology', 'mastery': 0.65, 'color': Colors.greenAccent},
    {'name': 'English', 'mastery': 0.88, 'color': Colors.pinkAccent},
  ];

  final List<Map<String, dynamic>> _weeklyData = [
    {'day': 'Mon', 'hours': 2.5},
    {'day': 'Tue', 'hours': 3.1},
    {'day': 'Wed', 'hours': 1.8},
    {'day': 'Thu', 'hours': 4.2},
    {'day': 'Fri', 'hours': 2.9},
    {'day': 'Sat', 'hours': 5.1},
    {'day': 'Sun', 'hours': 3.5},
  ];

  final int _totalQuizzes = 24;
  final int _quizzesPassed = 19;
  final int _totalStudyHours = 23;
  final int _studyStreak = 7;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 90,
            pinned: true,
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'My Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
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
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                _buildStatsRow(colors),
                const SizedBox(height: 16),
                _buildMasteryCard(colors),
                const SizedBox(height: 16),
                _buildWeeklyChart(colors),
                const SizedBox(height: 16),
                _buildQuizStats(colors),
                const SizedBox(height: 16),
                _buildStreakCard(colors),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(dynamic colors) {
    return Row(
      children: [
        _buildStatBox(Icons.access_time_rounded, '$_totalStudyHours hrs', 'Study Time', colors),
        const SizedBox(width: 8),
        _buildStatBox(Icons.quiz_rounded, '$_quizzesPassed/$_totalQuizzes', 'Quizzes Passed', colors),
        const SizedBox(width: 8),
        _buildStatBox(Icons.local_fire_department_rounded, '$_studyStreak days', 'Study Streak', colors),
      ],
    );
  }

  Widget _buildStatBox(IconData icon, String value, String label, dynamic colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: colors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteryCard(dynamic colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subject Mastery',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          const SizedBox(height: 14),
          ..._mockSubjects.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s['name'] as String, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        Text('${((s['mastery'] as double) * 100).toInt()}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s['color'] as Color)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: s['mastery'] as double,
                        backgroundColor: colors.surfaceHighest,
                        valueColor: AlwaysStoppedAnimation(s['color'] as Color),
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

  Widget _buildWeeklyChart(dynamic colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Study Hours',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary)),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 6,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < _weeklyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(_weeklyData[idx]['day'] as String,
                                style: TextStyle(fontSize: 10, color: colors.textMuted)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}h',
                        style: TextStyle(fontSize: 9, color: colors.textMuted),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _weeklyData.asMap().entries.map((entry) {
                  final hours = entry.value['hours'] as double;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: hours,
                        color: AppColors.primary,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStats(dynamic colors) {
    final passRate = _totalQuizzes > 0 ? _quizzesPassed / _totalQuizzes : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    value: _quizzesPassed.toDouble(),
                    color: Colors.greenAccent,
                    radius: 14,
                    title: '',
                  ),
                  PieChartSectionData(
                    value: (_totalQuizzes - _quizzesPassed).toDouble(),
                    color: colors.surfaceHighest,
                    radius: 14,
                    title: '',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quiz Performance',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                const SizedBox(height: 6),
                Text('${_quizzesPassed} passed out of $_totalQuizzes quizzes',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                const SizedBox(height: 4),
                Text('${(passRate * 100).toStringAsFixed(1)}% pass rate',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.greenAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(dynamic colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withAlpha(40), AppColors.primaryDark.withAlpha(40)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_studyStreak-Day Streak!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep studying daily to maintain your streak.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
