import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Color _bioGreen = Color(0xFF10B981);

class BiologyAnalyticsScreen extends StatefulWidget {
  const BiologyAnalyticsScreen({super.key});

  @override
  State<BiologyAnalyticsScreen> createState() => _BiologyAnalyticsScreenState();
}

class _BiologyAnalyticsScreenState extends State<BiologyAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  String _selectedPeriod = 'All Time';

  static final _coreElementProgress = [
    const _CoreProgress('Research Skills', 85, 6, 4, Icons.science_rounded, Colors.blue),
    const _CoreProgress('Environment', 72, 6, 4, Icons.eco_rounded, Colors.teal),
    const _CoreProgress('Plant Biology', 60, 5, 3, Icons.local_florist_rounded, _bioGreen),
    const _CoreProgress('Animal Biology', 45, 4, 2, Icons.pets_rounded, Colors.orange),
    const _CoreProgress('Human Biology', 35, 15, 6, Icons.person_rounded, Colors.purple),
    const _CoreProgress('Micro-organisms', 20, 4, 1, Icons.bug_report_rounded, Colors.red),
    const _CoreProgress('Genetics & Evolution', 15, 6, 3, Icons.science_rounded, Colors.amber),
  ];

  static final _recentActivity = [
    const _Activity('Completed Chapter 1 Quiz', 'Practice Centre', 85, Icons.quiz_rounded, '2h ago'),
    const _Activity('Reviewed Photosynthesis Diagram', 'Diagram Centre', 70, Icons.image_rounded, '4h ago'),
    const _Activity('Virtual Lab: Osmosis Experiment', 'Virtual Lab', 90, Icons.science_rounded, '1d ago'),
    const _Activity('Practical Report: Microscope', 'Practical Hub', 75, Icons.edit_document, '2d ago'),
    const _Activity('Past Paper: 2023 MSCE', 'Past Papers', 65, Icons.description_rounded, '3d ago'),
    const _Activity('Mock Exam: Paper 1', 'Mock Exams', 80, Icons.assignment_rounded, '5d ago'),
  ];

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1623),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/biology'),
        ),
        title: const Text(
          'Biology Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          _periodDropdown(),
          const SizedBox(width: 12),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCards(isDesktop, isTablet, screenWidth),
              const SizedBox(height: 24),
              _buildSectionTitle('Core Element Progress'),
              const SizedBox(height: 12),
              _buildCoreElementBars(),
              const SizedBox(height: 24),
              _buildSectionTitle('Overall Statistics'),
              const SizedBox(height: 12),
              _buildStatsGrid(isDesktop),
              const SizedBox(height: 24),
              _buildSectionTitle('Recent Activity'),
              const SizedBox(height: 12),
              _buildActivityList(),
              const SizedBox(height: 24),
              _buildSectionTitle('Weekly Study Pattern'),
              const SizedBox(height: 12),
              _buildWeeklyChart(),
              const SizedBox(height: 24),
              _buildSectionTitle('Recommended Actions'),
              const SizedBox(height: 12),
              _buildRecommendations(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodDropdown() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bioGreen.withValues(alpha: 0.2)),
      ),
      child: DropdownButton<String>(
        value: _selectedPeriod,
        isDense: true,
        dropdownColor: const Color(0xFF1A2035),
        underline: const SizedBox(),
        items: ['This Week', 'This Month', 'This Term', 'All Time']
            .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p,
                    style: const TextStyle(color: Colors.white70, fontSize: 12))))
            .toList(),
        onChanged: (v) => setState(() => _selectedPeriod = v ?? 'All Time'),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54, size: 18),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildOverviewCards(bool isDesktop, bool isTablet, double screenWidth) {
    final cards = [
      const _OverviewCard('Overall Mastery', '48%', Icons.trending_up_rounded, _bioGreen),
      const _OverviewCard('Questions Answered', '312', Icons.quiz_rounded, Colors.blue),
      const _OverviewCard('Study Hours', '24.5', Icons.access_time_rounded, Colors.orange),
      const _OverviewCard('Streak', '7 days', Icons.local_fire_department_rounded, Colors.amber),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: _overviewCard(c))).toList(),
      );
    }
    if (isTablet) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(
          width: (screenWidth - 44) / 2,
          child: _overviewCard(c),
        )).toList(),
      );
    }
    return Column(
      children: cards.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _overviewCard(c),
      )).toList(),
    );
  }

  Widget _overviewCard(_OverviewCard card) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(card.icon, color: card.color, size: 24),
          const SizedBox(height: 10),
          Text(card.value,
              style: TextStyle(
                  color: card.color, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(card.label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCoreElementBars() {
    return Column(
      children: _coreElementProgress.map((cp) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cp.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cp.icon, color: cp.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cp.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text('${cp.progress}%',
                            style: TextStyle(
                                color: cp.color,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: cp.progress / 100,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation(cp.color),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('${cp.topics} topics',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11)),
                        const SizedBox(width: 12),
                        Text('${cp.completed} completed',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatsGrid(bool isDesktop) {
    final stats = [
      const _StatItem('Quiz Average', '76%', Icons.analytics_rounded, _bioGreen),
      const _StatItem('Mock Exam Best', '82%', Icons.assignment_turned_in_rounded, Colors.blue),
      const _StatItem('Diagrams Mastered', '8/15', Icons.image_rounded, Colors.orange),
      const _StatItem('Practicals Done', '6/12', Icons.science_rounded, Colors.purple),
      const _StatItem('Virtual Labs', '4/6', Icons.biotech_rounded, Colors.teal),
      const _StatItem('Study Days', '21/30', Icons.calendar_today_rounded, Colors.amber),
    ];

    if (isDesktop) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: stats.map((s) => SizedBox(
          width: 180,
          child: _statCard(s),
        )).toList(),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats.map((s) => SizedBox(
        width: 160,
        child: _statCard(s),
      )).toList(),
    );
  }

  Widget _statCard(_StatItem stat) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: stat.color, size: 22),
          const SizedBox(height: 10),
          Text(stat.value,
              style: TextStyle(
                  color: stat.color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(stat.label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    return Column(
      children: _recentActivity.map((a) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _bioGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a.icon, color: _bioGreen, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(a.source,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${a.score}%',
                      style: TextStyle(
                          color: _scoreColor(a.score),
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(a.time,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return _bioGreen;
    if (score >= 60) return Colors.orange;
    return Colors.redAccent;
  }

  Widget _buildWeeklyChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hours = [1.5, 2.0, 0.5, 3.0, 2.5, 4.0, 1.0];
    final maxH = hours.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Study hours this week',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              const Text('14.5h total',
                  style: TextStyle(
                      color: _bioGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final fraction = hours[i] / maxH;
                final isToday = i == DateTime.now().weekday - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${hours[i]}h',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10)),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 80 * fraction,
                          decoration: BoxDecoration(
                            color: isToday
                                ? _bioGreen
                                : _bioGreen.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(days[i],
                            style: TextStyle(
                                color: isToday
                                    ? _bioGreen
                                    : Colors.white.withValues(alpha: 0.4),
                                fontSize: 11,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    final recs = [
      const _Recommendation(
        'Focus on Micro-organisms',
        'You have only completed 20% of this core element. Review the syllabus and attempt practice questions.',
        Icons.bug_report_rounded,
        Colors.red,
      ),
      const _Recommendation(
        'Practice Human Biology Diagrams',
        'Try the Diagram Centre for heart, eye, and reproductive system diagrams.',
        Icons.image_rounded,
        Colors.purple,
      ),
      const _Recommendation(
        'Take a Mock Exam',
        'You haven\'t attempted Mock Exam 3 yet. Test your full syllabus coverage.',
        Icons.assignment_rounded,
        Colors.orange,
      ),
    ];

    return Column(
      children: recs.map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: r.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: r.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(r.icon, color: r.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(r.description,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            height: 1.3)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.2), size: 16),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _OverviewCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _OverviewCard(this.label, this.value, this.icon, this.color);
}

class _CoreProgress {
  final String name;
  final int progress;
  final int topics;
  final int completed;
  final IconData icon;
  final Color color;
  const _CoreProgress(this.name, this.progress, this.topics, this.completed, this.icon, this.color);
}

class _Activity {
  final String title;
  final String source;
  final int score;
  final IconData icon;
  final String time;
  const _Activity(this.title, this.source, this.score, this.icon, this.time);
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _Recommendation {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  const _Recommendation(this.title, this.description, this.icon, this.color);
}
