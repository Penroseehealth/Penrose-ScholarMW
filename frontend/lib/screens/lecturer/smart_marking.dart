import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';

class SmartMarkingScreen extends StatefulWidget {
  final int assessmentId;
  final List<dynamic> submissions;

  const SmartMarkingScreen({
    super.key,
    required this.assessmentId,
    required this.submissions,
  });

  @override
  State<SmartMarkingScreen> createState() => _SmartMarkingScreenState();
}

class _SmartMarkingScreenState extends State<SmartMarkingScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.submissions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Smart Marking')),
        body: const Center(child: Text('No submissions to mark')),
      );
    }

    final sub = widget.submissions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Marking Assistant'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentIndex + 1}/${widget.submissions.length}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentInfo(sub),
            const SizedBox(height: 16),
            _buildSubmissionContent(sub),
            const SizedBox(height: 16),
            _buildAIAnalysis(sub),
            const SizedBox(height: 16),
            _buildMarkingDecision(sub),
            const SizedBox(height: 16),
            _buildNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfo(dynamic sub) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          title: Text('Student #${sub['student_id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Submitted: ${sub['submitted_at'] ?? 'N/A'}'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sub['status'] == 'graded'
                  ? context.colors.success.withValues(alpha: 0.1)
                  : context.colors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (sub['status'] ?? 'pending') as String,
              style: TextStyle(
                fontSize: 11,
                color: sub['status'] == 'graded' ? context.colors.success : context.colors.warning,
              ),
            ),
          ),
        ),
      );

  Widget _buildSubmissionContent(dynamic sub) {
    String answers = 'No answers submitted';
    try {
      answers = (sub['answers'] ?? answers) as String;
    } catch (_) {}

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Student Answers',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(answers, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAnalysis(dynamic sub) {
    final aiMarks = sub['ai_suggested_marks'];
    final aiFeedback = (sub['ai_feedback'] ?? 'AI analysis pending...') as String;

    return Card(
      color: context.colors.info.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: context.colors.info, size: 20),
                const SizedBox(width: 8),
                Text(
                  'AI Analysis',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.colors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (aiMarks != null) ...[
              Row(
                children: [
                  const Text('AI Suggested Mark: ', style: TextStyle(fontSize: 14)),
                  Text(
                    '$aiMarks',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.colors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(aiFeedback, style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkingDecision(dynamic sub) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Decision',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDecisionButton(
                      label: 'Accept AI',
                      icon: Icons.check_circle_outline,
                      color: context.colors.success,
                      onPressed: () => _submitDecision('accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDecisionButton(
                      label: 'Modify',
                      icon: Icons.edit_outlined,
                      color: context.colors.secondary,
                      onPressed: () => _showModifyDialog(sub),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDecisionButton(
                      label: 'Reject',
                      icon: Icons.cancel_outlined,
                      color: context.colors.error,
                      onPressed: () => _submitDecision('reject'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildDecisionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) =>
      OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 18),
        label: Text(label, style: TextStyle(color: color, fontSize: 12)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );

  Widget _buildNavigation() => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
              child: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _currentIndex < widget.submissions.length - 1 ? () => setState(() => _currentIndex++) : null,
              child: const Text('Next'),
            ),
          ),
        ],
      );

  Future<void> _submitDecision(String decision, {int? finalMarks, String? feedback}) async {
    final sub = widget.submissions[_currentIndex];
    final submissionId = sub['id'];
    final api = ApiService();
    final response = await api.put('/assessments/submissions/$submissionId/mark', body: {
      'submission_id': submissionId,
      'decision': decision,
      'final_marks': finalMarks ?? sub['ai_suggested_marks'] ?? 0,
      'feedback': feedback,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.statusCode == 200 ? 'Marking decision: $decision' : 'Failed to save marking',
          ),
        ),
      );
      if (_currentIndex < widget.submissions.length - 1) {
        setState(() => _currentIndex++);
      }
    }
  }

  void _showModifyDialog(dynamic sub) {
    final marksCtrl = TextEditingController(
      text: (sub['ai_suggested_marks'] ?? '').toString(),
    );
    final feedbackCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modify Mark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: marksCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Final Marks'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Feedback'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitDecision(
                'modify',
                finalMarks: int.tryParse(marksCtrl.text),
                feedback: feedbackCtrl.text,
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
