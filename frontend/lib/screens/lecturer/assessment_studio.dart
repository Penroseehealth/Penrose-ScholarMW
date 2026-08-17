import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';

class AssessmentStudio extends StatefulWidget {
  const AssessmentStudio({super.key});

  @override
  State<AssessmentStudio> createState() => _AssessmentStudioState();
}

class _AssessmentStudioState extends State<AssessmentStudio> {
  final AiService _aiService = AiService();
  final _topicCtrl = TextEditingController();
  String _difficulty = 'medium';
  int _numQuestions = 10;
  List<String> _selectedTypes = ['mcq', 'short_answer'];
  List<dynamic> _generatedQuestions = [];
  bool _generating = false;
  bool _editing = false;

  final _types = [
    {'key': 'mcq', 'label': 'MCQ', 'icon': Icons.radio_button_checked},
    {'key': 'true_false', 'label': 'True/False', 'icon': Icons.check_circle_outline},
    {'key': 'short_answer', 'label': 'Short Answer', 'icon': Icons.short_text},
    {'key': 'essay', 'label': 'Essay', 'icon': Icons.article_outlined},
    {'key': 'case_study', 'label': 'Case Study', 'icon': Icons.medical_services_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assessment Studio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Configure Assessment'),
            const SizedBox(height: 12),
            TextField(
              controller: _topicCtrl,
              decoration: const InputDecoration(
                labelText: 'Topic',
                hintText: 'e.g. Antimicrobial Resistance',
                prefixIcon: Icon(Icons.topic_outlined),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _difficulty,
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    items: const [
                      DropdownMenuItem(value: 'easy', child: Text('Easy')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'hard', child: Text('Hard')),
                    ],
                    onChanged: (v) => setState(() => _difficulty = v ?? 'medium'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _numQuestions,
                    decoration: const InputDecoration(labelText: 'Questions'),
                    items: [5, 10, 15, 20, 25, 30]
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) => setState(() => _numQuestions = v ?? 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionHeader('Question Types'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final selected = _selectedTypes.contains(t['key']);
                return FilterChip(
                  label: Text(t['label'] as String),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedTypes.add(t['key'] as String);
                      } else {
                        _selectedTypes.remove(t['key']);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _generateAssessment,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_generating ? 'Generating...' : 'Generate Assessment'),
              ),
            ),
            if (_generatedQuestions.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionHeader('Generated Questions (${_generatedQuestions.length})'),
              const SizedBox(height: 8),
              ...(_generatedQuestions.asMap().entries.map((e) => _buildQuestionCard(e.key, e.value))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _editing = !_editing),
                      icon: Icon(_editing ? Icons.close : Icons.edit),
                      label: Text(_editing ? 'Done Editing' : 'Review & Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _publishAssessment,
                      icon: const Icon(Icons.publish),
                      label: const Text('Approve & Publish'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildQuestionCard(int index, dynamic q) {
    final typeColors = {
      'mcq': AppColors.primary,
      'true_false': AppColors.secondary,
      'short_answer': AppColors.accent,
      'essay': AppColors.info,
      'case_study': AppColors.success,
    };
    final qType = q['question_type'] ?? 'mcq';
    final color = typeColors[qType] ?? AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withOpacity(0.1),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    qType.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
                const Spacer(),
                Text(
                  '${q['marks'] ?? 1} mark${(q['marks'] ?? 1) > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_editing)
              TextFormField(
                initialValue: q['question_text'] ?? '',
                onChanged: (v) => _generatedQuestions[index]['question_text'] = v,
                decoration: const InputDecoration(isDense: true),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              )
            else
              Text(
                q['question_text'] ?? '',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            if (q['options'] != null && (q['options'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              if (_editing)
                TextFormField(
                  initialValue: q['options'] as String,
                  onChanged: (v) => _generatedQuestions[index]['options'] = v,
                  maxLines: null,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'One option per line',
                  ),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                )
              else
                ...((q['options'] as String).split('\n').map((o) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(o, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ))),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _publishAssessment() async {
    final api = ApiService();
    final response = await api.post('/assessments/', body: {
      'course_id': 1,
      'title': _topicCtrl.text,
      'description': 'AI-generated assessment',
      'assessment_type': 'ai_generated',
      'total_marks': _generatedQuestions.fold<int>(0, (sum, q) => sum + ((q['marks'] as int?) ?? 1)),
      'weight_pct': 10.0,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.statusCode == 201
                ? 'Assessment published successfully'
                : 'Failed to publish assessment',
          ),
        ),
      );
    }
  }

  Future<void> _generateAssessment() async {
    if (_topicCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic')),
      );
      return;
    }

    setState(() => _generating = true);
    final result = await _aiService.generateAssessment(
      courseId: 1,
      topic: _topicCtrl.text,
      numQuestions: _numQuestions,
      difficulty: _difficulty,
      questionTypes: _selectedTypes,
    );
    if (mounted) {
      setState(() {
        _generating = false;
        _generatedQuestions = result['success'] ? (result['data']['questions'] ?? []) : [];
      });
      if (_generatedQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No questions generated. Try a different topic.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }
}
