import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';
import '../../services/services.dart';

class ExaminationHall extends StatefulWidget {
  const ExaminationHall({super.key});

  @override
  State<ExaminationHall> createState() => _ExaminationHallState();
}

class _ExaminationHallState extends State<ExaminationHall> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _submissions = [];
  bool _loading = true;
  bool _loadingDetail = false;
  bool _loadingQuestions = false;
  bool _submitting = false;

  Map<String, dynamic>? _selectedExam;
  List<Map<String, dynamic>> _questions = [];
  final Map<String, String> _answers = {};
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentView = 0; // 0=list, 1=detail, 2=take exam

  @override
  void initState() {
    super.initState();
    _loadExams();
    _loadSubmissions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadExams() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/examinations/');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      setState(() {
        _exams = List<Map<String, dynamic>>.from(
          data is List ? data : (data?['items'] as Iterable<Object?>? ?? []),
        );
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load examinations: $e')),
        );
      }
    }
  }

  Future<void> _loadSubmissions() async {
    try {
      final response = await _api.get('/examinations/my-submissions');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      setState(() {
        _submissions = List<Map<String, dynamic>>.from(
          data is List ? data : (data?['items'] as Iterable<Object?>? ?? []),
        );
      });
    } catch (e) {
      // silent
    }
  }

  Future<void> _viewExamDetail(String examId) async {
    setState(() => _loadingDetail = true);
    try {
      final response = await _api.get('/examinations/$examId');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _selectedExam = body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : (body['data'][0] ?? body) as Map<String, dynamic>?;
        _loadingDetail = false;
        _currentView = 1;
      });
    } catch (e) {
      setState(() => _loadingDetail = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load exam details: $e')),
        );
      }
    }
  }

  Future<void> _startExam(String examId) async {
    setState(() => _loadingQuestions = true);
    try {
      final response = await _api.get('/examinations/$examId/questions');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      final questions = List<Map<String, dynamic>>.from(
        data is List ? data : (data?['items'] as Iterable<Object?>? ?? []),
      );
      final duration = ((_selectedExam?['duration_minutes'] ?? 60) as int) * 60;
      setState(() {
        _questions = questions;
        _answers.clear();
        _remainingSeconds = duration;
        _loadingQuestions = false;
        _currentView = 2;
      });
      _startTimer();
    } catch (e) {
      setState(() => _loadingQuestions = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load questions: $e')),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _submitExam();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submitExam() async {
    _timer?.cancel();
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final examId = _selectedExam?['id']?.toString();
      await _api.post('/examinations/submit', body: {
        'examination_id': examId,
        'answers': _answers.entries.map((e) => {'question_id': e.key, 'answer': e.value}).toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exam submitted successfully!')),
        );
        setState(() => _currentView = 0);
        _loadExams();
        _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit exam: $e')),
        );
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return context.colors.success;
      case 'upcoming':
        return context.colors.info;
      case 'completed':
      case 'closed':
        return context.colors.textSecondary;
      case 'in_progress':
        return context.colors.warning;
      default:
        return context.colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.surface,
          elevation: 0,
          leading: _currentView != 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _timer?.cancel();
                    setState(() => _currentView = 0);
                  },
                )
              : null,
          title: Text(
            _currentView == 2 ? 'Examination — ${_formatDuration(_remainingSeconds)}' : 'Examination Hall',
            style: TextStyle(
              color: _currentView == 2 && _remainingSeconds < 300 ? context.colors.error : context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (_currentView == 0)
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: _showSubmissionsSheet,
              ),
            if (_currentView == 0)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _loadExams();
                  _loadSubmissions();
                },
              ),
          ],
        ),
        body: _buildBody(),
      );

  Widget _buildBody() {
    if (_currentView == 2) return _buildExamView();
    if (_loading) return _buildSpinner();
    if (_currentView == 1) return _buildDetailView();
    return _buildExamList();
  }

  Widget _buildSpinner() => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );

  Widget _buildEmptyState(String title, String subtitle, IconData icon) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: context.colors.textSecondary),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: context.colors.textSecondary)),
            ],
          ),
        ),
      );

  Widget _buildExamList() {
    if (_exams.isEmpty) {
      return _buildEmptyState(
        'No Examinations',
        'No examinations are available at this time. Check back later.',
        Icons.quiz_outlined,
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadExams();
        await _loadSubmissions();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _exams.length,
        itemBuilder: (context, index) => _buildExamCard(_exams[index]),
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final status = (exam['status'] ?? 'unknown').toString();
    final title = (exam['title'] ?? exam['name'] ?? 'Untitled Exam') as String;
    final duration = exam['duration_minutes'] ?? exam['duration'] ?? '--';
    final totalMarks = exam['total_marks'] ?? exam['marks'] ?? '--';
    final questionCount = exam['question_count'] ?? exam['questions_count'] ?? '--';
    final canTake = status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: context.colors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewExamDetail(exam['id'].toString()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoChip(Icons.timer_outlined, '$duration min'),
                  const SizedBox(width: 12),
                  _infoChip(Icons.grade_outlined, '$totalMarks marks'),
                  const SizedBox(width: 12),
                  _infoChip(Icons.help_outline, '$questionCount questions'),
                ],
              ),
              const SizedBox(height: 12),
              if (canTake)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _viewExamDetail(exam['id'].toString()),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start Exam'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: context.colors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.colors.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
        ],
      );

  Widget _buildDetailView() {
    if (_loadingDetail) return _buildSpinner();
    if (_selectedExam == null) return _buildEmptyState('Error', 'Exam not found', Icons.error_outline);

    final exam = _selectedExam!;
    final title = (exam['title'] ?? exam['name'] ?? 'Untitled') as String;
    final description = (exam['description'] ?? '') as String;
    final duration = exam['duration_minutes'] ?? '--';
    final totalMarks = exam['total_marks'] ?? exam['marks'] ?? '--';
    final instructions = exam['instructions'] ?? 'No special instructions.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(description, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: context.colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statColumn(Icons.timer_outlined, '$duration', 'Minutes'),
                  _statColumn(Icons.grade_outlined, '$totalMarks', 'Total Marks'),
                  _statColumn(Icons.quiz_outlined, '${_selectedExam?['question_count'] ?? '--'}', 'Questions'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: context.colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(instructions.toString(), style: TextStyle(fontSize: 14, color: context.colors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadingQuestions ? null : () => _startExam(exam['id'].toString()),
              icon: _loadingQuestions
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow),
              label: Text(_loadingQuestions ? 'Loading...' : 'Begin Examination'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: context.colors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(IconData icon, String value, String label) => Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
          Text(label, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
        ],
      );

  Widget _buildExamView() => Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: _remainingSeconds < 300 ? context.colors.error.withValues(alpha: 0.1) : context.colors.surface,
            child: Row(
              children: [
                Icon(Icons.timer, color: _remainingSeconds < 300 ? context.colors.error : AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_remainingSeconds),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds < 300 ? context.colors.error : context.colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_answers.length}/${_questions.length} answered',
                  style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _questions.isEmpty
                ? _buildEmptyState('No Questions', 'This exam has no questions yet', Icons.help_outline)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) => _buildQuestionCard(index),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _showSubmitConfirmation,
                icon: _submitting
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'Submitting...' : 'Submit Examination'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: context.colors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final qId = q['id'] ?? index;
    final questionText = (q['question'] ?? q['text'] ?? 'Untitled question') as String;
    final marks = q['marks'] ?? q['points'] ?? '';
    final type = (q['type'] ?? q['question_type'] ?? 'text').toString();
    final options = List<String>.from(q['options'] as Iterable<Object?>? ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _answers[qId.toString()] != null
                      ? AppColors.primary
                      : context.colors.textSecondary.withValues(alpha: 0.2),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _answers[qId.toString()] != null ? Colors.white : context.colors.textSecondary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(questionText,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.textPrimary)),
                ),
                if (marks != '')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${marks}m',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (type == 'multiple_choice' && options.isNotEmpty)
              RadioGroup<String>(
                groupValue: _answers[qId.toString()],
                onChanged: (val) {
                  setState(() => _answers[qId.toString()] = val ?? '');
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: options
                      .map((opt) => RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(opt, style: TextStyle(fontSize: 14, color: context.colors.textPrimary)),
                            value: opt,
                            activeColor: AppColors.primary,
                          ))
                      .toList(),
                ),
              )
            else if (type == 'true_false')
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('True'),
                      selected: _answers[qId.toString()] == 'true',
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _answers[qId.toString()] == 'true' ? Colors.white : context.colors.textPrimary,
                      ),
                      onSelected: (_) {
                        setState(() => _answers[qId.toString()] = 'true');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('False'),
                      selected: _answers[qId.toString()] == 'false',
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _answers[qId.toString()] == 'false' ? Colors.white : context.colors.textPrimary,
                      ),
                      onSelected: (_) {
                        setState(() => _answers[qId.toString()] = 'false');
                      },
                    ),
                  ),
                ],
              )
            else
              TextField(
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Type your answer here...',
                  hintStyle: TextStyle(color: context.colors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  filled: true,
                  fillColor: context.colors.background,
                ),
                style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
                onChanged: (val) {
                  setState(() => _answers[qId.toString()] = val);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSubmitConfirmation() {
    final unanswered = _questions.length - _answers.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Examination'),
        content: Text(
          unanswered > 0
              ? 'You have $unanswered unanswered question(s). Are you sure you want to submit?'
              : 'You have answered all questions. Ready to submit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showSubmissionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('My Submissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            const SizedBox(height: 8),
            Expanded(
              child: _submissions.isEmpty
                  ? Center(
                      child: Text('No submissions yet', style: TextStyle(color: context.colors.textSecondary)),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: _submissions.length,
                      itemBuilder: (context, index) {
                        final sub = _submissions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: context.colors.surface,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              (sub['examination_title'] ?? sub['title'] ?? 'Examination') as String,
                              style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                            ),
                            subtitle: Text(
                              (sub['submitted_at'] ?? sub['created_at'] ?? '') as String,
                              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.colors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${sub['score'] ?? sub['grade'] ?? '--'}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.success),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
