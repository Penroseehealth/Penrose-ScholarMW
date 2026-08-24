import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';
import '../../widgets/stem_text.dart';

class StudyPlanScreen extends StatefulWidget {
  final int courseId;

  const StudyPlanScreen({super.key, required this.courseId});

  @override
  State<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends State<StudyPlanScreen> {
  final AiService _aiService = AiService();
  Map<String, dynamic>? _plan;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _generatePlan();
  }

  Future<void> _generatePlan() async {
    setState(() => _loading = true);
    final result = await _aiService.generateStudyPlan(
      courseId: widget.courseId,
      hoursPerDay: 3,
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _plan = result['success'] == true ? result['data'] as Map<String, dynamic>? : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Study Plan'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _generatePlan,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating your personalized study plan...'),
                  ],
                ),
              )
            : _plan == null
                ? const Center(child: Text('Failed to generate plan'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWeakTopics(),
                        const SizedBox(height: 20),
                        _buildSchedule(),
                        const SizedBox(height: 20),
                        _buildResources(),
                      ],
                    ),
                  ),
      );

  Widget _buildWeakTopics() {
    final weakTopics = List<String>.from((_plan!['weak_topics'] ?? []) as Iterable);
    if (weakTopics.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: context.colors.warning, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Weak Areas Identified',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...weakTopics.map((topic) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.colors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: StemText(topic)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedule() {
    final schedule = List<Map<String, dynamic>>.from((_plan!['schedule'] ?? []) as Iterable);
    if (schedule.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Study Schedule',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...schedule.map((day) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (day['date'] ?? '') as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${day['hours'] ?? 0}h',
                          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StemText(
                      (day['topic'] ?? '') as String,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (day['activity'] != null) ...[
                      const SizedBox(height: 4),
                      StemText(
                        day['activity'] as String,
                        style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildResources() {
    final resources = List<String>.from((_plan!['recommended_resources'] ?? []) as Iterable);
    if (resources.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommended Resources',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...resources.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.link, size: 16, color: context.colors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StemText(
                          r,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
