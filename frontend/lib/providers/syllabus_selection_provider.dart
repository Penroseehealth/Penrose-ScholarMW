import 'package:flutter/foundation.dart';

import '../services/services.dart';

class SyllabusSelectionProvider extends ChangeNotifier {
  final SyllabusService _api = SyllabusService();

  bool _initialized = false;
  bool _busy = false;
  String? _error;

  List<dynamic> _subjects = [];
  String? _subjectSlug;
  Map<String, dynamic> _subject = const {};
  List<dynamic> _forms = [];
  bool _formsTried = false;
  int? _form;
  List<dynamic> _topics = [];
  bool _topicsTried = false;
  Map<String, dynamic>? _topic;
  List<dynamic> _subtopics = [];
  bool _subtopicsTried = false;
  Map<String, dynamic>? _subtopic;
  List<dynamic> _objectives = [];
  bool _objectivesTried = false;

  bool get initialized => _initialized;
  bool get busy => _busy;
  String? get error => _error;

  List<dynamic> get subjects => _subjects;
  String? get subjectSlug => _subjectSlug;
  Map<String, dynamic> get subject => _subject;
  List<dynamic> get forms => _forms;
  bool get formsTried => _formsTried;
  int? get form => _form;
  List<dynamic> get topics => _topics;
  bool get topicsTried => _topicsTried;
  Map<String, dynamic>? get topic => _topic;
  List<dynamic> get subtopics => _subtopics;
  bool get subtopicsTried => _subtopicsTried;
  Map<String, dynamic>? get subtopic => _subtopic;
  List<dynamic> get objectives => _objectives;
  bool get objectivesTried => _objectivesTried;

  bool get hasSelection => _subjectSlug != null;
  bool get hasForm => _form != null;
  bool get hasTopic => _topic != null;
  bool get hasSubtopic => _subtopic != null;

  Future<void> init() async {
    if (_initialized && _subjects.isNotEmpty) return;
    await loadSubjects();
  }

  Future<void> loadSubjects() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.getSubjects();
      _subjects = List<dynamic>.from(result);
      _initialized = true;
    } catch (e) {
      _error = 'Could not load subjects: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> selectSubject(String slug) async {
    _subjectSlug = slug;
    _subject = _subjects.firstWhere(
      (s) => (s['slug'] as String?) == slug,
      orElse: () => const {},
    );
    _form = null;
    _topic = null;
    _subtopic = null;
    _objectives = [];
    _topics = [];
    _subtopics = [];
    _forms = [];
    _formsTried = false;
    _topicsTried = false;
    _subtopicsTried = false;
    _objectivesTried = false;
    _error = null;
    await loadForms();
  }

  Future<void> loadForms() async {
    final slug = _subjectSlug;
    if (slug == null) return;
    _formsTried = true;
    _error = null;
    _busy = true;
    notifyListeners();
    try {
      final result = await _api.getForms(slug);
      _forms = List<dynamic>.from((result['forms'] as List<dynamic>?) ?? []);
    } catch (e) {
      _error = 'Could not load forms: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> selectForm(int form) async {
    final slug = _subjectSlug;
    if (slug == null) return;
    _form = form;
    _topic = null;
    _subtopic = null;
    _objectives = [];
    _topics = [];
    _subtopics = [];
    _topicsTried = false;
    _subtopicsTried = false;
    _objectivesTried = false;
    _error = null;
    await loadTopics();
  }

  Future<void> loadTopics() async {
    final slug = _subjectSlug;
    final form = _form;
    if (slug == null || form == null) return;
    _topicsTried = true;
    _error = null;
    _busy = true;
    notifyListeners();
    try {
      final result = await _api.getTopics(slug, form);
      _topics = List<dynamic>.from(result);
    } catch (e) {
      _error = 'Could not load topics: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> selectTopic(int topicId) async {
    _topic = _topics.firstWhere(
      (t) => (t['id'] as int?) == topicId,
      orElse: () => const {},
    );
    _subtopic = null;
    _objectives = [];
    _subtopics = [];
    _subtopicsTried = false;
    _objectivesTried = false;
    _error = null;
    await loadSubtopics();
  }

  Future<void> loadSubtopics() async {
    final topicId = _topic?['id'] as int?;
    if (topicId == null) return;
    _subtopicsTried = true;
    _error = null;
    _busy = true;
    notifyListeners();
    try {
      final result = await _api.getSubtopics(topicId);
      _subtopics = List<dynamic>.from(result);
    } catch (e) {
      _error = 'Could not load subtopics: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> selectSubtopic(int subtopicId) async {
    _subtopic = _subtopics.firstWhere(
      (s) => (s['id'] as int?) == subtopicId,
      orElse: () => const {},
    );
    _objectives = [];
    _objectivesTried = false;
    _error = null;
    await loadObjectives();
  }

  Future<void> loadObjectives() async {
    final subtopicId = _subtopic?['id'] as int?;
    if (subtopicId == null) return;
    _objectivesTried = true;
    _error = null;
    _busy = true;
    notifyListeners();
    try {
      final result = await _api.getObjectives(subtopicId);
      _objectives = List<dynamic>.from(result);
    } catch (e) {
      _error = 'Could not load objectives: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void reset() {
    _subjectSlug = null;
    _subject = const {};
    _form = null;
    _topic = null;
    _subtopic = null;
    _objectives = [];
    _forms = [];
    _topics = [];
    _subtopics = [];
    _formsTried = false;
    _topicsTried = false;
    _subtopicsTried = false;
    _objectivesTried = false;
    notifyListeners();
  }

  Map<String, dynamic> applyToPresentation() {
    return {
      'subject': (_subject['name'] as String?) ?? '',
      'subject_slug': _subjectSlug ?? '',
      'form': _form,
      'form_label': _form != null ? 'Form $_form' : '',
      'topic': (_topic?['title'] as String?) ?? '',
      'topic_id': _topic?['id'] as int?,
      'subtopic': (_subtopic?['title'] as String?) ?? '',
      'subtopic_id': _subtopic?['id'] as int?,
      'learning_objectives': <String>[
        for (final lo in _objectives)
          if ((lo['objective'] as String?)?.isNotEmpty ?? false) lo['objective'] as String,
      ],
    };
  }
}
