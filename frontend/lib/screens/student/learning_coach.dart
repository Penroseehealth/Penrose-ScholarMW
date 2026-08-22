import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class LearningCoachScreen extends StatefulWidget {
  const LearningCoachScreen({super.key});

  @override
  State<LearningCoachScreen> createState() => _LearningCoachScreenState();
}

class _LearningCoachScreenState extends State<LearningCoachScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _plans = [];
  Map<String, dynamic>? _selectedPlan;
  List<dynamic> _items = [];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/analytics/learning-plans');
      if (response.statusCode == 200) {
        final plans = jsonDecode(response.body);
        setState(() => _plans = plans is List ? plans : []);
        if (_plans.isNotEmpty) {
          await _selectPlan(_plans.first['id']);
        } else {
          setState(() => _loading = false);
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectPlan(dynamic planId) async {
    try {
      final response = await _api.get('/analytics/learning-plans/$planId');
      if (response.statusCode == 200) {
        final plan = jsonDecode(response.body);
        setState(() {
          _selectedPlan = plan is Map<String, dynamic> ? plan : null;
          _items = (_selectedPlan != null) ? (_selectedPlan!['items'] ?? []) : [];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _generatePlan() async {
    setState(() => _generating = true);
    try {
      await _api.post('/analytics/learning-plans/generate', body: {
        'exam_date': '2026-12-01',
        'hours_per_day': 2.0,
      });
      await _loadPlans();
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _markComplete(dynamic planId, dynamic itemId) async {
    try {
      await _api.put(
        '/analytics/learning-plans/$planId/items/$itemId/complete',
      );
      await _selectPlan(planId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark as complete')),
        );
      }
    }
  }

  Map<String, List<dynamic>> _groupByDay() {
    final dayOrder = {
      'monday': 0,
      'tuesday': 1,
      'wednesday': 2,
      'thursday': 3,
      'friday': 4,
      'saturday': 5,
      'sunday': 6,
    };
    final grouped = <String, List<dynamic>>{};
    for (final item in _items) {
      final day = (item['day_of_week'] ?? '').toString().toLowerCase();
      grouped.putIfAbsent(day, () => []).add(item);
    }
    final sorted = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) =>
            (dayOrder[a.key] ?? 7).compareTo(dayOrder[b.key] ?? 7)),
    );
    return sorted;
  }

  Color _chipColor(String type) {
    switch (type) {
      case 'study':
        return AppColors.primary;
      case 'quiz':
        return Colors.orange;
      case 'revision':
        return Colors.green;
      case 'mock_exam':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _chipIcon(String type) {
    switch (type) {
      case 'study':
        return Icons.menu_book;
      case 'quiz':
        return Icons.quiz;
      case 'revision':
        return Icons.refresh;
      case 'mock_exam':
        return Icons.science;
      default:
        return Icons.play_arrow;
    }
  }

  String _dayTitle(String day) {
    return day[0].toUpperCase() + day.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penrose Learning Assistant'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPlans,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'YOUR WEEKLY AI STUDY PLAN',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _generating ? null : _generatePlan,
                        icon: _generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Generate New Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedPlan != null) ...[
                    Text(
                      'Exam: ${_selectedPlan!['exam_date'] ?? 'Not set'} · '
                      '${_selectedPlan!['hours_per_day'] ?? 2}h/day',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_items.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(Icons.school,
                                size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'No study plan yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Generate New Plan" to get started',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._groupByDay().entries.map((entry) {
                      return _buildDaySection(entry.key, entry.value);
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildDaySection(String day, List<dynamic> dayItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _dayTitle(day),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...dayItems.map((item) => _buildItemCard(item)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final completed = item['completed'] == true;
    final activityType = (item['activity_type'] ?? 'study').toString();
    final planId = _selectedPlan?['id'];
    final itemId = item['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: completed ? AppColors.successMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: completed
              ? Colors.green.withOpacity(0.3)
              : AppColors.textSecondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          if (completed)
            const Icon(Icons.check_circle, color: Colors.green, size: 22)
          else
            Icon(
              _chipIcon(activityType),
              color: _chipColor(activityType),
              size: 22,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['subject'] ?? item['topic'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    decoration:
                        completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _chipColor(activityType).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        activityType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _chipColor(activityType),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item['duration_minutes'] ?? 30} min',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!completed)
            TextButton(
              onPressed: () => _markComplete(planId, itemId),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Study', style: TextStyle(fontSize: 12)),
            ),
          if (completed)
            TextButton(
              onPressed: null,
              child: Text(
                'Done',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
