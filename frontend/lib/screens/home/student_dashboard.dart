import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/services.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final CourseService _courseService = CourseService();
  List<dynamic> _courses = [];
  List<dynamic> _notifications = [];
  bool _loading = true;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  static String _greetingFor(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final courses = await _courseService.listCourses();
      final notifs = await NotificationService().listNotifications();
      if (mounted) {
        setState(() {
          _courses = courses;
          _notifications = notifs;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final greeting = _greetingFor(DateTime.now().hour);
    final firstName = (auth.userName.isNotEmpty ? auth.userName : 'Scholar').split(' ').first;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          backgroundColor: context.colors.surface,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, greeting, firstName)),
              SliverToBoxAdapter(child: _buildQuickActions(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: _buildSectionTitle('My Courses'),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
                )
              else if (_courses.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState('No courses yet', 'Enroll in courses to begin'))
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.separated(
                    itemCount: _courses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildCourseCard(_courses[index]),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: _buildSectionTitle('Recent Activity'),
                ),
              ),
              if (_notifications.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: _buildEmptyState('All caught up!', 'No new notifications'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  sliver: SliverList.separated(
                    itemCount: _notifications.length.clamp(0, 5),
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _buildActivityCard(_notifications[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String greeting, String firstName) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $firstName',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            _buildHamburgerButton(context),
          ],
        ),
      );

  Widget _buildHamburgerButton(BuildContext context) => GestureDetector(
        onTap: () => Scaffold.of(context).openEndDrawer(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: Icon(
            Icons.menu_rounded,
            color: context.colors.textSecondary,
            size: 20,
          ),
        ),
      );

  Widget _buildQuickActions(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Row(
          children: [
            _buildActionCard(
              context,
              icon: Icons.psychology_rounded,
              label: 'Penrose Learning Assistant',
              gradient: [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
              onTap: () => context.go('/ai-tutor'),
            ),
            const SizedBox(width: 10),
            _buildActionCard(
              context,
              icon: Icons.translate_rounded,
              label: 'Language Hubs',
              gradient: [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
              onTap: () => context.go('/languages'),
            ),
            const SizedBox(width: 10),
            _buildActionCard(
              context,
              icon: Icons.quiz_rounded,
              label: 'Tasks',
              gradient: [const Color(0xFF059669), const Color(0xFF047857)],
              onTap: () => context.go('/assignments'),
            ),
            const SizedBox(width: 10),
            _buildActionCard(
              context,
              icon: Icons.insights_rounded,
              label: 'Grades',
              gradient: [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
              onTap: () => context.go('/grades'),
            ),
            const SizedBox(width: 10),
            _buildActionCard(
              context,
              icon: Icons.science_rounded,
              label: 'STEM Hub',
              gradient: [const Color(0xFF22C55E), const Color(0xFF16A34A)],
              onTap: () => context.go('/stem'),
            ),
          ],
        ),
      );

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: gradient[0].withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      );

  Widget _buildCourseCard(dynamic course) {
    final progress = ((course['progress'] ?? 0.0) as num).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: context.colors.primaryGlow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (course['title'] ?? '') as String,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${course['code'] ?? ''} · ${course['level'] ?? ''}',
                  style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                ),
                if (progress > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor: context.colors.surfaceHighest,
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${progress.toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 20),
        ],
      ),
    );
  }

  Widget _buildActivityCard(dynamic notif) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.infoMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.info_outline_rounded, size: 18, color: context.colors.info),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (notif['title'] ?? '') as String,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (notif['message'] ?? '') as String,
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildEmptyState(String title, String subtitle) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 44, color: context.colors.textMuted.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
              ],
            ),
          ),
        ),
      );
}
