import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../core/theme/theme_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _analytics;
  List<dynamic> _users = [];
  List<dynamic> _courses = [];
  int _selectedTab = 0;

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
      final results = await Future.wait([
        _api.get('/admin/institutional-analytics'),
        _api.get('/admin/users'),
        _api.get('/admin/courses'),
      ]);
      if (!mounted) return;
      setState(() {
        if (results[0].statusCode == 200) {
          _analytics = jsonDecode(results[0].body);
        }
        if (results[1].statusCode == 200) {
          _users = jsonDecode(results[1].body);
        }
        if (results[2].statusCode == 200) {
          _courses = jsonDecode(results[2].body);
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load admin data: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 70,
                        floating: true,
                        backgroundColor: context.colors.surface,
                        title: Semantics(
                          header: true,
                          child: Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        actions: [
                          IconButton(
                            icon: Icon(Icons.refresh_rounded, color: context.colors.textSecondary),
                            tooltip: 'Refresh data',
                            onPressed: _loadData,
                          ),
                        ],
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(48),
                          child: _buildTabBar(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _selectedTab == 0
                            ? _buildOverviewTab()
                            : _selectedTab == 1
                                ? _buildUsersTab()
                                : _selectedTab == 99
                                    ? SizedBox()
                                    : _buildCoursesTab(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
        children: [
          _buildTab('Overview', 0),
          _buildTab('Users (${_users.length})', 1),
          _buildTab('Courses (${_courses.length})', 2),
          _buildTab('Syllabus', 99),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (index == 99) {
          context.go('/admin/syllabus');
          return;
        }
        setState(() => _selectedTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : context.colors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final overview = _analytics?['overview'] ?? {};
    final engagement = _analytics?['engagement'] ?? {};
    final academics = _analytics?['academics'] ?? {};

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('SYSTEM OVERVIEW'),
          SizedBox(height: 8),
          _buildStatsGrid([
            _StatItem('Total Users', '${overview['total_users'] ?? 0}', Icons.people_rounded, AppColors.primary),
            _StatItem('Students', '${overview['total_students'] ?? 0}', Icons.school_rounded, context.colors.success),
            _StatItem('Lecturers', '${overview['total_lecturers'] ?? 0}', Icons.badge_rounded, context.colors.warning),
            _StatItem('Courses', '${overview['total_courses'] ?? 0}', Icons.menu_book_rounded, context.colors.accent),
            _StatItem('Enrollments', '${overview['total_enrollments'] ?? 0}', Icons.assignment_rounded, context.colors.info),
            _StatItem('Submissions', '${overview['total_submissions'] ?? 0}', Icons.quiz_rounded, context.colors.lavender),
          ]),
          SizedBox(height: 24),
          const _SectionHeader('ENGAGEMENT (30 DAYS)'),
          SizedBox(height: 8),
          _buildStatsGrid([
            _StatItem('New Users', '${engagement['new_users_30d'] ?? 0}', Icons.person_add_rounded, context.colors.success),
            _StatItem('Active (7d)', '${engagement['active_users_7d'] ?? 0}', Icons.access_time_rounded, AppColors.primary),
            _StatItem('Recent Submissions', '${engagement['recent_submissions'] ?? 0}', Icons.upload_rounded, context.colors.info),
            _StatItem('Avg Score', '${engagement['avg_score'] ?? 0}%', Icons.star_rounded, context.colors.warning),
          ]),
          SizedBox(height: 24),
          const _SectionHeader('ACADEMIC PERFORMANCE'),
          SizedBox(height: 8),
          _buildStatCard(
            'Avg Enrollment Progress',
            '${academics['avg_enrollment_progress'] ?? 0}%',
            Icons.trending_up_rounded,
            AppColors.primary,
          ),
          SizedBox(height: 8),
          _buildStatCard(
            'Course Completion Rate',
            '${academics['completion_rate'] ?? 0}%',
            Icons.check_circle_rounded,
            context.colors.success,
          ),
          if ((academics['department_breakdown'] as List?)?.isNotEmpty == true) ...[
            SizedBox(height: 16),
            const _SectionHeader('DEPARTMENT BREAKDOWN'),
            SizedBox(height: 8),
            _buildDepartmentBreakdown(academics['department_breakdown']),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_users.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('No users found', style: TextStyle(color: context.colors.textMuted)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (ctx, i) => _buildUserCard(_users[i]),
    );
  }

  Widget _buildCoursesTab() {
    if (_courses.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('No courses found', style: TextStyle(color: context.colors.textMuted)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _courses.length,
      itemBuilder: (ctx, i) => _buildCourseCard(_courses[i]),
    );
  }

  Widget _buildStatsGrid(List<_StatItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.8,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Semantics(
          label: '${item.label}: ${item.value}',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 18, color: item.color),
                SizedBox(height: 6),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: item.color,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentBreakdown(List<dynamic> departments) {
    final total = departments.fold<int>(0, (sum, d) => sum + ((d['count'] as int?) ?? 0));
    final colors = [
      AppColors.primary, context.colors.success, context.colors.warning,
      context.colors.info, context.colors.lavender, context.colors.accent,
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: List.generate(departments.length, (i) {
                        final pct = total > 0
                            ? ((departments[i]['count'] as int) / total)
                            : 0.0;
                        return Expanded(
                          flex: (pct * 1000).toInt().clamp(1, 1000),
                          child: Container(color: colors[i % colors.length]),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: List.generate(departments.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${departments[i]['department']} (${departments[i]['count']})',
                    style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role = (user['role'] ?? 'student').toString();
    final isActive = user['is_active'] == true;
    final roleColor = role == 'admin'
        ? context.colors.error
        : role == 'lecturer'
            ? context.colors.warning
            : AppColors.primary;

    return Semantics(
      label: 'User: ${user['full_name']}, role: $role',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  (user['full_name'] ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['full_name'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    user['email'] ?? '',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive ? context.colors.success : context.colors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive ? context.colors.success : context.colors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final isActive = course['is_active'] == true;
    return Semantics(
      label: 'Course: ${course['title']}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.primaryGlow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.menu_book_rounded, size: 20, color: AppColors.primary),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course['code'] ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMuted,
                    ),
                  ),
                  Text(
                    course['title'] ?? 'Untitled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? context.colors.success : context.colors.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: context.colors.error),
            SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textMuted),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: Icon(Icons.refresh_rounded, size: 16),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: context.colors.textMuted,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _StatItem(this.label, this.value, this.icon, this.color);
}
