import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class LecturerCentre extends StatefulWidget {
  const LecturerCentre({super.key});

  @override
  State<LecturerCentre> createState() => _LecturerCentreState();
}

class _LecturerCentreState extends State<LecturerCentre> {
  final CourseService _courseService = CourseService();
  final AiService _aiService = AiService();
  List<dynamic> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final courses = await _courseService.listCourses();
    if (mounted) {
      setState(() {
        _courses = courses;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => Scaffold.of(context).openEndDrawer(),
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
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
                            'Lecturer Command Centre',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$greeting, Dr. Penrose',
                            style: const TextStyle(
          color: AppColors.surface,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('My Courses'),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ...(_courses.map((c) => _buildCourseCard(c))),
                    const SizedBox(height: 24),
                    _buildSectionTitle('AI Teaching Assistant'),
                    const SizedBox(height: 12),
                    _buildAiActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Courses', '${_courses.length}', Icons.menu_book_outlined, AppColors.primary),
        const SizedBox(width: 12),
        _buildStatCard('Students', '--', Icons.people_outlined, AppColors.accent),
        const SizedBox(width: 12),
        _buildStatCard('Engagement', '--%', Icons.trending_up, AppColors.success),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCourseCard(dynamic course) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        course['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course['code'] ?? '',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.75,
                backgroundColor: AppColors.surfaceHighest,
                color: AppColors.primary,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiActions() {
    final actions = [
      _buildAiActionCard(
        icon: Icons.menu_book_outlined,
        label: 'Generate Lesson Plan',
        color: AppColors.primary,
        onTap: () => _showLessonPlanDialog(),
      ),
      _buildAiActionCard(
        icon: Icons.quiz_outlined,
        label: 'Create Assessment',
        color: AppColors.secondary,
        onTap: () => context.push('/assessment-studio'),
      ),
      _buildAiActionCard(
        icon: Icons.fact_check_outlined,
        label: 'Generate Quiz',
        color: AppColors.accent,
        onTap: () => context.push('/assessment-studio'),
      ),
      _buildAiActionCard(
        icon: Icons.auto_stories_outlined,
        label: 'Revision Material',
        color: AppColors.success,
        onTap: () => context.push('/ai-tutor'),
      ),
      _buildAiActionCard(
        icon: Icons.analytics_outlined,
        label: 'Analyse Performance',
        color: AppColors.info,
        onTap: () => context.push('/analytics'),
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }

  Widget _buildAiActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 40) / 2 - 4,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLessonPlanDialog() {
    final topicCtrl = TextEditingController();
    final levelCtrl = TextEditingController(text: 'Year 3');
    final durationCtrl = TextEditingController(text: '90');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Lesson Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: topicCtrl,
              decoration: const InputDecoration(labelText: 'Topic'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: levelCtrl,
              decoration: const InputDecoration(labelText: 'Level'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationCtrl,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await _aiService.generateLessonPlan(
                topic: topicCtrl.text,
                level: levelCtrl.text,
                durationMinutes: int.tryParse(durationCtrl.text) ?? 90,
              );
              if (mounted && result['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lesson plan generated!')),
                );
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }
}
