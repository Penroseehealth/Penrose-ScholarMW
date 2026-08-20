import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/stem_service.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/shimmer_loading.dart';
import 'proctor_overlay.dart';

class MockExamScreen extends StatefulWidget {
  const MockExamScreen({super.key});

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  final StemService _stemService = StemService();
  final GlobalKey<ProctorOverlayState> _proctorKey = GlobalKey();

  List<dynamic> _subjects = [];
  bool _loadingSubjects = true;

  bool _examActive = false;
  bool _examFinished = false;
  bool _loadingExam = false;

  Map<String, dynamic>? _examData;
  List<dynamic> _questions = [];
  Map<int, String> _answers = {};
  int _currentIndex = 0;
  int _timeLimitSeconds = 0;
  int _timeRemaining = 0;
  Timer? _timer;

  Map<String, dynamic>? _results;
  List<dynamic> _history = [];
  bool _loadingHistory = true;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onDetach: () {
        if (_examActive) {
          final sessionId = _examData?['exam_session_id'] ?? 0;
          _stemService.logProctorEvent('mock', sessionId, 'app_exit');
        }
      },
      onHide: () {
        if (_examActive) {
          final sessionId = _examData?['exam_session_id'] ?? 0;
          _stemService.logProctorEvent('mock', sessionId, 'app_background');
        }
      },
      onResume: () {
        if (_examActive) {
          final sessionId = _examData?['exam_session_id'] ?? 0;
          _stemService.logProctorEvent('mock', sessionId, 'app_resumed');
        }
      },
    );
    _loadSubjects();
    _loadHistory();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      final data = await _stemService.getSubjects();
      if (mounted) setState(() { _subjects = data; _loadingSubjects = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingSubjects = false; });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final data = await _stemService.getMockExamHistory();
      if (mounted) setState(() { _history = data; _loadingHistory = false; });
    } catch (e) {
      if (mounted) setState(() { _loadingHistory = false; });
    }
  }

  Future<void> _startExam(String slug) async {
    setState(() { _loadingExam = true; });
    try {
      final data = await _stemService.startMockExam(slug, numQuestions: 10);
      if (!mounted) return;
      setState(() {
        _examData = data;
        _questions = data['questions'] ?? [];
        _answers.clear();
        _currentIndex = 0;
        _timeLimitSeconds = (data['time_limit'] ?? 60) * 60;
        _timeRemaining = _timeLimitSeconds;
        _examActive = true;
        _examFinished = false;
        _results = null;
        _loadingExam = false;
      });
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() { _loadingExam = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start exam: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining <= 0) {
        timer.cancel();
        _submitExam();
        return;
      }
      if (mounted) setState(() { _timeRemaining--; });
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submitExam() async {
    _timer?.cancel();
    if (_examData == null) return;
    final sessionId = _examData!['exam_session_id'];
    final answersList = _answers.entries.map((e) => {
      'question_id': e.key,
      'answer': e.value,
    }).toList();
    try {
      final data = await _stemService.submitMockExam(sessionId, answersList);
      if (!mounted) return;
      setState(() {
        _examActive = false;
        _examFinished = true;
        _results = data;
      });
      _loadHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_examActive) {
      final sessionId = _examData?['exam_session_id'] ?? 0;
      return ProctorOverlay(
        key: _proctorKey,
        examType: 'mock',
        examId: sessionId is int ? sessionId : 0,
        active: true,
        child: _buildExamView(),
      );
    }
    if (_examFinished && _results != null) return _buildResultsView();
    return _buildSetupView();
  }

  Widget _buildSetupView() {

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
              onPressed: () => Navigator.maybePop(context),
            ),
            backgroundColor: AppColors.primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Mock Exam',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryMuted],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(Icons.timer_outlined, color: AppColors.textMuted, size: 40),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Subject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Choose a subject to start a timed mock exam', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 14),
                      if (_loadingSubjects)
                        ShimmerLoading.grid(count: 4)
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _subjects.map((s) {
                            final slug = s['subject_slug'] ?? '';
                            final name = s['name'] ?? s['title'] ?? '';
                            final color = AppColors.primary;
                            return GestureDetector(
                              onTap: _loadingExam ? null : () => _startExam(slug),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: color.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.school_outlined, color: color, size: 16),
                                    const SizedBox(width: 6),
                                    Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      if (_loadingExam) ...[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(color: AppColors.primary),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('How it works', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.timer_outlined, '10 minutes per 10 questions', AppColors.info),
                      _buildInfoRow(Icons.quiz_outlined, '10 random questions from the question bank', AppColors.teal),
                      _buildInfoRow(Icons.psychology_outlined, 'Results update your mastery and spaced repetition schedule', AppColors.lavender),
                      _buildInfoRow(Icons.check_circle_outline, 'Auto-submits when time runs out', AppColors.success),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Exam History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                if (_loadingHistory)
                  ShimmerLoading.list(count: 3)
                else if (_history.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text('No exams taken yet', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ),
                  )
                else
                  ..._history.map((h) => _buildHistoryCard(h)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> h) {
    final pct = (h['score_percentage'] as num?)?.toDouble() ?? 0;
    final color = pct >= 70 ? AppColors.success : (pct >= 50 ? Colors.amber : Colors.red.shade400);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text('${pct.round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h['subject_slug'] ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${h['correct_count']}/${h['total_questions']} correct',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            _formatDate(h['taken_at']),
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildExamView() {
    final timerColor = _timeRemaining <= 60 ? Colors.red : (_timeRemaining <= 300 ? Colors.amber : AppColors.primary);
    final question = _questions.isNotEmpty ? _questions[_currentIndex] : null;
    final total = _questions.length;
    final progress = total > 0 ? (_currentIndex + 1) / total : 0.0;
    final options = _parseOptions(question?['options']);
    final selectedAnswer = question != null ? _answers[question['id']] : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => _showQuitDialog(),
        ),
        title: Column(
          children: [
            Text(
              '${_examData?['subject']?['title'] ?? 'Exam'}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            Text(
              'Question ${_currentIndex + 1} of $total',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: timerColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, color: timerColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  _formatTime(_timeRemaining),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: timerColor),
                ),
              ],
            ),
          ),
        ],
      ),
      body: question == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 3,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGlow,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${question['difficulty'] ?? 'medium'}'.toUpperCase(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${question['marks'] ?? 1} mark${(question['marks'] ?? 1) > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          question['question_text'] ?? '',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        if (options.isNotEmpty)
                          ...options.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final option = entry.value;
                            final letter = String.fromCharCode(65 + idx);
                            final isSelected = selectedAnswer == letter;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _answers[question['id']] = letter;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary : AppColors.surfaceHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          letter,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected ? Colors.white : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                                  ],
                                ),
                              ),
                            );
                          })
                        else
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TextField(
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Type your answer here...',
                                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                border: InputBorder.none,
                              ),
                              onChanged: (val) {
                                _answers[question['id']] = val;
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _buildQuestionNav(total, question['id']),
                _buildBottomBar(total),
              ],
            ),
    );
  }

  Widget _buildQuestionNav(int total, int currentQuestionId) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        itemBuilder: (context, index) {
          final q = _questions[index];
          final isAnswered = _answers.containsKey(q['id']);
          final isCurrent = index == _currentIndex;
          return GestureDetector(
            onTap: () => setState(() { _currentIndex = index; }),
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.primary
                    : (isAnswered ? AppColors.success.withValues(alpha: 0.2) : AppColors.surfaceHighest),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrent ? AppColors.primary : (isAnswered ? AppColors.success : AppColors.border),
                ),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCurrent ? Colors.white : (isAnswered ? AppColors.success : AppColors.textMuted),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(int total) {
    final answeredCount = _answers.length;
    final allAnswered = answeredCount == total;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_currentIndex > 0)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() { _currentIndex--; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('Prev', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          if (_currentIndex > 0) const SizedBox(width: 10),
          if (_currentIndex < total - 1)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() { _currentIndex++; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Next', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          if (_currentIndex == total - 1)
            Expanded(
              child: GestureDetector(
                onTap: () => _showSubmitDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: allAnswered ? AppColors.success : Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(allAnswered ? Icons.check_circle : Icons.warning_amber_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        allAnswered ? 'Submit Exam ($answeredCount/$total)' : 'Submit ($answeredCount/$total answered)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _parseOptions(dynamic options) {
    if (options == null) return [];
    if (options is List) return options.map((e) => e.toString()).toList();
    if (options is String && options.startsWith('[')) {
      try {
        final decoded = jsonDecode(options);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  void _showQuitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Quit Exam?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Your progress will be lost if you quit now.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _timer?.cancel();
              if (_examData != null) {
                final sessionId = _examData!['exam_session_id'];
                _stemService.logProctorEvent('mock', sessionId, 'exam_exit');
              }
              Navigator.pop(ctx);
              setState(() { _examActive = false; _examFinished = false; });
            },
            child: const Text('Quit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSubmitDialog() {
    final total = _questions.length;
    final answered = _answers.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Submit Exam?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          answered < total
              ? 'You have answered $answered of $total questions. Unanswered questions will be marked as wrong.'
              : 'You have answered all $total questions. Ready to submit?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Go Back')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submitExam();
            },
            child: const Text('Submit', style: TextStyle(color: AppColors.success)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    final totalScore = _results?['total_score'] ?? 0;
    final maxScore = _results?['max_score'] ?? 1;
    final percentage = (_results?['percentage'] as num?)?.toDouble() ?? 0;
    final timeTaken = _results?['time_taken'] as int?;
    final results = _results?['results'] as List<dynamic>? ?? [];
    final color = percentage >= 70 ? AppColors.success : (percentage >= 50 ? Colors.amber : Colors.red.shade400);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
              onPressed: () => Navigator.maybePop(context),
            ),
            backgroundColor: color.withValues(alpha: 0.9),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Exam Results',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${percentage.round()}%',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Text(
                        '$totalScore / $maxScore marks',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                      if (timeTaken != null)
                        Text(
                          'Time: ${_formatTime(timeTaken)}',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard('Correct', '$totalScore', AppColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard('Wrong', '${maxScore - totalScore}', Colors.red.shade400),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard('Accuracy', '${percentage.round()}%', color),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Question Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                ...results.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  final isCorrect = r['is_correct'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isCorrect ? AppColors.success.withValues(alpha: 0.3) : Colors.red.shade300.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: isCorrect ? AppColors.success : Colors.red.shade400,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Q${idx + 1}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const Spacer(),
                            Text(
                              'Your answer: ${r['submitted_answer'] ?? 'None'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isCorrect ? AppColors.success : Colors.red.shade400,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!isCorrect && r['correct_answer'] != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Correct: ${r['correct_answer']}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                        if (r['explanation'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            r['explanation'],
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setState(() { _examActive = false; _examFinished = false; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Take Another Exam', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}
