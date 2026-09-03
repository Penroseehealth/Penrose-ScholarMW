import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_colors.dart';
import '../../providers/syllabus_selection_provider.dart';
import '../../services/export_service.dart';
import '../../services/services.dart';

class ExaminationBuilderScreen extends StatefulWidget {
  const ExaminationBuilderScreen({super.key});

  @override
  State<ExaminationBuilderScreen> createState() => _ExaminationBuilderScreenState();
}

class _ExaminationBuilderScreenState extends State<ExaminationBuilderScreen> {
  final ExaminationBuilderService _api = ExaminationBuilderService();

  int _step = 0;
  bool _busy = false;
  String? _error;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _programmeCtrl = TextEditingController();
  final TextEditingController _institutionCtrl = TextEditingController();
  final TextEditingController _lecturerCtrl = TextEditingController();
  final TextEditingController _semesterCtrl = TextEditingController();
  final TextEditingController _yearCtrl = TextEditingController();
  final TextEditingController _objectiveCtrl = TextEditingController();
  final TextEditingController _newQTextCtrl = TextEditingController();
  final TextEditingController _newAnsCtrl = TextEditingController();

  String _examType = 'final';
  int _totalMarks = 100;
  int _durationMins = 120;
  int _numQuestions = 10;
  String _difficulty = 'medium';
  String _bloomFocus = 'balanced';
  List<String> _questionTypes = const ['multiple_choice', 'short_answer'];
  bool _includeAnswers = false;

  // Professional-paper formatting (optional; drives cover/paper_options payload).
  bool _includeCover = false;
  String _paperSize = 'A4';
  String _numberingStyle = 'decimal';
  String _markStyle = '[2 marks]';
  String _answerSpace = 'standard';
  bool _showPageNumbers = true;
  bool _showTurnOver = true;
  final TextEditingController _paperNumberCtrl = TextEditingController();
  final TextEditingController _examCodeCtrl = TextEditingController();
  final TextEditingController _termCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _versionCtrl = TextEditingController();

  String? _examId;
  String _title = '';
  List<Map<String, dynamic>> _questions = const [];
  List<Map<String, dynamic>> _quality = const [];
  List<Map<String, dynamic>> _qualityChecks = const [];
  List<String> _qualityWarnings = const [];
  String? _exportStatus;

  bool _showAddForm = false;
  String _newQType = 'short_answer';
  int _newMarks = 5;

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _programmeCtrl,
      _institutionCtrl,
      _lecturerCtrl,
      _semesterCtrl,
      _yearCtrl,
      _objectiveCtrl,
      _newQTextCtrl,
      _newAnsCtrl,
      _paperNumberCtrl,
      _examCodeCtrl,
      _termCtrl,
      _dateCtrl,
      _versionCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _typeLabel(String type) => switch (type) {
        'multiple_choice' => 'Multiple Choice',
        'true_false' => 'True / False',
        'matching' => 'Matching',
        'fill_in_blank' => 'Fill in the Blank',
        'short_answer' => 'Short Answer',
        'structured' => 'Structured',
        'essay' => 'Essay',
        'practical' => 'Practical',
        'calculation' => 'Calculation',
        'case_study' => 'Case Study',
        _ => type,
      };

  String get _paperTitle => _title.isNotEmpty ? _title : 'examination';

  int get _totalQuestionMarks => _questions.fold(0, (sum, q) => sum + ((q['marks'] as int?) ?? 0));

  List<String> _splitObjectives() =>
      _objectiveCtrl.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<String> _combinedObjectives(Map<String, dynamic> ctx) {
    final lo = (ctx['learning_objectives'] as List<dynamic>? ?? const []).whereType<String>().toList();
    lo.addAll(_splitObjectives());
    return lo;
  }

  Map<String, dynamic> get _paperOptionsPayload => {
        'paper_size': _paperSize,
        'numbering_style': _numberingStyle,
        'mark_style': _markStyle,
        'answer_space': _answerSpace,
        'show_page_numbers': _showPageNumbers,
        'show_turn_over': _showTurnOver,
      };

  Map<String, dynamic> get _coverPayload => {
        'paper_number': _paperNumberCtrl.text.trim(),
        'exam_code': _examCodeCtrl.text.trim(),
        'term': _termCtrl.text.trim(),
        'exam_date': _dateCtrl.text.trim(),
        'version': _versionCtrl.text.trim(),
        'institution': _institutionCtrl.text.trim(),
      };

  Map<String, dynamic> get _config {
    final s = Provider.of<SyllabusSelectionProvider>(context, listen: false);
    final ctx = s.applyToPresentation();
    return {
      'subject': (ctx['subject'] as String?) ?? '',
      'subject_slug': (ctx['subject_slug'] as String?) ?? '',
      'form': ctx['form'],
      'form_label': (ctx['form_label'] as String?) ?? '',
      'topic': (ctx['topic'] as String?) ?? '',
      'topic_id': ctx['topic_id'],
      'subtopic': (ctx['subtopic'] as String?) ?? '',
      'subtopic_id': ctx['subtopic_id'],
      'academic_level': (ctx['form_label'] as String?) ?? '',
      'programme': _programmeCtrl.text.trim(),
      'institution': _institutionCtrl.text.trim(),
      'lecturer': _lecturerCtrl.text.trim(),
      'semester': _semesterCtrl.text.trim(),
      'academic_year': _yearCtrl.text.trim(),
      'title': _titleCtrl.text.trim(),
      'exam_type': _examType,
      'total_marks': _totalMarks,
      'duration_minutes': _durationMins,
      'num_questions': _numQuestions,
      'difficulty': _difficulty,
      'bloom_focus': _bloomFocus,
      'question_types': _questionTypes,
      'include_answers': _includeAnswers,
      'learning_objectives': _combinedObjectives(ctx),
      'cover': _includeCover ? _coverPayload : const {},
      'paper_options': _paperOptionsPayload,
    };
  }

  Future<void> _generate() async {
    final s = Provider.of<SyllabusSelectionProvider>(context, listen: false);
    final hasTopic = (s.topic?['title'] as String?)?.trim().isNotEmpty ?? false;
    final hasSub = (s.subtopic?['title'] as String?)?.trim().isNotEmpty ?? false;
    if (!hasTopic && !hasSub) {
      setState(() => _error = 'Please select a Topic (or Subtopic) from the syllabus.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.generateQuestions(_config);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        _examId = data['exam_id'] as String?;
        _title = (data['title'] as String?) ?? _title;
        _questions =
            (data['questions'] as List<dynamic>? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _quality = const [];
        _qualityChecks = const [];
        _qualityWarnings = const [];
        _exportStatus = null;
        _step = 5;
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  void _editQuestion(int index, String field, dynamic value) {
    setState(() => _questions[index][field] = value);
  }

  void _editOption(Map<String, dynamic> q, int optionIndex, String value) {
    setState(() {
      final opts = List<String>.from((q['options'] as List<dynamic>?) ?? const []);
      opts[optionIndex] = value;
      q['options'] = opts;
    });
  }

  void _addOption(Map<String, dynamic> q) {
    setState(() {
      final opts = List<String>.from((q['options'] as List<dynamic>?) ?? const []);
      opts.add('New option');
      q['options'] = opts;
    });
  }

  void _removeOption(Map<String, dynamic> q, int index) {
    setState(() {
      final opts = List<String>.from((q['options'] as List<dynamic>?) ?? const []);
      opts.removeAt(index);
      q['options'] = opts;
    });
  }

  Future<void> _regenerate(int index, {String focus = ''}) async {
    final examId = _examId;
    if (examId == null) return;
    final questionId = _questions[index]['id'] as String?;
    if (questionId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.regenerateQuestion(examId, questionId, focus);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        final newQ = Map<String, dynamic>.from((data['question'] as Map).cast<String, dynamic>());
        _questions[index] = newQ;
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  Future<void> _removeQuestion(int index) async {
    final examId = _examId;
    if (examId == null) return;
    final questionId = _questions[index]['id'] as String?;
    if (questionId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.removeQuestion(examId, questionId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        _questions = List<Map<String, dynamic>>.from(_questions)..removeAt(index);
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  Future<void> _addQuestion() async {
    final examId = _examId;
    final text = _newQTextCtrl.text.trim();
    if (examId == null || text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.addQuestion(examId, {
      'question_type': _newQType,
      'question_text': text,
      'correct_answer': _newAnsCtrl.text.trim(),
      'marks': _newMarks,
      'difficulty': _difficulty == 'mixed' ? 'medium' : _difficulty,
      'bloom_level': _bloomFocus == 'balanced' ? 'Applying' : _bloomFocus,
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        final created = Map<String, dynamic>.from((res['data'] as Map).cast<String, dynamic>());
        _questions = List<Map<String, dynamic>>.from(_questions)..add(created);
        _showAddForm = false;
        _newQTextCtrl.clear();
        _newAnsCtrl.clear();
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  Future<void> _runQuality() async {
    final examId = _examId;
    if (examId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.computeQuality(examId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        _quality = data.entries
            .where((e) => e.key.endsWith('_pct') || e.key == 'question_count' || e.key == 'total_marks')
            .map((e) => {'key': e.key, 'value': e.value})
            .toList();
        _qualityChecks =
            (data['checks'] as List<dynamic>? ?? const []).map((c) => Map<String, dynamic>.from(c as Map)).toList();
        _qualityWarnings = (data['warnings'] as List<dynamic>? ?? const []).whereType<String>().toList();
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  Future<void> _export(String format) async {
    final examId = _examId;
    if (examId == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _exportStatus = null;
    });
    final res = await _api.exportExam(
      examId,
      format: format,
      includeAnswers: _includeAnswers,
      title: _paperTitle,
      cover: _includeCover ? _coverPayload : const {},
      paperOptions: _paperOptionsPayload,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        ExportService.exportBytesToFile(
          (res['data'] as List<int>),
          (res['name'] as String),
          format == 'pdf'
              ? 'application/pdf'
              : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
        _exportStatus = 'Downloaded ${res['name']} — open it to print or share.';
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final syllabus = context.watch<SyllabusSelectionProvider>();
    final busy = _busy || syllabus.busy;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: const Text('AI Examination Builder', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/lecturer'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _stepIndicator(),
            const Divider(height: 1),
            if (_error != null) _errorBanner(),
            Expanded(
              child: LoadingOverlay(
                isLoading: busy,
                child: switch (_step) {
                  0 => _subjectStep(),
                  1 => _formStep(),
                  2 => _topicStep(),
                  3 => _subtopicStep(),
                  4 => _configureStep(),
                  _ => _questionsStep(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _stepIndicator() {
    const labels = ['Subject', 'Class', 'Topic', 'Subtopic', 'Configure', 'Generate'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: List.generate(6, (i) {
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: i <= _step ? context.colors.primary : context.colors.surfaceHighest,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          color: i <= _step ? context.colors.textOnPrimary : context.colors.textSecondary)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == _step ? FontWeight.w700 : FontWeight.w400,
                          color: i <= _step ? context.colors.textPrimary : context.colors.textMuted)),
                ),
                if (i < 6) ...[
                  const SizedBox(width: 2),
                  Expanded(
                    child: Container(height: 2, color: i < _step ? context.colors.primary : context.colors.border),
                  ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      width: double.infinity,
      color: context.colors.errorMuted,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: context.colors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: TextStyle(fontSize: 12, color: context.colors.error))),
          InkWell(
            onTap: () => setState(() => _error = null),
            child: Icon(Icons.close, size: 16, color: context.colors.error),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _txtField(TextEditingController ctrl, String label, {int lines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textMuted),
        filled: true,
        fillColor: context.colors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.colors.border),
        ),
      ),
    );
  }

  Widget _syllabusDropdown<T>({
    required String label,
    required List<DropdownMenuItem<T>> items,
    required T? value,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
    String hint = '',
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textMuted),
        filled: true,
        fillColor: context.colors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.colors.border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: hint.isEmpty ? null : Text(hint, style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
          style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _loadHint(SyllabusSelectionProvider s,
      {required Future<void> Function() onRetry, required String emptyMessage}) {
    if (s.busy) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text('Loading…', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
          ],
        ),
      );
    }
    Widget child;
    if (s.error != null) {
      child = Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Icon(Icons.error_outline, size: 15, color: context.colors.error),
          Flexible(
            child: Text('${s.error}', style: TextStyle(fontSize: 12, color: context.colors.error)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    } else if (emptyMessage.isNotEmpty) {
      child = Text(emptyMessage, style: TextStyle(fontSize: 12, color: context.colors.textMuted));
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(padding: const EdgeInsets.only(top: 10), child: child);
  }

  Widget _stepNav(
      {required String nextLabel, required VoidCallback? onNext, required bool nextEnabled, bool showBack = true}) {
    return Row(
      children: [
        if (showBack) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _step > 0 ? () => setState(() => _step -= 1) : null,
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: nextEnabled ? onNext : null,
            child: Text(nextLabel),
          ),
        ),
      ],
    );
  }

  Widget _syllabusSummary(SyllabusSelectionProvider s) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Syllabus selection',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          const SizedBox(height: 8),
          _summaryRow(Icons.menu_book_outlined, 'Subject', s.subject['name'] as String? ?? ''),
          _summaryRow(Icons.school_outlined, 'Class', s.form != null ? 'Form ${s.form}' : ''),
          _summaryRow(Icons.article_outlined, 'Topic', s.topic?['title'] as String? ?? ''),
          _summaryRow(Icons.account_tree_outlined, 'Subtopic', s.subtopic?['title'] as String? ?? ''),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.colors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value, style: TextStyle(fontSize: 12, color: context.colors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _numberField(String label, int value, ValueChanged<int> onChanged) {
    return TextFormField(
      keyboardType: TextInputType.number,
      initialValue: '$value',
      style: TextStyle(color: context.colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textMuted),
        filled: true,
        fillColor: context.colors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null) setState(() => onChanged(n));
      },
    );
  }

  // ── Steps 0-4: syllabus cascade ─────────────────────────────────────────────

  Widget _subjectStep() {
    final s = context.watch<SyllabusSelectionProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 1 · Choose the subject',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Select a subject from the national syllabus. The paper will be aligned to its curriculum.',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 14),
              _syllabusDropdown<String>(
                label: 'Subject',
                hint: 'Choose a subject',
                value: s.subjectSlug,
                items: [
                  for (final sub in s.subjects)
                    DropdownMenuItem<String>(
                      value: sub['slug'] as String? ?? '',
                      child: Text(sub['name'] as String? ?? 'Unknown', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null && v.isNotEmpty) s.selectSubject(v);
                },
                enabled: !s.busy,
              ),
              if ((s.subject['description'] as String?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                Text('${s.subject['description']}',
                    style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
              ],
              if (s.subjects.isEmpty && !s.busy) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(onPressed: s.loadSubjects, child: const Text('Retry loading subjects')),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _stepNav(
          nextLabel: 'NEXT: CLASS',
          nextEnabled: s.hasSelection,
          onNext: () => setState(() => _step = 1),
        ),
      ],
    );
  }

  Widget _formStep() {
    final s = context.watch<SyllabusSelectionProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!s.busy && s.hasSelection && s.forms.isEmpty && !s.formsTried) s.loadForms();
    });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 2 · Class (Form)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Choose the class form for which this paper is set.',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 14),
              _syllabusDropdown<int>(
                label: 'Class',
                hint: s.forms.isEmpty ? 'No classes found' : 'Choose a form',
                value: s.form,
                items: [
                  for (final f in s.forms)
                    DropdownMenuItem<int>(
                      value: f['form'] as int? ?? 0,
                      child: Text(f['label'] as String? ?? 'Form ${f['form']}'),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) s.selectForm(v);
                },
                enabled: !s.busy && s.hasSelection && s.forms.isNotEmpty,
              ),
              _loadHint(
                s,
                onRetry: s.loadForms,
                emptyMessage: s.hasSelection ? 'No classes found for this subject.' : '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _stepNav(
          nextLabel: 'NEXT: TOPIC',
          nextEnabled: s.hasForm,
          onNext: () => setState(() => _step = 2),
        ),
      ],
    );
  }

  Widget _topicStep() {
    final s = context.watch<SyllabusSelectionProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!s.busy && s.hasForm && s.topics.isEmpty && !s.topicsTried) s.loadTopics();
    });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 3 · Topic',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Choose the topic the examination will cover.',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 14),
              _syllabusDropdown<int>(
                label: 'Topic',
                hint: s.topics.isEmpty ? 'No topics found' : 'Choose a topic',
                value: s.topic?['id'] as int?,
                items: [
                  for (final t in s.topics)
                    DropdownMenuItem<int>(
                      value: t['id'] as int? ?? 0,
                      child: Text(t['title'] as String? ?? 'Unknown', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) s.selectTopic(v);
                },
                enabled: !s.busy && s.hasForm && s.topics.isNotEmpty,
              ),
              _loadHint(
                s,
                onRetry: s.loadTopics,
                emptyMessage: s.hasForm ? 'No topics found for this class.' : '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _stepNav(
          nextLabel: 'NEXT: SUB-TOPIC',
          nextEnabled: s.hasTopic,
          onNext: () => setState(() => _step = 3),
        ),
      ],
    );
  }

  Widget _subtopicStep() {
    final s = context.watch<SyllabusSelectionProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!s.busy && s.hasTopic && s.subtopics.isEmpty && !s.subtopicsTried) s.loadSubtopics();
    });
    final canContinueWithout = s.hasTopic && s.subtopicsTried && s.subtopics.isEmpty && !s.busy;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 4 · Sub-topic',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Narrow the paper to a specific sub-topic for focused questions.',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 14),
              _syllabusDropdown<int>(
                label: 'Sub-topic',
                hint: s.subtopics.isEmpty ? 'No sub-topics listed' : 'Choose a sub-topic',
                value: s.subtopic?['id'] as int?,
                items: [
                  for (final st in s.subtopics)
                    DropdownMenuItem<int>(
                      value: st['id'] as int? ?? 0,
                      child: Text(st['title'] as String? ?? 'Unknown', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) s.selectSubtopic(v);
                },
                enabled: !s.busy && s.hasTopic && s.subtopics.isNotEmpty,
              ),
              _loadHint(
                s,
                onRetry: s.loadSubtopics,
                emptyMessage: s.hasTopic ? 'No sub-topics listed — you can continue with the whole topic.' : '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _stepNav(
          nextLabel: 'NEXT: CONFIGURE',
          nextEnabled: s.hasSubtopic || canContinueWithout,
          onNext: () => setState(() => _step = 4),
        ),
      ],
    );
  }

  // ── Step 4: configure ───────────────────────────────────────────────────────

  Widget _configureStep() {
    final s = context.watch<SyllabusSelectionProvider>();
    const examTypes = <String, String>{
      'final': 'Final Exam',
      'mock': 'Mock Exam',
      'practice': 'Practice Test',
      'midterm': 'Mid-Term Test',
    };
    const difficulties = <String, String>{
      'easy': 'Easy',
      'medium': 'Medium',
      'hard': 'Hard',
      'mixed': 'Mixed',
    };
    const bloomLevels = <String, String>{
      'balanced': 'Balanced',
      'remembering': 'Remembering',
      'understanding': 'Understanding',
      'applying': 'Applying',
      'analysing': 'Analysing',
      'evaluating': 'Evaluating',
      'creating': 'Creating',
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _syllabusSummary(s),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Examination paper',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 12),
              _txtField(_titleCtrl, 'Paper title (e.g. Biology Form 1 — End of Topic Test)'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _examType,
                decoration: InputDecoration(
                  labelText: 'Paper type',
                  labelStyle: TextStyle(color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  for (final entry in examTypes.entries)
                    DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) => setState(() => _examType = v ?? _examType),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _numberField('Total marks', _totalMarks, (v) => _totalMarks = v)),
                  const SizedBox(width: 12),
                  Expanded(child: _numberField('Duration (min)', _durationMins, (v) => _durationMins = v)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Question mix',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 12),
              _numberField('Number of questions', _numQuestions, (v) => _numQuestions = v),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: InputDecoration(
                  labelText: 'Difficulty',
                  labelStyle: TextStyle(color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  for (final entry in difficulties.entries)
                    DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _bloomFocus,
                decoration: InputDecoration(
                  labelText: 'Bloom\'s taxonomy focus',
                  labelStyle: TextStyle(color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  for (final entry in bloomLevels.entries)
                    DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) => setState(() => _bloomFocus = v ?? _bloomFocus),
              ),
              const SizedBox(height: 12),
              Text('Question types',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in const [
                    'multiple_choice',
                    'true_false',
                    'matching',
                    'fill_in_blank',
                    'short_answer',
                    'structured',
                    'essay',
                    'practical',
                    'calculation',
                    'case_study',
                  ])
                    ChoiceChip(
                      label: Text(_typeLabel(t)),
                      selected: _questionTypes.contains(t),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          if (!_questionTypes.contains(t)) _questionTypes = [..._questionTypes, t];
                        } else {
                          _questionTypes = _questionTypes.where((e) => e != t).toList();
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _includeAnswers,
                onChanged: (v) => setState(() => _includeAnswers = v ?? false),
                activeColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('Include marking scheme in the exported paper',
                    style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Course details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 12),
              _txtField(_programmeCtrl, 'Programme'),
              const SizedBox(height: 12),
              _txtField(_institutionCtrl, 'Institution'),
              const SizedBox(height: 12),
              _txtField(_lecturerCtrl, 'Lecturer'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _txtField(_semesterCtrl, 'Semester')),
                  const SizedBox(width: 12),
                  Expanded(child: _txtField(_yearCtrl, 'Academic year')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _paperFormattingCard(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 3),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _busy ? null : _generate,
                child: const Text('GENERATE & REVIEW'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paperFormattingCard() {
    const paperSizes = <String, String>{'A4': 'A4', 'letter': 'Letter'};
    const numberingStyles = <String, String>{
      'decimal': 'Decimal (1, 2, 3…)',
      'alphabetic': 'Alphabetic (A, B, C…)',
      'subsection': 'Subsection (1.1, 1.2…)',
      'alpha_letter': 'Letter (A, B, C)',
    };
    const markStyles = <String, String>{
      '[2 marks]': '[2 marks]',
      '[2]': '[2]',
      '(2 marks)': '(2 marks)',
      '(2)': '(2)',
    };
    const answerSpaces = <String, String>{
      'auto': 'Auto',
      'minimal': 'Minimal',
      'standard': 'Standard',
      'generous': 'Generous',
      'custom': 'Custom',
    };
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paper formatting',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          const SizedBox(height: 4),
          Text('Control how the exported paper is typeset (cover page, numbering, spacing).',
              style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _includeCover,
            onChanged: (v) => setState(() => _includeCover = v ?? false),
            activeColor: context.colors.primary,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text('Include an institution cover page',
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
          ),
          if (_includeCover) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _txtField(_paperNumberCtrl, 'Paper number (e.g. Paper 1)')),
                const SizedBox(width: 12),
                Expanded(child: _txtField(_examCodeCtrl, 'Exam code')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _txtField(_termCtrl, 'Term')),
                const SizedBox(width: 12),
                Expanded(child: _txtField(_dateCtrl, 'Date')),
              ],
            ),
            const SizedBox(height: 12),
            _txtField(_versionCtrl, 'Version (e.g. V1.0)'),
          ],
          const SizedBox(height: 12),
          _formatDropdown<String>(
            label: 'Paper size',
            value: _paperSize,
            entries: paperSizes,
            onChanged: (v) => setState(() => _paperSize = v ?? _paperSize),
          ),
          const SizedBox(height: 12),
          _formatDropdown<String>(
            label: 'Numbering style',
            value: _numberingStyle,
            entries: numberingStyles,
            onChanged: (v) => setState(() => _numberingStyle = v ?? _numberingStyle),
          ),
          const SizedBox(height: 12),
          _formatDropdown<String>(
            label: 'Mark style',
            value: _markStyle,
            entries: markStyles,
            onChanged: (v) => setState(() => _markStyle = v ?? _markStyle),
          ),
          const SizedBox(height: 12),
          _formatDropdown<String>(
            label: 'Answer space',
            value: _answerSpace,
            entries: answerSpaces,
            onChanged: (v) => setState(() => _answerSpace = v ?? _answerSpace),
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            value: _showPageNumbers,
            onChanged: (v) => setState(() => _showPageNumbers = v ?? true),
            activeColor: context.colors.primary,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text('Show "Page X of Y" on content pages',
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
          ),
          CheckboxListTile(
            value: _showTurnOver,
            onChanged: (v) => setState(() => _showTurnOver = v ?? true),
            activeColor: context.colors.primary,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title:
                Text('Show "TURN OVER" guidance', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _formatDropdown<T>({
    required String label,
    required T value,
    required Map<String, String> entries,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.colors.textMuted),
        filled: true,
        fillColor: context.colors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        for (final entry in entries.entries) DropdownMenuItem<T>(value: entry.key as T, child: Text(entry.value)),
      ],
      onChanged: onChanged,
    );
  }

  // ── Step 5: review questions, quality, export ───────────────────────────────

  Widget _questionsStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_exportStatus != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.successMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: context.colors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_exportStatus!, style: TextStyle(fontSize: 12, color: context.colors.success)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_paperTitle,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                '${_questions.length} questions · ${_totalQuestionMarks} marks · ${_durationMins} minutes',
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
              const SizedBox(height: 10),
              Text('Editable questions — tap any field to revise before exporting.',
                  style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(_questions.length, (i) => _questionEditor(i)),
        const SizedBox(height: 6),
        if (_showAddForm) _addQuestionCard(),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => setState(() => _showAddForm = !_showAddForm),
          icon: Icon(_showAddForm ? Icons.close : Icons.add, size: 18),
          label: Text(_showAddForm ? 'Cancel adding question' : 'Add a question manually'),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Academic quality check',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 8),
              if (_quality.isNotEmpty) ...[
                ..._quality.map((q) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(q['key'], style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                          ),
                          Text('${q['value']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
                if (_qualityChecks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ..._qualityChecks.map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              (c['passed'] == true) ? Icons.check_circle_outline : Icons.error_outline,
                              size: 16,
                              color: (c['passed'] == true) ? context.colors.success : context.colors.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('${c['label']}',
                                  style: TextStyle(fontSize: 12, color: context.colors.textPrimary)),
                            ),
                          ],
                        ),
                      )),
                ],
                if (_qualityWarnings.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ..._qualityWarnings.map((w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: context.colors.warning),
                            const SizedBox(width: 6),
                            Expanded(child: Text(w, style: TextStyle(fontSize: 12, color: context.colors.warning))),
                          ],
                        ),
                      )),
                ],
              ] else
                Text('Run the quality check to validate syllabus coverage, answer completeness and Bloom coverage.',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _runQuality,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Quality check'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export paper',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _includeAnswers,
                onChanged: (v) => setState(() => _includeAnswers = v ?? false),
                activeColor: context.colors.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('Include marking scheme / answer key',
                    style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _export('docx'),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('DOWNLOAD DOCX'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _export('pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('DOWNLOAD PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _step = 4),
          child: const Text('Back to configure'),
        ),
      ],
    );
  }

  Widget _questionEditor(int index) {
    final q = _questions[index];
    final type = (q['question_type'] as String?) ?? 'short_answer';
    final needsOptions = type == 'multiple_choice' || type == 'true_false';
    final needsRubric = type == 'essay' || type == 'short_answer';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Q${index + 1}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.primary)),
              ),
              Text('${q['marks'] ?? 1} marks · ${q['difficulty'] ?? 'medium'} · ${q['bloom_level'] ?? ''}',
                  style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          _syllabusDropdown<String>(
            label: 'Type',
            value: type,
            items: [
              for (final t in const [
                'multiple_choice',
                'true_false',
                'matching',
                'fill_in_blank',
                'short_answer',
                'structured',
                'essay',
                'practical',
                'calculation',
                'case_study',
              ])
                DropdownMenuItem<String>(value: t, child: Text(_typeLabel(t))),
            ],
            onChanged: (v) {
              if (v != null) _editQuestion(index, 'question_type', v);
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: (q['question_text'] as String?) ?? '',
            maxLines: 3,
            style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
            decoration: const InputDecoration(isDense: true),
            onChanged: (v) => _editQuestion(index, 'question_text', v),
          ),
          const SizedBox(height: 4),
          _numberField('Marks', (q['marks'] as int?) ?? 1, (v) => _editQuestion(index, 'marks', v)),
          if (needsOptions) ...[
            const SizedBox(height: 4),
            ...((q['options'] as List<dynamic>?) ?? const []).asMap().entries.map((e) => Row(
                  children: [
                    const Icon(Icons.radio_button_unchecked, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextFormField(
                        initialValue: (e.value as String?) ?? '',
                        style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) => _editOption(q, e.key, v),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => _removeOption(q, e.key),
                    ),
                  ],
                )),
            if (type == 'multiple_choice')
              TextButton.icon(
                onPressed: () => _addOption(q),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add option'),
              ),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: (q['correct_answer'] as String?) ?? '',
              style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
              decoration: const InputDecoration(isDense: true, labelText: 'Correct answer'),
              onChanged: (v) => _editQuestion(index, 'correct_answer', v),
            ),
          ],
          if (needsRubric) ...[
            const SizedBox(height: 4),
            TextFormField(
              initialValue: (q['rubric'] as String?) ?? '',
              maxLines: 2,
              style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
              decoration: const InputDecoration(isDense: true, labelText: 'Marking rubric'),
              onChanged: (v) => _editQuestion(index, 'rubric', v),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: _busy ? null : () => _regenerate(index),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Regenerate'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : () => _removeQuestion(index),
                icon: Icon(Icons.delete_outline, size: 16, color: context.colors.error),
                label: Text('Remove', style: TextStyle(color: context.colors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addQuestionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a question',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          const SizedBox(height: 10),
          _syllabusDropdown<String>(
            label: 'Type',
            value: _newQType,
            items: [
              for (final t in const [
                'multiple_choice',
                'true_false',
                'matching',
                'fill_in_blank',
                'short_answer',
                'structured',
                'essay',
                'practical',
                'calculation',
                'case_study',
              ])
                DropdownMenuItem<String>(value: t, child: Text(_typeLabel(t))),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _newQType = v);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newQTextCtrl,
            maxLines: 3,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Question text',
              labelStyle: TextStyle(color: context.colors.textMuted),
              filled: true,
              fillColor: context.colors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newAnsCtrl,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Answer / marking note (optional)',
              labelStyle: TextStyle(color: context.colors.textMuted),
              filled: true,
              fillColor: context.colors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          _numberField('Marks', _newMarks, (v) => _newMarks = v),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _busy ? null : _addQuestion,
              child: const Text('ADD QUESTION TO PAPER'),
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: context.colors.background.withValues(alpha: 0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
