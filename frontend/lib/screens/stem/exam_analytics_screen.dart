import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/shimmer_loading.dart';

class ExamAnalyticsScreen extends StatefulWidget {
  const ExamAnalyticsScreen({super.key});

  @override
  State<ExamAnalyticsScreen> createState() => _ExamAnalyticsScreenState();
}

class _ExamAnalyticsScreenState extends State<ExamAnalyticsScreen> {
  final StemService _stemService = StemService();
  Map<String, dynamic> _summary = {};
  List<dynamic> _recentExams = [];
  bool _loading = true;
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
      final results = await Future.wait([
        _stemService.getExamSummary(),
        _stemService.getMockExamHistory(),
      ]);
      if (mounted) {
        setState(() {
          _summary = Map<String, dynamic>.from(results[0] as Map);
          _recentExams = List<dynamic>.from(results[1] as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        body: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 100,
                pinned: true,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colors.textPrimary, size: 18),
                  onPressed: () => Navigator.maybePop(context),
                ),
                backgroundColor: AppColors.primaryDark,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Exam Analytics',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
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
              if (_error != null)
                SliverToBoxAdapter(child: ErrorState(message: 'Failed to load', details: _error, onRetry: _loadData))
              else if (_loading)
                SliverToBoxAdapter(child: ShimmerLoading.list())
              else ...[
                SliverToBoxAdapter(child: _buildSummaryCards()),
                SliverToBoxAdapter(child: _buildScoreTrendChart()),
                SliverToBoxAdapter(child: _buildSubjectBreakdown()),
                SliverToBoxAdapter(child: _buildRecentExamsList()),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ],
          ),
        ),
      );

  Widget _buildSummaryCards() {
    final totalExams = _summary['total_exams'] ?? 0;
    final avgScore = (_summary['average_score'] as num?)?.toDouble() ?? 0;
    final bestScore = (_summary['best_score'] as num?)?.toDouble() ?? 0;
    final totalHours = (_summary['total_study_hours'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
              child: _buildSummaryCard('Total Exams', '$totalExams', context.colors.info, Icons.assignment_outlined)),
          const SizedBox(width: 10),
          Expanded(
              child:
                  _buildSummaryCard('Avg Score', '${avgScore.round()}%', AppColors.primary, Icons.trending_up_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: _buildSummaryCard(
                  'Best Score', '${bestScore.round()}%', context.colors.success, Icons.emoji_events_outlined)),
          const SizedBox(width: 10),
          Expanded(
              child: _buildSummaryCard(
                  'Study Hours', '${totalHours.round()}', context.colors.lavender, Icons.schedule_outlined)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8)),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _buildScoreTrendChart() {
    final subjects = _summary['subjects'] as List? ?? [];
    final hasData = subjects.any((s) => ((s['exams_taken'] ?? 0) as num) > 0);

    if (!hasData) {
      return const EmptyState(
        icon: Icons.show_chart_rounded,
        title: 'No score trends yet',
        subtitle: 'Complete some exams to see your progress over time',
      );
    }

    final dataPoints = <_DataPoint>[];
    for (final s in subjects) {
      final avg = (s['average_score'] as num?)?.toDouble() ?? 0;
      final title = (s['subject_title'] ?? s['slug'] ?? '') as String;
      if (avg > 0) dataPoints.add(_DataPoint(label: title, value: avg));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Score Trends',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _ScoreTrendPainter(dataPoints: dataPoints),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectBreakdown() {
    final subjects = _summary['subjects'] as List? ?? [];
    if (subjects.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subject Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            const SizedBox(height: 14),
            ...subjects.map((s) {
              final title = (s['subject_title'] ?? s['slug'] ?? '') as String;
              final examsTaken = (s['exams_taken'] ?? 0) as int;
              final avgScore = (s['average_score'] as num?)?.toDouble() ?? 0;
              return _buildSubjectRow(title, examsTaken, avgScore);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectRow(String title, int examsTaken, double avgScore) {
    final color = avgScore >= 70
        ? context.colors.success
        : avgScore >= 50
            ? context.colors.warning
            : context.colors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text('$examsTaken exams', style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
              const SizedBox(width: 10),
              Text('${avgScore.round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: avgScore / 100,
              backgroundColor: context.colors.surfaceHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentExamsList() {
    if (_recentExams.isEmpty) {
      return const EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No exams taken yet',
        subtitle: 'Start a mock exam to see your results here',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Exams',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            const SizedBox(height: 12),
            ..._recentExams.take(10).map((e) => _buildExamItem(e)),
          ],
        ),
      ),
    );
  }

  Widget _buildExamItem(dynamic exam) {
    final score = (exam['score'] as num?)?.toDouble() ?? 0;
    final totalQuestions = exam['total_questions'] ?? 0;
    final correctAnswers = exam['correct_answers'] ?? 0;
    final subject = (exam['subject_title'] ?? exam['subject_slug'] ?? '') as String;
    final date = (exam['created_at'] ?? '') as String;
    final color = score >= 70
        ? context.colors.success
        : score >= 50
            ? context.colors.warning
            : context.colors.error;

    return GestureDetector(
      onTap: () => _showExamDetail(exam),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child:
                    Text('${score.round()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$correctAnswers/$totalQuestions correct',
                      style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (date.isNotEmpty)
                  Text(_formatDate(date), style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
                const SizedBox(height: 2),
                Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.6), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
    }
  }

  Future<void> _showExamDetail(dynamic exam) async {
    final examId = (exam['id'] ?? exam['session_id'] ?? 0) as int;
    if (examId == 0) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExamDetailSheet(examId: examId, exam: exam),
    );
  }
}

class _ExamDetailSheet extends StatefulWidget {
  final int examId;
  final dynamic exam;

  const _ExamDetailSheet({required this.examId, required this.exam});

  @override
  State<_ExamDetailSheet> createState() => _ExamDetailSheetState();
}

class _ExamDetailSheetState extends State<_ExamDetailSheet> {
  final StemService _stemService = StemService();
  Map<String, dynamic>? _breakdown;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBreakdown();
  }

  Future<void> _loadBreakdown() async {
    try {
      final data = await _stemService.getExamBreakdown(widget.examId);
      if (mounted) {
        setState(() {
          _breakdown = data;
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
    final score = (widget.exam['score'] as num?)?.toDouble() ?? 0;
    final color = score >= 70
        ? context.colors.success
        : score >= 50
            ? context.colors.warning
            : context.colors.error;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${score.round()}%',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                (widget.exam['subject_title'] ?? widget.exam['subject_slug'] ?? '') as String,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textSecondary),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else if (_breakdown == null || _breakdown!.isEmpty)
              Center(child: Text('No breakdown available', style: TextStyle(color: context.colors.textMuted)))
            else ...[
              _buildConceptBreakdown(),
              const SizedBox(height: 20),
              _buildDifficultyBreakdown(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConceptBreakdown() {
    final concepts = _breakdown!['concepts'] as List? ?? [];
    if (concepts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Concept Breakdown',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
        const SizedBox(height: 12),
        ...concepts.map((c) {
          final title = (c['concept_title'] ?? '') as String;
          final correct = (c['correct'] ?? 0) as num;
          final total = (c['total'] ?? 1) as num;
          final mastery = total > 0 ? correct / total : 0.0;
          final masteryColor = mastery >= 0.7
              ? context.colors.success
              : mastery >= 0.5
                  ? context.colors.warning
                  : context.colors.error;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: mastery,
                        strokeWidth: 3,
                        backgroundColor: context.colors.surfaceHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(masteryColor),
                      ),
                      Center(
                        child: Text(
                          '${(mastery * 100).round()}',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: masteryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style:
                              TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('$correct/$total correct', style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDifficultyBreakdown() {
    final difficulties = _breakdown!['difficulty_breakdown'] as Map<String, dynamic>? ?? {};
    if (difficulties.isEmpty) return const SizedBox.shrink();

    final items = [
      _DifficultyItem('Easy', difficulties['easy'] as Map<String, dynamic>?, context.colors.success),
      _DifficultyItem('Medium', difficulties['medium'] as Map<String, dynamic>?, context.colors.warning),
      _DifficultyItem('Hard', difficulties['hard'] as Map<String, dynamic>?, context.colors.error),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Difficulty Breakdown',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
        const SizedBox(height: 12),
        ...items.map((item) {
          final data = item.data;
          if (data == null) return const SizedBox.shrink();
          final correct = (data['correct'] ?? 0) as num;
          final total = (data['total'] ?? 1) as num;
          final progress = total > 0 ? correct / total : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: item.color)),
                    Text('$correct/$total', style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: context.colors.surfaceHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(item.color),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DifficultyItem {
  final String label;
  final Map<String, dynamic>? data;
  final Color color;
  const _DifficultyItem(this.label, this.data, this.color);
}

class _DataPoint {
  final String label;
  final double value;
  const _DataPoint({required this.label, required this.value});
}

class _ScoreTrendPainter extends CustomPainter {
  final List<_DataPoint> dataPoints;
  const _ScoreTrendPainter({required this.dataPoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5;

    const labelStyle = TextStyle(fontSize: 10, color: AppColors.textMuted);

    const topPadding = 10.0;
    const bottomPadding = 30.0;
    const sidePadding = 10.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final chartWidth = size.width - sidePadding * 2;

    for (final pct in [25, 50, 75, 100]) {
      final y = topPadding + chartHeight * (1 - pct / 100);
      canvas.drawLine(Offset(sidePadding, y), Offset(size.width - sidePadding, y), gridPaint);

      final tp = TextPainter(text: TextSpan(text: '$pct%', style: labelStyle), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(0, y - 6));
    }

    final points = <Offset>[];
    for (var i = 0; i < dataPoints.length; i++) {
      final x = dataPoints.length == 1 ? size.width / 2 : sidePadding + (chartWidth * i / (dataPoints.length - 1));
      final y = topPadding + chartHeight * (1 - dataPoints[i].value / 100);
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    for (final pt in points) {
      canvas.drawCircle(pt, 5, dotPaint);
      canvas.drawCircle(pt, 3, Paint()..color = AppColors.surface);
      canvas.drawCircle(pt, 3, dotPaint);
    }

    for (var i = 0; i < dataPoints.length; i++) {
      final label = dataPoints[i].label.length > 6 ? '${dataPoints[i].label.substring(0, 6)}..' : dataPoints[i].label;
      final tp = TextPainter(text: TextSpan(text: label, style: labelStyle), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(points[i].dx - tp.width / 2, size.height - bottomPadding + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreTrendPainter oldDelegate) => oldDelegate.dataPoints != dataPoints;
}
