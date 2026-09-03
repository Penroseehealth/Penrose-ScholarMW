import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/theme_colors.dart';
import '../../providers/syllabus_selection_provider.dart';
import '../../services/export_service.dart';
import '../../services/services.dart';

class LecturePresentationBuilderScreen extends StatefulWidget {
  const LecturePresentationBuilderScreen({super.key});

  @override
  State<LecturePresentationBuilderScreen> createState() => _LecturePresentationBuilderScreenState();
}

class _LecturePresentationBuilderScreenState extends State<LecturePresentationBuilderScreen> {
  final PresentationBuilderService _api = PresentationBuilderService();

  int _step = 0;
  int _genPhase = 0; // within Generate step: 0 = outline, 1 = slides review
  bool _busy = false;
  String? _error;

  // Course details
  final _codeCtrl = TextEditingController();
  final _programmeCtrl = TextEditingController();
  final _institutionCtrl = TextEditingController();
  final _lecturerCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _objectiveCtrl = TextEditingController();
  String _uploadedText = '';
  final List<Map<String, dynamic>> _uploads = [];
  int _slideCount = 10;
  bool _autoSlideCount = false;

  // Design
  String _presentationType = 'Lecture Presentation';
  String _template = 'Minimal Academic';
  String _bodyFont = 'Calibri';
  String _citationStyle = 'APA 7';
  int _bodySize = 24;
  int _headingSize = 34;
  int _maxBullets = 5;
  int _maxLines = 6;
  int _columns = 1;
  bool _webResearch = false;

  // Outline + slides
  List<dynamic> _outline = [];
  List<Map<String, dynamic>> _outlineWarnings = [];
  List<Map<String, dynamic>> _slides = [];
  List<Map<String, dynamic>> _quality = [];
  String? _exportStatus;

  @override
  void dispose() {
    for (final c in [
      _codeCtrl,
      _programmeCtrl,
      _institutionCtrl,
      _lecturerCtrl,
      _semesterCtrl,
      _yearCtrl,
      _objectiveCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _splitObjectives() {
    return _objectiveCtrl.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<String> _combinedObjectives(Map<String, dynamic> ctx) {
    final lo = (ctx['learning_objectives'] as List<dynamic>? ?? const []).whereType<String>().toList();
    lo.addAll(_splitObjectives());
    return lo;
  }

  Map<String, dynamic> get _config {
    final s = Provider.of<SyllabusSelectionProvider>(context, listen: false);
    final ctx = s.applyToPresentation();
    return {
      'course': (ctx['subject'] as String?) ?? '',
      'course_code': _codeCtrl.text.trim(),
      'topic': (ctx['topic'] as String?) ?? '',
      'subtopic': (ctx['subtopic'] as String?) ?? '',
      'academic_level': (ctx['form_label'] as String?) ?? '',
      'programme': _programmeCtrl.text.trim(),
      'institution': _institutionCtrl.text.trim(),
      'lecturer': _lecturerCtrl.text.trim(),
      'semester': _semesterCtrl.text.trim(),
      'academic_year': _yearCtrl.text.trim(),
      'learning_objectives': _combinedObjectives(ctx),
      'uploaded_text': _uploadedText,
      'vault_doc_ids': <int>[],
      'slide_count': _slideCount,
      'auto_slide_count': _autoSlideCount,
      'presentation_type': _presentationType,
      'template': _template,
      'body_font': _bodyFont,
      'heading_font': _bodyFont,
      'heading_size': _headingSize,
      'body_size': _bodySize,
      'max_lines_per_slide': _maxLines,
      'max_bullets': _maxBullets,
      'max_words_per_slide': _maxBullets * _maxLines,
      'columns': _columns,
      'accent_hex': '#1F4E79',
      'background_hex': '#FFFFFF',
      'text_hex': '#1A1A1A',
      'citation_style': _citationStyle,
      'web_research': _webResearch,
      'sections': <Map<String, dynamic>>[],
    };
  }

  Future<void> _pickUpload(String label) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'pptx', 'xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = file.bytes ?? await file.xFile.readAsBytes();
      final res = await _api.uploadSource(bytes, file.name, label);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        final text = (data['text'] as String?) ?? '';
        setState(() {
          _uploads.add({
            'filename': data['filename'] ?? file.name,
            'label': data['label'] ?? label,
            'size': data['size'] ?? 0,
          });
          _uploadedText = '$_uploadedText\n[FILE: ${data['filename'] ?? file.name}]\n$text';
        });
      } else {
        setState(() => _error = res['error'] as String?);
      }
    } catch (e) {
      setState(() => _error = 'Could not read file: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buildOutline() async {
    final s = Provider.of<SyllabusSelectionProvider>(context, listen: false);
    final hasContent = (s.topic?['title'] as String?)?.trim().isNotEmpty ?? false;
    final hasSub = (s.subtopic?['title'] as String?)?.trim().isNotEmpty ?? false;
    if (!hasContent && !hasSub) {
      setState(() => _error = 'Please select a Topic (or Subtopic) from the syllabus.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.buildOutline(_config);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        _outline = (data['slides'] as List<dynamic>? ?? []);
        _outlineWarnings = (data['warnings'] as List<dynamic>? ?? []).map((e) => {'text': e as String}).toList();
        _genPhase = 0;
        _step = 6;
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.generateSlides(_config, _outline);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        _slides = (data['slides'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _genPhase = 1;
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  Future<void> _runQuality() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await _api.computeQuality(_config, _outline, _slides);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        _quality = (res['data'] as Map<String, dynamic>)
            .entries
            .where((e) => e.key.endsWith('_pct') || e.key == 'checks' || e.key == 'warnings')
            .map((e) => {'key': e.key, 'value': e.value})
            .toList();
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
      _exportStatus = null;
    });
    final res = await _api.exportPptx(_config, _slides);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res['success'] == true) {
        ExportService.exportBytesToFile(
          (res['data'] as List<int>),
          '${res['name']}.pptx',
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        );
        _exportStatus = 'Downloaded ${res['name']}.pptx — open it in PowerPoint to edit.';
      } else {
        _error = res['error'] as String?;
      }
    });
  }

  void _editSlide(int index, String field, dynamic value) {
    setState(() => _slides[index][field] = value);
  }

  @override
  Widget build(BuildContext context) {
    final syllabus = context.watch<SyllabusSelectionProvider>();
    final busy = _busy || syllabus.busy;
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title:
            const Text('AI Lecture Presentation Builder', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
                  4 => _objectivesStep(),
                  5 => _configureStep(),
                  _ => _genPhase == 0 ? _outlineStep() : _slidesStep(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator() {
    const labels = ['Subject', 'Class', 'Topic', 'Subtopic', 'Objectives', 'Configure', 'Generate'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: List.generate(7, (i) {
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
                    child: Container(
                      height: 2,
                      color: i < _step ? context.colors.primary : context.colors.border,
                    ),
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

  /// Automatically advances to [targetStep] once a cascade field is filled,
  /// so users don't need to press Next on the syllabus steps.
  void _autoAdvance(int targetStep) {
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted && _step == targetStep - 1) setState(() => _step = targetStep);
    });
  }

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
              Text('Select a subject from the national syllabus. The presentation will be aligned to its curriculum.',
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
                  if (v != null && v.isNotEmpty) {
                    s.selectSubject(v);
                    _autoAdvance(1);
                  }
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
                  child: OutlinedButton(
                    onPressed: s.loadSubjects,
                    child: const Text('Retry loading subjects'),
                  ),
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
              Text('${s.subject['name'] ?? 'Selected subject'} — choose the class level for this lecture.',
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
                  if (v != null) {
                    s.selectForm(v);
                    _autoAdvance(2);
                  }
                },
                enabled: !s.busy && s.hasSelection && s.forms.isNotEmpty,
              ),
              _loadHint(s, onRetry: s.loadForms, emptyMessage: 'No class levels are available for this subject.'),
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
              Text('${s.subject['name'] ?? ''} · Form ${s.form ?? ''} — choose a topic from the syllabus.',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 14),
              _syllabusDropdown<int>(
                label: 'Topic',
                hint: s.topics.isEmpty ? 'No topics found' : 'Choose a topic',
                value: s.topic?['id'] as int?,
                items: [
                  for (final t in s.topics)
                    DropdownMenuItem<int>(value: t['id'] as int? ?? 0, child: Text(t['title'] as String? ?? 'Unknown')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    s.selectTopic(v);
                    _autoAdvance(3);
                  }
                },
                enabled: !s.busy && s.hasForm && s.topics.isNotEmpty,
              ),
              _loadHint(s, onRetry: s.loadTopics, emptyMessage: 'No topics are listed for this class level.'),
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
              Text('${s.topic?['title'] ?? 'Selected topic'} — narrow the lecture to a sub-topic (optional).',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 14),
              _syllabusDropdown<int>(
                label: 'Subtopic',
                hint: s.subtopics.isEmpty ? 'No sub-topics listed' : 'Choose a sub-topic',
                value: s.subtopic?['id'] as int?,
                items: [
                  for (final st in s.subtopics)
                    DropdownMenuItem<int>(
                        value: st['id'] as int? ?? 0, child: Text(st['title'] as String? ?? 'Unknown')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    s.selectSubtopic(v);
                    _autoAdvance(4);
                  }
                },
                enabled: !s.busy && s.hasTopic && s.subtopics.isNotEmpty,
              ),
              if (canContinueWithout) ...[
                const SizedBox(height: 10),
                Text('This topic has no sub-topics in the syllabus. You can continue with the topic as-is.',
                    style: TextStyle(fontSize: 12, color: context.colors.warning)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _stepNav(
          nextLabel: 'NEXT: OBJECTIVES',
          nextEnabled: s.hasSubtopic || canContinueWithout,
          onNext: () => setState(() => _step = 4),
        ),
      ],
    );
  }

  Widget _objectivesStep() {
    final s = context.watch<SyllabusSelectionProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!s.busy && s.hasSubtopic && s.objectives.isEmpty && !s.objectivesTried) s.loadObjectives();
    });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Step 5 · Learning objectives',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                  'Review the syllabus objectives for "${s.subtopic?['title'] ?? s.topic?['title'] ?? ''}". '
                  'These will guide the AI presentation.',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 12),
              if (s.objectives.isEmpty && !s.busy) _loadHint(s, onRetry: s.loadObjectives, emptyMessage: ''),
              if (s.objectives.isEmpty)
                Text('No learning objectives found for this selection.',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted))
              else
                ...s.objectives.asMap().entries.map((e) {
                  final lo = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: context.colors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.key + 1}. ${lo['objective']}',
                                style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
                              ),
                              if ((lo['cognitive_level'] as String?)?.isNotEmpty ?? false)
                                Text('• ${lo['cognitive_level']}',
                                    style: TextStyle(fontSize: 11, color: context.colors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 10),
              _txtField(_objectiveCtrl, 'Additional objectives (one per line, optional)', lines: 3),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _stepNav(
          nextLabel: 'NEXT: CONFIGURE',
          nextEnabled: true,
          onNext: () => setState(() => _step = 5),
        ),
      ],
    );
  }

  Widget _configureStep() {
    final s = context.watch<SyllabusSelectionProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _syllabusSummary(s),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Presentation type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _presentationType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  'Lecture Presentation',
                  'Seminar',
                  'Tutorial',
                  'Practical Demonstration',
                  'Revision Lecture',
                  'Exam Preparation',
                  'Case-Based Learning',
                  'Problem-Based Learning',
                  'Clinical Teaching',
                  'Research Presentation',
                  'Conference Presentation',
                  'Student Presentation',
                  'Laboratory Practical',
                  'Mixed Mode',
                ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _presentationType = v ?? _presentationType),
              ),
              const SizedBox(height: 16),
              const Text('Design template', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _template,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  'Minimal Academic',
                  'Modern University',
                  'Medical/Health Sciences',
                  'STEM',
                  'Biology',
                  'Chemistry',
                  'Physics',
                  'Mathematics',
                  'Public Health',
                  'Clinical',
                  'Research',
                  'Corporate Academic',
                  'Dark Professional',
                  'Light Professional',
                  'Institutional',
                ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _template = v ?? _template),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Typography', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _bodyFont,
                decoration: InputDecoration(
                  labelText: 'Body / heading font',
                  filled: true,
                  fillColor: context.colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  'Calibri',
                  'Arial',
                  'Times New Roman',
                  'Aptos',
                  'Helvetica',
                  'Georgia',
                  'Verdana',
                  'Tahoma'
                ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _bodyFont = v ?? _bodyFont),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _numberField('Body size (pt)', _bodySize, (v) => _bodySize = v)),
                const SizedBox(width: 10),
                Expanded(child: _numberField('Heading size (pt)', _headingSize, (v) => _headingSize = v)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _numberField('Max lines/slide', _maxLines, (v) => _maxLines = v)),
                const SizedBox(width: 10),
                Expanded(child: _numberField('Max bullets', _maxBullets, (v) => _maxBullets = v)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Columns: ', style: TextStyle(fontSize: 13)),
                ...const [1, 2, 3].map((n) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$n'),
                        selected: _columns == n,
                        onSelected: (_) => setState(() => _columns = n),
                      ),
                    )),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Citations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _citationStyle,
                decoration: InputDecoration(
                  labelText: 'Citation style',
                  filled: true,
                  fillColor: context.colors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const ['APA 7', 'Vancouver', 'Harvard', 'IEEE', 'MLA', 'Custom']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _citationStyle = v ?? _citationStyle),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Checkbox(
                  value: _webResearch,
                  onChanged: (v) => setState(() => _webResearch = v ?? false),
                  activeColor: context.colors.primary,
                ),
                const Expanded(
                    child: Text('Enable web research (supplement when needed)', style: TextStyle(fontSize: 13))),
              ]),
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
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _txtField(_programmeCtrl, 'Programme')),
                const SizedBox(width: 10),
                SizedBox(width: 110, child: _txtField(_codeCtrl, 'Course code')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _txtField(_institutionCtrl, 'Institution')),
                const SizedBox(width: 10),
                Expanded(child: _txtField(_lecturerCtrl, 'Lecturer')),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _txtField(_semesterCtrl, 'Semester')),
                const SizedBox(width: 10),
                Expanded(child: _txtField(_yearCtrl, 'Academic year')),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Source material (priority: syllabus > notes > uploads)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _uploadChip(Icons.school_outlined, 'Syllabus', 'syllabus'),
                  _uploadChip(Icons.notes_rounded, 'Notes', 'notes'),
                  _uploadChip(Icons.menu_book_rounded, 'Textbook', 'textbook'),
                  _uploadChip(Icons.folder_copy_outlined, 'Reference', 'reference'),
                ],
              ),
              if (_uploads.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._uploads.map((u) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined, size: 20),
                      title: Text(u['filename'], style: TextStyle(fontSize: 13, color: context.colors.textPrimary)),
                      subtitle: Text('${u['label']}  •  ${u['size']} B',
                          style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                      trailing: InkWell(
                        onTap: () => setState(() => _uploads.remove(u)),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Presentation length',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 12),
              Row(children: [
                Checkbox(
                  value: _autoSlideCount,
                  onChanged: (v) => setState(() => _autoSlideCount = v ?? false),
                  activeColor: context.colors.primary,
                ),
                const Text('AI determine optimal slide count', style: TextStyle(fontSize: 13)),
              ]),
              if (!_autoSlideCount) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 10, 15, 20, 25, 30, 40, 50]
                      .map((n) => ChoiceChip(
                            label: Text('$n'),
                            selected: _slideCount == n,
                            onSelected: (_) => setState(() => _slideCount = n),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 4),
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
              onPressed: _busy ? null : _buildOutline,
              child: const Text('GENERATE OUTLINE'),
            ),
          ),
        ]),
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
          _summaryRow(Icons.checklist_rounded, 'Objectives', '${s.objectives.length} syllabus objectives'),
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

  Widget _uploadChip(IconData icon, String label, String key) {
    return InkWell(
      onTap: _busy ? null : () => _pickUpload(key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(10),
          color: context.colors.background,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: context.colors.primary),
            const SizedBox(width: 6),
            Text('+ $label', style: TextStyle(fontSize: 12, color: context.colors.textPrimary)),
          ],
        ),
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

  Widget _outlineStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Presentation outline — ${_outline.length} slides',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Approve the outline before generating the full presentation. You can edit slide titles below.',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 12),
              if (_outlineWarnings.isNotEmpty)
                ..._outlineWarnings.map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: context.colors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(w['text'], style: TextStyle(fontSize: 12, color: context.colors.warning))),
                        ],
                      ),
                    )),
              ...List.generate(_outline.length, (i) {
                final sl = _outline[i];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: context.colors.primaryMuted,
                      child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: context.colors.primary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: (sl['title'] as String?) ?? '',
                        style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Slide ${i + 1} title',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: context.colors.textMuted),
                        ),
                        onChanged: (v) => _outline[i]['title'] = v,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 5),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _buildOutline,
              child: const Text('Regenerate outline'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
              onPressed: _busy ? null : _generate,
              child: const Text('APPROVE & GENERATE'),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _slidesStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_exportStatus != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.successMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.check_circle, color: context.colors.success, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_exportStatus!, style: TextStyle(fontSize: 12, color: context.colors.success))),
            ]),
          ),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editable slides — ${_slides.length}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Review and edit each slide. speaker notes are included in the exported file.',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              const SizedBox(height: 12),
              ...List.generate(_slides.length, (i) => _slideEditor(i)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Academic quality check',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 10),
              if (_quality.isNotEmpty)
                ..._quality.map((q) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(
                            child: Text(q['key'], style: TextStyle(fontSize: 12, color: context.colors.textSecondary))),
                        Text('${q['value']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ))
              else
                Text('Run the quality check to validate syllabus coverage, citations, density and accessibility.',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => setState(() => _genPhase = 0),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to outline'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _runQuality,
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: const Text('Quality check'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
              onPressed: _busy ? null : _export,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('DOWNLOAD PPTX'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _slideEditor(int index) {
    final s = _slides[index];
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
          Text('Slide ${index + 1}  •  ${s['slide_type'] ?? 'content'}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.primary)),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: (s['title'] as String?) ?? '',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
            decoration: const InputDecoration(isDense: true),
            onChanged: (v) => _editSlide(index, 'title', v),
          ),
          const SizedBox(height: 6),
          ...((s['bullets'] as List<dynamic>?) ?? []).asMap().entries.map((e) {
            return TextFormField(
              initialValue: (e.value as String?) ?? '',
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) {
                final b = (s['bullets'] as List<dynamic>? ?? []);
                b[e.key] = v;
                _editSlide(index, 'bullets', b);
              },
            );
          }),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: (s['speaker_notes'] as String?) ?? '',
            maxLines: 3,
            style: TextStyle(fontSize: 11, color: context.colors.textMuted),
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Speaker notes',
            ),
            onChanged: (v) => _editSlide(index, 'speaker_notes', v),
          ),
          if ((s['citation'] as String?)?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${s['citation']}', style: TextStyle(fontSize: 10, color: context.colors.primary)),
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
            child: Container(
              color: context.colors.background.withValues(alpha: 0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
