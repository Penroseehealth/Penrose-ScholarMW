import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class LecturerCentre extends StatefulWidget {
  const LecturerCentre({super.key});

  @override
  State<LecturerCentre> createState() => _LecturerCentreState();
}

class _LecturerCentreState extends State<LecturerCentre>
    with SingleTickerProviderStateMixin {
  final CourseService _courseService = CourseService();
  final AiService _aiService = AiService();
  bool _loading = true;
  String _greeting = '';
  String _searchQuery = '';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<_StemSubject> _stemSubjects = [
    _StemSubject('Computer Science', 'CS101', Icons.code_rounded,
        const Color(0xFF8B5CF6), 0.72, 48, 'CS'),
    _StemSubject('Mathematics', 'MATH101', Icons.functions_rounded,
        const Color(0xFF3B82F6), 0.65, 52, 'MATH'),
    _StemSubject('Physics', 'PHY101', Icons.scatter_plot_rounded,
        const Color(0xFF10B981), 0.58, 35, 'PHY'),
    _StemSubject('Chemistry', 'CHEM101', Icons.science_rounded,
        const Color(0xFFF59E0B), 0.45, 41, 'CHEM'),
    _StemSubject('Biology', 'BIO101', Icons.biotech_rounded,
        const Color(0xFFEF4444), 0.38, 39, 'BIO'),
    _StemSubject('Engineering', 'ENG101', Icons.engineering_rounded,
        const Color(0xFF06B6D4), 0.52, 30, 'ENG'),
  ];

  final ScrollController _subjectScrollCtrl = ScrollController();

  final List<_ActivityItem> _recentActivity = [
    _ActivityItem(
        Icons.quiz_rounded,
        'Created assessment for CS101',
        'Data Structures Quiz',
        '2 hours ago',
        const Color(0xFF8B5CF6)),
    _ActivityItem(
        Icons.edit_note_rounded,
        'Updated lesson plan for MATH101',
        'Calculus and Integration',
        '5 hours ago',
        const Color(0xFF3B82F6)),
    _ActivityItem(
        Icons.grading_rounded,
        'Reviewed student submissions',
        'Physics Lab Report – Week 4',
        '1 day ago',
        const Color(0xFF10B981)),
    _ActivityItem(
        Icons.auto_awesome_rounded,
        'Generated quiz for CHEM101',
        'Organic Chemistry Basics',
        '1 day ago',
        const Color(0xFFF59E0B)),
    _ActivityItem(
        Icons.forum_rounded,
        'New discussion in CS101 forum',
        'Topic: Time Complexity Analysis',
        '2 days ago',
        const Color(0xFF8B5CF6)),
  ];

  final List<_ScheduleItem> _upcomingSchedule = [
    _ScheduleItem(20, 'MAY', 'CS101 Lecture', 'Data Structures – Arrays',
        '10:00 AM – 11:30 AM', 'Lecture', const Color(0xFF8B5CF6)),
    _ScheduleItem(22, 'MAY', 'MATH101 Tutorial', 'Problem Solving Session',
        '2:00 PM – 3:30 PM', 'Tutorial', const Color(0xFF3B82F6)),
    _ScheduleItem(24, 'MAY', 'CHEM101 Lab', 'Organic Compounds Lab',
        '9:00 AM – 12:00 PM', 'Lab', const Color(0xFFF59E0B)),
    _ScheduleItem(26, 'MAY', 'CS101 Assignment 4', 'Due: Data Structures',
        '11:59 PM', 'Deadline', const Color(0xFFEF4444)),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _setGreeting();
    _loadData();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    _greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
  }

  Future<void> _loadData() async {
    await _courseService.listCourses();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _subjectScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1100;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            if (isWide) _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildTopHeader(),
                  Expanded(
                    child: _loading
                        ? _buildSkeletonLoader()
                        : SingleChildScrollView(
                            padding: EdgeInsets.symmetric(
                              horizontal: isWide ? 32 : 16,
                              vertical: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStemSubjectsSection(isWide),
                                const SizedBox(height: 32),
                                _buildAnalyticsOverview(isWide),
                                const SizedBox(height: 32),
                                _buildProductivityArea(isWide),
                                const SizedBox(height: 32),
                                _buildAiAssistantSection(isWide),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarLogo(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildSidebarItem(Icons.dashboard_rounded, 'Dashboard', true,
                    onTap: () {}),
                _buildSidebarItem(Icons.menu_book_rounded, 'My Courses', false,
                    onTap: () => context.go('/vault')),
                _buildSidebarItem(Icons.auto_awesome_rounded, 'AI Assistant', false,
                    onTap: () => context.go('/ai-tutor')),
                _buildSidebarItem(Icons.school_rounded, 'My Learning', false,
                    onTap: () => context.go('/stem')),
                _buildSidebarItem(Icons.assignment_rounded, 'Assignments', false,
                    onTap: () => context.go('/assignments')),
                _buildSidebarItem(Icons.quiz_rounded, 'Assessments', false,
                    onTap: () => context.go('/assessment-studio')),
                _buildSidebarItem(Icons.bar_chart_rounded, 'Reports', false,
                    onTap: () => context.go('/analytics')),
                _buildSidebarItem(Icons.science_rounded, 'Research', false,
                    onTap: () => context.go('/research')),
                _buildSidebarItem(Icons.folder_rounded, 'Resources', false,
                    onTap: () => context.go('/vault')),
                _buildSidebarItem(Icons.calendar_month_rounded, 'Calendar', false,
                    onTap: () => context.go('/calendar')),
                _buildSidebarItem(Icons.chat_bubble_outline_rounded, 'Messages', false,
                    onTap: () => context.go('/messages')),
                _buildSidebarItem(Icons.settings_rounded, 'Settings', false,
                    onTap: () => context.go('/settings')),
              ],
            ),
          ),
          _buildSidebarProfile(),
        ],
      ),
    );
  }

  Widget _buildSidebarLogo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Penrose',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'ScholarMW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, bool isActive,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isActive ? AppColors.primaryGlow : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isActive ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color:
                          isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarProfile() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('GP',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dr. Grace Mphatso',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Lecturer',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lecturer Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your STEM subjects, students, and teaching activities.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          _buildHeaderAction(
              Icons.search_rounded, 'Search', () => context.go('/search')),
          const SizedBox(width: 8),
          _buildHeaderAction(
              Icons.notifications_outlined, 'Notifications', () {
            final count = 3;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$count unread notifications'),
                duration: const Duration(seconds: 2),
              ),
            );
          }, badge: 3),
          const SizedBox(width: 8),
          _buildHeaderAction(
              Icons.dark_mode_outlined, 'Theme', () {}),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Scaffold.of(context).openEndDrawer(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, String tooltip, VoidCallback onTap,
      {int? badge}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 19, color: AppColors.textSecondary),
            ),
            if (badge != null)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStemSubjectsSection(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'My STEM Subjects',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Row(
              children: [
                _buildCarouselArrow(Icons.arrow_back_ios_new_rounded, () {
                  _subjectScrollCtrl.animateTo(
                    _subjectScrollCtrl.offset - 320,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }),
                const SizedBox(width: 8),
                _buildCarouselArrow(Icons.arrow_forward_ios_rounded, () {
                  _subjectScrollCtrl.animateTo(
                    _subjectScrollCtrl.offset + 320,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            controller: _subjectScrollCtrl,
            scrollDirection: Axis.horizontal,
            itemCount: _stemSubjects.length,
            itemBuilder: (ctx, i) => _buildSubjectCard(_stemSubjects[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildCarouselArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildSubjectCard(_StemSubject subject) {
    return Semantics(
      label: '${subject.name} ${subject.code}',
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 260,
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: subject.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(subject.icon, color: subject.color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject.code,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subject.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.people_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    '${subject.students} students',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    '${(subject.progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: subject.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: subject.progress,
                  backgroundColor: AppColors.surfaceHighest,
                  color: subject.color,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: subject.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open Subject',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: subject.color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: subject.color),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsOverview(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.success, Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.0 : 1.6,
          children: [
            _buildAnalyticCard(
                '12', 'Active Subjects', Icons.menu_book_rounded, AppColors.primary,
                trend: '+2 this semester'),
            _buildAnalyticCard('245', 'Students Taught', Icons.people_rounded,
                AppColors.success,
                trend: '+18 this month'),
            _buildAnalyticCard(
                '18', 'Assessments Created', Icons.quiz_rounded, AppColors.warning,
                trend: '5 pending review'),
            _buildAnalyticCard(
                '82%', 'Avg Engagement', Icons.trending_up_rounded, AppColors.info,
                trend: '+4% vs last month'),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticCard(
      String value, String label, IconData icon, Color color,
      {String? trend}) {
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: color),
                ),
                const Spacer(),
                if (trend != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trend,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductivityArea(bool isWide) {
    return isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _buildRecentActivity()),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: _buildUpcomingSchedule()),
            ],
          )
        : Column(
            children: [
              _buildRecentActivity(),
              const SizedBox(height: 20),
              _buildUpcomingSchedule(),
            ],
          );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'View All →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_recentActivity.map((a) => _buildActivityItem(a))),
        ],
      ),
    );
  }

  Widget _buildActivityItem(_ActivityItem activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(activity.icon, size: 18, color: activity.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            activity.time,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSchedule() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppColors.success),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Upcoming Schedule',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/calendar'),
                child: const Text(
                  'View Full Calendar →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_upcomingSchedule.map((s) => _buildScheduleItem(s))),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(_ScheduleItem event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${event.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: event.color,
                  ),
                ),
                Text(
                  event.month,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: event.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                event.time,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: event.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  event.category,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: event.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantSection(bool isWide) {
    final actions = [
      _AiAction(Icons.menu_book_rounded, 'Generate Lesson Plan',
          'Create structured AI-powered lesson plans', AppColors.primary),
      _AiAction(Icons.quiz_rounded, 'Create Assessment',
          'Generate assignments, tests, and evaluations', AppColors.secondary),
      _AiAction(Icons.auto_awesome_rounded, 'Generate Quiz',
          'Create adaptive quizzes and practice questions', AppColors.accent),
      _AiAction(Icons.lightbulb_rounded, 'Content Suggestions',
          'Get intelligent material recommendations', AppColors.success),
      _AiAction(Icons.edit_note_rounded, 'Generate Lecture Notes',
          'AI-powered notes from your curriculum', AppColors.info),
      _AiAction(Icons.science_rounded, 'Lab Guide',
          'Create practical and laboratory guides', AppColors.warning),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rose AI Teaching Assistant',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Let AI help you create better STEM learning experiences.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: isWide ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.2 : 1.8,
          children: actions.map((a) => _buildAiActionCard(a)).toList(),
        ),
      ],
    );
  }

  Widget _buildAiActionCard(_AiAction action) {
    return Semantics(
      button: true,
      label: action.title,
      child: GestureDetector(
        onTap: () => context.go('/ai-tutor'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, size: 22, color: action.color),
              ),
              const Spacer(),
              Text(
                action.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                action.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonBar(200, 22),
          const SizedBox(height: 8),
          _buildSkeletonBar(350, 12),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, __) => _buildSkeletonCard(260, 200),
            ),
          ),
          const SizedBox(height: 32),
          _buildSkeletonBar(120, 22),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: List.generate(4, (_) => _buildSkeletonCard(0, 0)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBar(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildSkeletonCard(double w, double h) {
    return Container(
      width: w > 0 ? w : null,
      height: h > 0 ? h : null,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

class _StemSubject {
  final String name;
  final String code;
  final IconData icon;
  final Color color;
  final double progress;
  final int students;
  final String prefix;
  _StemSubject(this.name, this.code, this.icon, this.color, this.progress,
      this.students, this.prefix);
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;
  _ActivityItem(this.icon, this.title, this.subtitle, this.time, this.color);
}

class _ScheduleItem {
  final int day;
  final String month;
  final String title;
  final String subtitle;
  final String time;
  final String category;
  final Color color;
  _ScheduleItem(this.day, this.month, this.title, this.subtitle, this.time,
      this.category, this.color);
}

class _AiAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  _AiAction(this.icon, this.title, this.subtitle, this.color);
}
