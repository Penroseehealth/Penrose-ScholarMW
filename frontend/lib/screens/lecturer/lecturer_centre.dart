import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../services/services.dart';
import '../home/app_drawer.dart';

class LecturerCentre extends StatefulWidget {
  const LecturerCentre({super.key});

  @override
  State<LecturerCentre> createState() => _LecturerCentreState();
}

class _LecturerCentreState extends State<LecturerCentre> with TickerProviderStateMixin {
  final CourseService _courseService = CourseService();
  bool _loading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final bool _isOffline = false;

  // Sidebar state
  bool _sidebarCollapsed = true;
  int _selectedNavIndex = 0;
  late AnimationController _sidebarAnimCtrl;
  late Animation<double> _sidebarWidthAnim;

  // Page fade
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Subject hover
  int _hoveredSubjectIndex = -1;

  final ScrollController _subjectScrollCtrl = ScrollController();

  final List<_StemSubject> _stemSubjects = [
    _StemSubject(
      'Computer Science',
      'CS101',
      Icons.code_rounded,
      const Color(0xFF8B5CF6),
      0.72,
      48,
      'cs',
    ),
    _StemSubject(
      'Mathematics',
      'MATH101',
      Icons.functions_rounded,
      const Color(0xFF3B82F6),
      0.65,
      52,
      'math',
    ),
    _StemSubject(
      'Physics',
      'PHY101',
      Icons.scatter_plot_rounded,
      const Color(0xFF10B981),
      0.58,
      35,
      'physics',
    ),
    _StemSubject(
      'Chemistry',
      'CHEM101',
      Icons.science_rounded,
      const Color(0xFFF59E0B),
      0.45,
      41,
      'chemistry',
    ),
    _StemSubject(
      'Biology',
      'BIO101',
      Icons.biotech_rounded,
      const Color(0xFFEF4444),
      0.38,
      39,
      'biology',
    ),
    _StemSubject(
      'Engineering',
      'ENG101',
      Icons.engineering_rounded,
      const Color(0xFF06B6D4),
      0.52,
      30,
      'engineering',
    ),
  ];

  final List<_ActivityItem> _recentActivity = [
    _ActivityItem(Icons.quiz_rounded, 'Created assessment for CS101', 'Data Structures Quiz', '2 hours ago',
        const Color(0xFF8B5CF6)),
    _ActivityItem(Icons.edit_note_rounded, 'Updated lesson plan for MATH101', 'Calculus and Integration', '5 hours ago',
        const Color(0xFF3B82F6)),
    _ActivityItem(Icons.grading_rounded, 'Reviewed student submissions', 'Physics Lab Report – Week 4', '1 day ago',
        const Color(0xFF10B981)),
    _ActivityItem(Icons.auto_awesome_rounded, 'Generated quiz for CHEM101', 'Organic Chemistry Basics', '1 day ago',
        const Color(0xFFF59E0B)),
    _ActivityItem(Icons.forum_rounded, 'New discussion in CS101 forum', 'Topic: Time Complexity Analysis', '2 days ago',
        const Color(0xFF8B5CF6)),
  ];

  final List<_ScheduleItem> _upcomingSchedule = [
    _ScheduleItem(20, 'MAY', 'CS101 Lecture', 'Data Structures – Arrays', '10:00 AM – 11:30 AM', 'Lecture',
        const Color(0xFF8B5CF6)),
    _ScheduleItem(22, 'MAY', 'MATH101 Tutorial', 'Problem Solving Session', '2:00 PM – 3:30 PM', 'Tutorial',
        const Color(0xFF3B82F6)),
    _ScheduleItem(
        24, 'MAY', 'CHEM101 Lab', 'Organic Compounds Lab', '9:00 AM – 12:00 PM', 'Lab', const Color(0xFFF59E0B)),
    _ScheduleItem(
        26, 'MAY', 'CS101 Assignment 4', 'Due: Data Structures', '11:59 PM', 'Deadline', const Color(0xFFEF4444)),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _sidebarAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _sidebarWidthAnim = Tween<double>(begin: 260, end: 68).animate(
      CurvedAnimation(parent: _sidebarAnimCtrl, curve: Curves.easeInOut),
    );

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _courseService.listCourses();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _sidebarAnimCtrl.dispose();
    _subjectScrollCtrl.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    if (_sidebarCollapsed) {
      _sidebarAnimCtrl.forward();
    } else {
      _sidebarAnimCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < AppBreakpoints.mobile;
    final isTablet = width >= AppBreakpoints.mobile && width < AppBreakpoints.desktop;
    final isDesktop = width >= AppBreakpoints.desktop;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: context.colors.background,
        endDrawer: const AppDrawer(),
        body: isMobile
            ? _buildMobileLayout()
            : Row(
                children: [
                  if (isDesktop) _buildAnimatedSidebar(),
                  if (isTablet) _buildTabletSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopHeader(isMobile, isTablet, isDesktop: isDesktop),
                        Expanded(child: _buildMainContent(isDesktop, isTablet)),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: isMobile ? _buildBottomNav() : null,
      ),
    );
  }

  // ───────────────────────── MOBILE LAYOUT ─────────────────────────

  Widget _buildMobileLayout() => Column(
        children: [
          _buildTopHeader(true, false),
          Expanded(child: _buildMainContent(false, false)),
        ],
      );

  // ───────────────────────── BOTTOM NAV (MOBILE) ─────────────────────────

  Widget _buildBottomNav() => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: NavigationBar(
          onDestinationSelected: (i) {},
          backgroundColor: context.colors.surface,
          elevation: 0,
          height: 64,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, size: 22),
              selectedIcon: Icon(Icons.dashboard_rounded, size: 22),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined, size: 22),
              selectedIcon: Icon(Icons.auto_awesome_rounded, size: 22),
              label: 'AI Assistant',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined, size: 22),
              selectedIcon: Icon(Icons.school_rounded, size: 22),
              label: 'My Learning',
            ),
            NavigationDestination(
              icon: Icon(Icons.science_outlined, size: 22),
              selectedIcon: Icon(Icons.science_rounded, size: 22),
              label: 'Research',
            ),
          ],
        ),
      );

  // ───────────────────────── TABLET SIDEBAR (COLLAPSED ICONS ONLY) ─────────────────

  Widget _buildTabletSidebar() => Container(
        width: 68,
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(right: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildSidebarLogoCompact(),
            const SizedBox(height: 12),
            _buildCollapseToggle(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _navItems.length,
                itemBuilder: (ctx, i) => _buildSidebarItemCompact(i),
              ),
            ),
            _buildSidebarProfileCompact(),
          ],
        ),
      );

  // ───────────────────────── ANIMATED DESKTOP SIDEBAR ─────────────────

  Widget _buildAnimatedSidebar() => AnimatedBuilder(
        animation: _sidebarWidthAnim,
        builder: (context, child) {
          final w = _sidebarWidthAnim.value;
          final isCollapsed = w < 120;
          return Container(
            width: w,
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(right: BorderSide(color: context.colors.border, width: 0.5)),
            ),
            child: Column(
              children: [
                if (isCollapsed) _buildSidebarLogoCompact() else _buildSidebarLogoFull(),
                const SizedBox(height: 4),
                _buildCollapseToggle(),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 12, vertical: 4),
                    itemCount: _navItems.length,
                    itemBuilder: (ctx, i) => isCollapsed ? _buildSidebarItemCompact(i) : _buildSidebarItemFull(i),
                  ),
                ),
                if (isCollapsed) _buildSidebarProfileCompact() else _buildSidebarProfileFull(),
              ],
            ),
          );
        },
      );

  // ───────────────────────── SIDEBAR LOGO ─────────────────

  Widget _buildSidebarLogoFull() => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Penrose',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                          letterSpacing: -0.3)),
                  Text('ScholarMW',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textMuted,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildSidebarLogoCompact() => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          ),
        ),
      );

  // ───────────────────────── SIDEBAR TOGGLE ─────────────────

  Widget _buildCollapseToggle() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _toggleSidebar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _sidebarCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                    size: 18,
                    color: context.colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  // ───────────────────────── SIDEBAR NAV ITEMS ─────────────────

  static final _navItems = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard', '/lecturer'),
    _NavItem(Icons.menu_book_rounded, 'My Courses', '/vault'),
    _NavItem(Icons.auto_awesome_rounded, 'AI Assistant', '/ai-tutor'),
    _NavItem(Icons.school_rounded, 'My Learning', '/stem'),
    _NavItem(Icons.assignment_rounded, 'Assignments', '/assignments'),
    _NavItem(Icons.quiz_rounded, 'Assessments', '/assessment-studio'),
    _NavItem(Icons.bar_chart_rounded, 'Reports', '/analytics'),
    _NavItem(Icons.science_rounded, 'Research', '/research'),
    _NavItem(Icons.folder_rounded, 'Resources', '/vault'),
    _NavItem(Icons.calendar_month_rounded, 'Calendar', '/calendar'),
    _NavItem(Icons.chat_bubble_outline_rounded, 'Messages', '/messages'),
    _NavItem(Icons.settings_rounded, 'Settings', '/settings'),
  ];

  Widget _buildSidebarItemFull(int index) {
    final item = _navItems[index];
    final isActive = index == _selectedNavIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isActive ? context.colors.primaryGlow : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _selectedNavIndex = index);
            context.go(item.route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(item.icon, size: 19, color: isActive ? AppColors.primary : context.colors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? AppColors.primary : context.colors.textSecondary,
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

  Widget _buildSidebarItemCompact(int index) {
    final item = _navItems[index];
    final isActive = index == _selectedNavIndex;
    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: isActive ? context.colors.primaryGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() => _selectedNavIndex = index);
              context.go(item.route);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Icon(item.icon, size: 20, color: isActive ? AppColors.primary : context.colors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── SIDEBAR PROFILE ─────────────────

  Widget _buildSidebarProfileFull() => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
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
                child: Text('GP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Dr. Grace Mphatso',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                  Text('Lecturer', style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textMuted, size: 20),
          ],
        ),
      );

  Widget _buildSidebarProfileCompact() => Tooltip(
        message: 'Dr. Grace Mphatso – Lecturer',
        waitDuration: const Duration(milliseconds: 500),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('GP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ),
        ),
      );

  // ───────────────────────── TOP HEADER ─────────────────

  Widget _buildTopHeader(bool isMobile, bool isTablet, {bool isDesktop = false}) => Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu_rounded, color: context.colors.textPrimary, size: 24),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lecturer Dashboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Manage your STEM subjects, students, and teaching activities.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMuted.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildHeaderAction(Icons.search_rounded, 'Search', () {}),
            const SizedBox(width: 8),
            _buildHeaderAction(Icons.notifications_outlined, 'Notifications', () {}, badge: 3),
            const SizedBox(width: 8),
            _buildHeaderAction(
              context.watch<ThemeProvider>().isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              'Theme',
              () => context.read<ThemeProvider>().toggleTheme(),
            ),
          ],
        ),
      );

  Widget _buildHeaderAction(IconData icon, String tooltip, VoidCallback onTap, {int? badge}) => Tooltip(
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
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(icon, size: 19, color: context.colors.textSecondary),
              ),
              if (badge != null)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.colors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  // ───────────────────────── MAIN CONTENT ─────────────────

  Widget _buildMainContent(bool isDesktop, bool isTablet) {
    if (_isOffline) return _buildOfflineState();
    if (_hasError) return _buildErrorState();
    if (_loading) return _buildSkeletonLoader();
    if (_stemSubjects.isEmpty) return _buildEmptyState();

    return SingleChildScrollView(
      padding: EdgeInsets.only(
          left: isDesktop ? 0 : (isTablet ? 20 : 16),
          right: isDesktop ? 32 : (isTablet ? 20 : 16),
          top: 20,
          bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStemSubjectsSection(),
          const SizedBox(height: 32),
          _buildLanguageHubsSection(),
          const SizedBox(height: 32),
          _buildAnalyticsOverview(isDesktop),
          const SizedBox(height: 32),
          _buildProductivityArea(isDesktop),
          const SizedBox(height: 32),
          _buildAiAssistantSection(isDesktop),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ───────────────────────── SECTION HEADER ─────────────────

  Widget _buildSectionHeader(String title, {Widget? trailing}) => Row(
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
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      );

  // ───────────────────────── STEM SUBJECTS SECTION ─────────────────

  Widget _buildStemSubjectsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'My STEM Subjects',
            trailing: Row(
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
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            child: ListView.builder(
              controller: _subjectScrollCtrl,
              scrollDirection: Axis.horizontal,
              itemCount: _stemSubjects.length,
              itemBuilder: (ctx, i) => _buildSubjectCard(i),
            ),
          ),
        ],
      );

  Widget _buildCarouselArrow(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.border),
          ),
          child: Icon(icon, size: 16, color: context.colors.textMuted),
        ),
      );

  Widget _buildSubjectCard(int index) {
    final subject = _stemSubjects[index];
    final isHovered = _hoveredSubjectIndex == index;

    return Semantics(
      label: '${subject.name} ${subject.code}',
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredSubjectIndex = index),
        onExit: (_) => setState(() => _hoveredSubjectIndex = -1),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go('/stem-subject/${subject.prefix}'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 270,
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isHovered ? context.colors.surfaceElevated : context.colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isHovered ? subject.color.withValues(alpha: 0.3) : context.colors.border,
                width: isHovered ? 1.5 : 1,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: subject.color.withValues(alpha: 0.08),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
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
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
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
                    Icon(Icons.people_rounded, size: 14, color: context.colors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      '${subject.students} students',
                      style: TextStyle(fontSize: 12, color: context.colors.textMuted),
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
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: subject.progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    builder: (ctx, val, _) => LinearProgressIndicator(
                      value: val,
                      backgroundColor: context.colors.surfaceHighest,
                      color: subject.color,
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: subject.color),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── LANGUAGE HUBS SECTION ─────────────────

  Widget _buildLanguageHubsSection() {
    const languageHubs = [
      {
        'title': 'English',
        'subtitle': 'English Language Hub',
        'slug': 'english',
        'colorHex': 0xFF2196F3,
        'icon': Icons.language_rounded,
      },
      {
        'title': 'Chinese',
        'subtitle': 'Chinese Language Hub',
        'slug': 'chinese',
        'colorHex': 0xFFD32F2F,
        'icon': Icons.translate_rounded,
      },
      {
        'title': 'Arabic',
        'subtitle': 'Arabic Language Hub',
        'slug': 'arabic',
        'colorHex': 0xFF388E3C,
        'icon': Icons.menu_book_rounded,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Language Hubs',
          trailing: TextButton.icon(
            onPressed: () => context.go('/languages'),
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            label: const Text('View All'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 450 ? 2 : 1);
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.0,
              children: languageHubs.map((hub) {
                final color = Color(hub['colorHex'] as int);
                final icon = hub['icon'] as IconData;
                final slug = hub['slug'] as String;

                return Semantics(
                  button: true,
                  label: hub['title'] as String,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => context.go('/language/$slug'),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(icon, color: color, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hub['title'] as String,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hub['subtitle'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: color,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.colors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ───────────────────────── ANALYTICS OVERVIEW ─────────────────

  Widget _buildAnalyticsOverview(bool isDesktop) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Overview'),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isDesktop ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 2.0 : 1.6,
            children: [
              _buildAnalyticCard('12', 'Active Subjects', Icons.menu_book_rounded, AppColors.primary,
                  trend: '+2 this semester'),
              _buildAnalyticCard('245', 'Students Taught', Icons.people_rounded, context.colors.success,
                  trend: '+18 this month'),
              _buildAnalyticCard('18', 'Assessments Created', Icons.quiz_rounded, context.colors.warning,
                  trend: '5 pending review'),
              _buildAnalyticCard('82%', 'Avg Engagement', Icons.trending_up_rounded, context.colors.info,
                  trend: '+4% vs last month'),
            ],
          ),
        ],
      );

  Widget _buildAnalyticCard(String value, String label, IconData icon, Color color, {String? trend}) => Semantics(
        label: '$label: $value',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trend,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  // ───────────────────────── PRODUCTIVITY AREA ─────────────────

  Widget _buildProductivityArea(bool isDesktop) => isDesktop
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

  Widget _buildRecentActivity() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
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

  Widget _buildActivityItem(_ActivityItem activity) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {},
          child: Padding(
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activity.subtitle,
                        style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  activity.time,
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildUpcomingSchedule() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: context.colors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Upcoming Schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
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

  Widget _buildScheduleItem(_ScheduleItem event) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {},
          child: Padding(
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.subtitle,
                        style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      event.time,
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted, fontWeight: FontWeight.w500),
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
          ),
        ),
      );

  // ───────────────────────── AI ASSISTANT SECTION ─────────────────

  Widget _buildAiAssistantSection(bool isDesktop) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Rose AI Teaching Assistant',
            trailing: const SizedBox.shrink(),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Let AI help you create better STEM learning experiences.',
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: isDesktop ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 2.2 : 1.8,
            children: _aiActions.asMap().entries.map((e) => _buildAiActionCard(e.value)).toList(),
          ),
        ],
      );

  static final _aiActions = [
    _AiAction(Icons.menu_book_rounded, 'Generate Lesson Plan', 'Create structured AI-powered lesson plans',
        AppColors.primary),
    _AiAction(
        Icons.quiz_rounded, 'Create Assessment', 'Generate assignments, tests, and evaluations', AppColors.secondary),
    _AiAction(Icons.auto_awesome_rounded, 'Generate Quiz', 'Create adaptive quizzes and practice questions',
        AppColors.accent),
    _AiAction(
        Icons.lightbulb_rounded, 'Content Suggestions', 'Get intelligent material recommendations', AppColors.success),
    _AiAction(
        Icons.edit_note_rounded, 'Generate Lecture Notes', 'AI-powered notes from your curriculum', AppColors.info),
    _AiAction(Icons.science_rounded, 'Lab Guide', 'Create practical and laboratory guides', AppColors.warning),
    _AiAction(Icons.insights_rounded, 'Analyze Performance', 'AI-driven analysis of student performance data',
        AppColors.teal),
    _AiAction(Icons.warning_amber_rounded, 'Identify Difficult Topics', 'Discover topics where students struggle most',
        AppColors.error),
    _AiAction(Icons.person_rounded, 'Personalised Activities', 'Generate tailored activities for each learner',
        AppColors.primaryLight),
    _AiAction(Icons.stacked_bar_chart_rounded, 'STEM Visual Explanation',
        'AI-generated visual diagrams and explanations', AppColors.info),
  ];

  Widget _buildAiActionCard(_AiAction action) => Semantics(
        button: true,
        label: action.title,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go('/ai-tutor'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  // ───────────────────────── SKELETON LOADER ─────────────────

  Widget _buildSkeletonLoader() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSkeletonBar(200, 22),
            const SizedBox(height: 8),
            _buildSkeletonBar(350, 12),
            const SizedBox(height: 24),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, __) => _buildSkeletonCard(270, 210),
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
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: _buildSkeletonCard(0, 200)),
                const SizedBox(width: 16),
                Expanded(child: _buildSkeletonCard(0, 200)),
              ],
            ),
          ],
        ),
      );

  Widget _buildSkeletonBar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.colors.surfaceHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      );

  Widget _buildSkeletonCard(double w, double h) => Container(
        width: w > 0 ? w : null,
        height: h > 0 ? h : null,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
      );

  // ───────────────────────── EMPTY STATE ─────────────────

  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.primaryGlow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'No subjects yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your STEM subjects will appear here once\nthey are assigned to you.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.colors.textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      );

  // ───────────────────────── ERROR STATE ─────────────────

  Widget _buildErrorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.errorMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline_rounded, size: 40, color: context.colors.error),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage.isNotEmpty ? _errorMessage : 'Unable to load dashboard data.\nPlease try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.colors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _hasError = false;
                    _errorMessage = '';
                  });
                  _loadData();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  // ───────────────────────── OFFLINE STATE ─────────────────

  Widget _buildOfflineState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.colors.warningMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.wifi_off_rounded, size: 40, color: context.colors.warning),
              ),
              const SizedBox(height: 24),
              Text(
                'You are offline',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your internet connection.\nSome features may be unavailable.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.colors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: context.colors.warningMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 16, color: context.colors.warning),
                    const SizedBox(width: 8),
                    Text(
                      'Offline Mode',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ───────────────────────── DATA MODELS ─────────────────

class _StemSubject {
  final String name;
  final String code;
  final IconData icon;
  final Color color;
  final double progress;
  final int students;
  final String prefix;
  _StemSubject(this.name, this.code, this.icon, this.color, this.progress, this.students, this.prefix);
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
  _ScheduleItem(this.day, this.month, this.title, this.subtitle, this.time, this.category, this.color);
}

class _AiAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  _AiAction(this.icon, this.title, this.subtitle, this.color);
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  _NavItem(this.icon, this.label, this.route);
}
