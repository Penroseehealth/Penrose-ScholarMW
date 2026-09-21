import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_colors.dart';

const Color _bioGreen = Color(0xFF10B981);
const Color _bioGreenDark = Color(0xFF059669);
const Color _bioGreenGlow = Color(0x2210B981);

class BiologyDashboard extends StatefulWidget {
  const BiologyDashboard({super.key});

  @override
  State<BiologyDashboard> createState() => _BiologyDashboardState();
}

class _BiologyDashboardState extends State<BiologyDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final Map<String, double> _chapterProgress = {
    'Introduction to Biology': 0.85,
    'Cell Biology': 0.72,
    'Movement of Substances': 0.60,
    'Nutrition': 0.45,
    'Transport': 0.30,
    'Gaseous Exchange & Respiration': 0.20,
    'Excretion & Homeostasis': 0.10,
    'Coordination & Response': 0.05,
    'Reproduction': 0.0,
    'Genetics & Inheritance': 0.0,
    'Ecology': 0.0,
    'Microorganisms': 0.0,
    'Disease & Immunity': 0.0,
    'Environment & Conservation': 0.0,
    'Practical Skills': 0.15,
  };

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  double get _overallProgress {
    if (_chapterProgress.isEmpty) return 0;
    final sum = _chapterProgress.values.fold<double>(0, (a, b) => a + b);
    return sum / _chapterProgress.length;
  }

  int get _masteredCount => _chapterProgress.values.where((p) => p >= 0.8).length;

  int get _inProgressCount => _chapterProgress.values.where((p) => p > 0 && p < 0.8).length;

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
                    _buildSectionTitle('Biology Module'),
                    const SizedBox(height: 14),
                    _buildModuleGrid(isDesktop),
                    const SizedBox(height: 28),
                    _buildSectionTitle('MSCE Chapter Progress'),
                    const SizedBox(height: 14),
                    _buildChapterProgress(),
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
                  color: _bioGreenGlow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.biotech_rounded, color: _bioGreen, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Biology',
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
                  color: _bioGreenGlow,
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
                        color: _bioGreen,
                        backgroundColor: context.colors.surfaceHighest,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_overallProgress * 100).toInt()}% Mastery',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _bioGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildContinueLearning() => Semantics(
        label: 'Continue learning: Cell Biology',
        button: true,
        child: GestureDetector(
          onTap: () => context.go('/stem-topic/cell-biology'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _bioGreen.withValues(alpha: 0.12),
                  _bioGreenDark.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _bioGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _bioGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: _bioGreen, size: 30),
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
                      Text('Cell Biology — Plant and Animal Cells',
                          style:
                              TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 0.72,
                                backgroundColor: context.colors.surfaceHighest,
                                color: _bioGreen,
                                minHeight: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('72%',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _bioGreen)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _bioGreen),
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
          _buildStatCard('15', 'MSCE Chapters', Icons.menu_book_rounded, _bioGreen, '5 in progress'),
          _buildStatCard('$_masteredCount', 'Mastered', Icons.check_circle_rounded, context.colors.success,
              '$_inProgressCount in progress'),
          _buildStatCard('42', 'Practical Skills', Icons.science_rounded, context.colors.info, '8 completed'),
          _buildStatCard('76%', 'Quiz Average', Icons.quiz_rounded, context.colors.warning, '+6% this week'),
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
              gradient: const LinearGradient(colors: [_bioGreen, _bioGreenDark]),
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
    const _BioModule(Icons.book_rounded, '📖 Syllabus', 'Official MSCE Biology syllabus', '/bio-syllabus'),
    const _BioModule(Icons.menu_book_rounded, 'Topics & Syllabus', 'Full MSCE Biology curriculum', '/bio-topics'),
    const _BioModule(Icons.auto_awesome_rounded, 'Biology AI Tutor', 'AI-powered Biology assistant', '/bio-ai-tutor'),
    const _BioModule(Icons.science_rounded, 'Virtual Biology Lab', 'Interactive experiments', '/bio-virtual-lab'),
    const _BioModule(Icons.science_outlined, 'Practical Skills', 'Lab techniques & procedures', '/bio-practicals'),
    const _BioModule(Icons.image_rounded, 'Diagram Centre', 'Interactive biology diagrams', '/bio-diagrams'),
    const _BioModule(Icons.bolt_rounded, 'Neuron Communication', 'Animated two-neuron signalling', '/bio-neuron'),
    const _BioModule(Icons.quiz_rounded, 'Practice Centre', 'MCQ, short answer & more', '/bio-practice'),
    const _BioModule(Icons.description_rounded, 'Past Papers', 'MSCE past exam papers', '/bio-past-papers'),
    const _BioModule(Icons.assignment_rounded, 'Mock Exams', 'MSCE-style mock examinations', '/bio-mock-exam'),
    const _BioModule(Icons.replay_rounded, 'Revision Centre', 'Spaced repetition & flashcards', '/stem-revision'),
    const _BioModule(
        Icons.stacked_bar_chart_rounded, 'Progress & Mastery', 'Track your mastery journey', '/stem-mastery'),
    const _BioModule(Icons.note_alt_rounded, 'Biology Notebook', 'Your personal study notes', '/bio-notebook'),
    const _BioModule(Icons.search_rounded, 'Biology Search', 'Search all Biology content', '/search'),
    const _BioModule(Icons.download_rounded, 'Offline Content', 'Download for offline study', '/offline-sync'),
    const _BioModule(Icons.insights_rounded, 'Analytics', 'Detailed performance analytics', '/bio-analytics'),
    const _BioModule(Icons.settings_rounded, 'Biology Settings', 'Customise your experience', '/settings'),
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

  Widget _buildModuleCard(_BioModule mod) => Semantics(
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
                      color: _bioGreenGlow,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(mod.icon, size: 20, color: _bioGreen),
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

  Widget _buildChapterProgress() {
    final chapters = _chapterProgress.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < chapters.length; i++) ...[
            _buildChapterRow(chapters[i].key, chapters[i].value, i + 1),
            if (i < chapters.length - 1) Divider(height: 1, indent: 20, endIndent: 20, color: context.colors.border),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterRow(String name, double progress, int number) {
    final color = progress >= 0.8
        ? context.colors.success
        : progress >= 0.4
            ? _bioGreen
            : progress > 0
                ? context.colors.warning
                : context.colors.textMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/bio-topics?chapter=$number'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('$number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: context.colors.surfaceHighest,
                              color: color,
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${(progress * 100).toInt()}%',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _BioModule {
  final IconData icon;
  final String title;
  final String description;
  final String route;
  const _BioModule(this.icon, this.title, this.description, this.route);
}
