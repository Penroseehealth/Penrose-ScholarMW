import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';

const Color _agriGreen = Color(0xFF22C55E);
const Color _agriGreenDark = Color(0xFF16A34A);
const Color _agriGreenGlow = Color(0x2222C55E);

class AgricultureDashboard extends StatefulWidget {
  const AgricultureDashboard({super.key});

  @override
  State<AgricultureDashboard> createState() => _AgricultureDashboardState();
}

class _AgricultureDashboardState extends State<AgricultureDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool _loading = true;
  String _versionName = '';
  int _coreElementCount = 0;
  int _topicCount = 0;
  int _subtopicCount = 0;
  int _form1Topics = 0;
  int _form2Topics = 0;
  final List<Map<String, dynamic>> _coreElements = [];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadSyllabus();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSyllabus() async {
    try {
      final api = ApiService();
      final res = await api.get('/syllabus/subjects/agriculture/tree');
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final versions = data['versions'] as List? ?? [];
        final currentVersion = versions.cast<Map<String, dynamic>>().firstWhere(
              (v) => v['is_current'] == true,
              orElse: () => versions.isNotEmpty ? versions.last as Map<String, dynamic> : {},
            );
        _versionName = currentVersion['version_name'] as String? ?? '';

        final coreElements = currentVersion['core_elements'] as List? ?? [];
        _coreElementCount = coreElements.length;
        _coreElements.clear();

        for (final ce in coreElements) {
          final ceData = ce as Map<String, dynamic>;
          final topics = ceData['topics'] as List? ?? [];
          _topicCount += topics.length;
          for (final t in topics) {
            final yr = (t as Map<String, dynamic>)['year_level'] as int? ?? 1;
            if (yr <= 1) {
              _form1Topics++;
            } else if (yr <= 2) {
              _form2Topics++;
            }
            final subs = t['subtopics'] as List? ?? [];
            _subtopicCount += subs.length;
          }
          _coreElements.add({
            'number': ceData['number'],
            'name': ceData['name'],
            'description': ceData['description'] ?? '',
            'topicCount': topics.length,
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  double get _overallProgress => 0.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContinueLearning(),
                    const SizedBox(height: 24),
                    _buildQuickStats(isDesktop),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Agriculture Module'),
                    const SizedBox(height: 14),
                    _buildModuleGrid(isDesktop),
                    const SizedBox(height: 28),
                    _buildSectionTitle('MSCE Core Elements'),
                    const SizedBox(height: 14),
                    _buildThemeProgress(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.go('/stem'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.colors.textSecondary),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _agriGreenGlow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.eco_rounded, color: _agriGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Agriculture',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                            letterSpacing: -0.3)),
                    Text('MSCE Learning Journey', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _agriGreenGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value: _overallProgress,
                        strokeWidth: 2.5,
                        color: _agriGreen,
                        backgroundColor: context.colors.surfaceHighest,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_overallProgress * 100).toInt()}% Mastery',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _agriGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildContinueLearning() => Semantics(
        label: 'Continue learning: Introduction to Agriculture — Farming Systems',
        button: true,
        child: GestureDetector(
          onTap: () => context.go('/agri-topics'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _agriGreen.withValues(alpha: 0.12),
                  _agriGreenDark.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _agriGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _agriGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: _agriGreen, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Continue Learning',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textMuted,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('Introduction to Agriculture — Farming Systems',
                          style:
                              TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.0,
                                backgroundColor: context.colors.surfaceHighest,
                                color: _agriGreen,
                                minHeight: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('0%',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _agriGreen)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _agriGreen),
              ],
            ),
          ),
        ),
      );

  Widget _buildQuickStats(bool isDesktop) => GridView.count(
        crossAxisCount: isDesktop ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isDesktop ? 2.0 : 1.6,
        children: [
          _buildStatCard(
            '$_coreElementCount',
            'Core Elements',
            Icons.menu_book_rounded,
            _agriGreen,
            '${_coreElementCount > 0 ? "$_topicCount topics" : "Loading..."}',
          ),
          _buildStatCard(
            '$_topicCount',
            'Topics',
            Icons.topic_rounded,
            context.colors.info,
            '$_subtopicCount subtopics',
          ),
          _buildStatCard(
            '$_form1Topics',
            'Form 1 Topics',
            Icons.looks_one_rounded,
            context.colors.warning,
            '$_form2Topics Form 2 topics',
          ),
          _buildStatCard(
            '$_form2Topics',
            'Form 2 Topics',
            Icons.looks_two_rounded,
            context.colors.success,
            '$_versionName',
          ),
        ],
      );

  Widget _buildStatCard(String value, String label, IconData icon, Color color, String sub) => Container(
        padding: const EdgeInsets.all(16),
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
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
                Text(value,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
              ],
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          ],
        ),
      );

  Widget _buildSectionTitle(String title) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_agriGreen, _agriGreenDark]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.textPrimary, letterSpacing: -0.3)),
        ],
      );

  static final _modules = [
    const _AgriModule(Icons.book_rounded, '📖 Syllabus', 'Official MSCE Agriculture syllabus', '/agri-syllabus'),
    const _AgriModule(Icons.menu_book_rounded, 'Topics & Syllabus', 'Full MSCE Agriculture curriculum', '/agri-topics'),
    const _AgriModule(
        Icons.auto_awesome_rounded, 'Agriculture AI Tutor', 'AI-powered Agriculture assistant', '/agri-ai-tutor'),
    const _AgriModule(
        Icons.agriculture_rounded, 'Practical Learning', 'Hands-on farming activities', '/agri-practicals'),
    const _AgriModule(Icons.image_rounded, 'Visual Learning', 'Interactive agriculture visuals', '/agri-visuals'),
    const _AgriModule(Icons.quiz_rounded, 'Questions & Practice', 'MCQ, short answer & more', '/agri-practice'),
    const _AgriModule(Icons.assignment_rounded, 'Assessments', 'MSCE-style assessments', '/agri-assessments'),
    const _AgriModule(Icons.replay_rounded, 'Revision', 'Spaced repetition & flashcards', '/agri-revision'),
    const _AgriModule(
        Icons.stacked_bar_chart_rounded, 'Progress & Mastery', 'Track your mastery journey', '/stem-mastery'),
    const _AgriModule(Icons.note_alt_rounded, 'Notebook', 'Your personal study notes', '/agri-notebook'),
    const _AgriModule(Icons.download_rounded, 'Offline Content', 'Download for offline study', '/offline-sync'),
    const _AgriModule(Icons.insights_rounded, 'Analytics', 'Detailed performance analytics', '/stem-analytics'),
  ];

  Widget _buildModuleGrid(bool isDesktop) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isDesktop ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 2.0 : 1.7,
        ),
        itemCount: _modules.length,
        itemBuilder: (ctx, i) => _buildModuleCard(_modules[i]),
      );

  Widget _buildModuleCard(_AgriModule mod) => Semantics(
        button: true,
        label: mod.title,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go(mod.route),
            child: Container(
              padding: const EdgeInsets.all(16),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _agriGreenGlow,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(mod.icon, size: 20, color: _agriGreen),
                  ),
                  const Spacer(),
                  Text(mod.title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(mod.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildThemeProgress() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Center(child: CircularProgressIndicator(color: _agriGreen)),
      );
    }
    if (_coreElements.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.eco_rounded, size: 32, color: context.colors.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Syllabus topics will appear here once seeded',
                  style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Icon(Icons.eco_rounded, size: 18, color: _agriGreen),
                const SizedBox(width: 8),
                Text(
                  '$_coreElementCount Core Elements · $_topicCount Topics · $_subtopicCount Subtopics',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          ..._coreElements.map((ce) => _CoreElementTile(
                number: ce['number'] as int,
                name: ce['name'] as String,
                description: ce['description'] as String,
                topicCount: ce['topicCount'] as int,
                accentColor: _agriGreen,
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AgriModule {
  final IconData icon;
  final String title;
  final String description;
  final String route;
  const _AgriModule(this.icon, this.title, this.description, this.route);
}

class _CoreElementTile extends StatelessWidget {
  final int number;
  final String name;
  final String description;
  final int topicCount;
  final Color accentColor;

  const _CoreElementTile({
    required this.number,
    required this.name,
    required this.description,
    required this.topicCount,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/agri-syllabus'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: accentColor),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted.withValues(alpha: 0.8)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$topicCount topic${topicCount != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 10, color: context.colors.textMuted),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}
