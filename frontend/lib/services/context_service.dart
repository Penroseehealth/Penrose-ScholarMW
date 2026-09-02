import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// Structured workspace state sent to the backend on every interaction.
/// Represents what the student is currently viewing/doing in the app.
class WorkspaceState {
  final String screen;
  final String subject;
  final String syllabus;
  final String topic;
  final String subtopic;
  final String currentObjective;
  final String activeLesson;
  final String activeContent;
  final String selectedText;
  final String activeVisualId;
  final String activeVisualType;
  final String activeVisualElement;
  final String activeQuestionId;
  final String currentPage;

  const WorkspaceState({
    this.screen = '',
    this.subject = '',
    this.syllabus = '',
    this.topic = '',
    this.subtopic = '',
    this.currentObjective = '',
    this.activeLesson = '',
    this.activeContent = '',
    this.selectedText = '',
    this.activeVisualId = '',
    this.activeVisualType = '',
    this.activeVisualElement = '',
    this.activeQuestionId = '',
    this.currentPage = '',
  });

  WorkspaceState copyWith({
    String? screen,
    String? subject,
    String? syllabus,
    String? topic,
    String? subtopic,
    String? currentObjective,
    String? activeLesson,
    String? activeContent,
    String? selectedText,
    String? activeVisualId,
    String? activeVisualType,
    String? activeVisualElement,
    String? activeQuestionId,
    String? currentPage,
  }) {
    return WorkspaceState(
      screen: screen ?? this.screen,
      subject: subject ?? this.subject,
      syllabus: syllabus ?? this.syllabus,
      topic: topic ?? this.topic,
      subtopic: subtopic ?? this.subtopic,
      currentObjective: currentObjective ?? this.currentObjective,
      activeLesson: activeLesson ?? this.activeLesson,
      activeContent: activeContent ?? this.activeContent,
      selectedText: selectedText ?? this.selectedText,
      activeVisualId: activeVisualId ?? this.activeVisualId,
      activeVisualType: activeVisualType ?? this.activeVisualType,
      activeVisualElement: activeVisualElement ?? this.activeVisualElement,
      activeQuestionId: activeQuestionId ?? this.activeQuestionId,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  Map<String, dynamic> toJson() => {
        if (screen.isNotEmpty) 'screen': screen,
        if (subject.isNotEmpty) 'subject': subject,
        if (syllabus.isNotEmpty) 'syllabus': syllabus,
        if (topic.isNotEmpty) 'topic': topic,
        if (subtopic.isNotEmpty) 'subtopic': subtopic,
        if (currentObjective.isNotEmpty) 'current_objective': currentObjective,
        if (activeLesson.isNotEmpty) 'active_lesson': activeLesson,
        if (activeContent.isNotEmpty) 'active_content': activeContent,
        if (selectedText.isNotEmpty) 'selected_text': selectedText,
        if (activeVisualId.isNotEmpty) 'active_visual_id': activeVisualId,
        if (activeVisualType.isNotEmpty) 'active_visual_type': activeVisualType,
        if (activeVisualElement.isNotEmpty) 'active_visual_element': activeVisualElement,
        if (activeQuestionId.isNotEmpty) 'active_question_id': activeQuestionId,
        if (currentPage.isNotEmpty) 'current_page': currentPage,
      };

  bool get isEmpty =>
      screen.isEmpty && subject.isEmpty && topic.isEmpty && selectedText.isEmpty && activeVisualId.isEmpty;
}

/// Intent classification result from the backend.
class ClassifiedIntent {
  final String action;
  final String target;
  final String responseMode;
  final bool isFollowup;
  final bool isVisualRequest;
  final bool isAudioRequest;
  final bool isQuizRequest;
  final bool isTeachingMode;
  final bool isInterrupt;
  final double confidence;

  const ClassifiedIntent({
    required this.action,
    required this.target,
    required this.responseMode,
    required this.isFollowup,
    required this.isVisualRequest,
    required this.isAudioRequest,
    required this.isQuizRequest,
    required this.isTeachingMode,
    required this.isInterrupt,
    required this.confidence,
  });

  factory ClassifiedIntent.fromJson(Map<String, dynamic> json) {
    return ClassifiedIntent(
      action: json['action'] ?? 'explain',
      target: json['target'] ?? '',
      responseMode: json['response_mode'] ?? 'text',
      isFollowup: json['is_followup'] ?? false,
      isVisualRequest: json['is_visual_request'] ?? false,
      isAudioRequest: json['is_audio_request'] ?? false,
      isQuizRequest: json['is_quiz_request'] ?? false,
      isTeachingMode: json['is_teaching_mode'] ?? false,
      isInterrupt: json['is_interrupt'] ?? false,
      confidence: (json['confidence'] ?? 0.7).toDouble(),
    );
  }
}

/// Manages live learning context across the application.
/// Tracks what the student is viewing and sends workspace state to backend.
class ContextService extends ChangeNotifier {
  final ApiService _api;

  WorkspaceState _currentWorkspace = const WorkspaceState();
  ClassifiedIntent? _lastIntent;
  int? _activeSessionId;
  bool _isSending = false;

  WorkspaceState get currentWorkspace => _currentWorkspace;
  ClassifiedIntent? get lastIntent => _lastIntent;
  int? get activeSessionId => _activeSessionId;
  bool get isSending => _isSending;

  ContextService({ApiService? api}) : _api = api ?? ApiService();

  /// Set the active session ID (called when a chat session starts).
  void setActiveSession(int? sessionId) {
    _activeSessionId = sessionId;
    notifyListeners();
  }

  /// Update workspace state — call this whenever the student navigates
  /// or the active content changes.
  void updateWorkspace(WorkspaceState workspace) {
    _currentWorkspace = workspace;
    _syncWorkspaceToBackend();
    notifyListeners();
  }

  /// Partial update — only override the fields that changed.
  void updateWorkspacePartial({
    String? screen,
    String? subject,
    String? syllabus,
    String? topic,
    String? subtopic,
    String? currentObjective,
    String? activeLesson,
    String? activeContent,
    String? selectedText,
    String? activeVisualId,
    String? activeVisualType,
    String? activeVisualElement,
    String? activeQuestionId,
    String? currentPage,
  }) {
    _currentWorkspace = _currentWorkspace.copyWith(
      screen: screen,
      subject: subject,
      syllabus: syllabus,
      topic: topic,
      subtopic: subtopic,
      currentObjective: currentObjective,
      activeLesson: activeLesson,
      activeContent: activeContent,
      selectedText: selectedText,
      activeVisualId: activeVisualId,
      activeVisualType: activeVisualType,
      activeVisualElement: activeVisualElement,
      activeQuestionId: activeQuestionId,
      currentPage: currentPage,
    );
    _syncWorkspaceToBackend();
    notifyListeners();
  }

  /// Record that the student selected text on screen.
  void selectText(String text) {
    _currentWorkspace = _currentWorkspace.copyWith(selectedText: text);
    _syncWorkspaceToBackend();
    notifyListeners();
  }

  /// Record that the student tapped on a visual element.
  void selectVisualElement({
    required String visualId,
    required String visualType,
    required String element,
    String elementLabel = '',
    String elementDescription = '',
  }) {
    _currentWorkspace = _currentWorkspace.copyWith(
      activeVisualId: visualId,
      activeVisualType: visualType,
      activeVisualElement: element,
    );
    // Also send to the dedicated visual-selection endpoint
    _sendVisualSelection(
      visualId: visualId,
      visualType: visualType,
      element: element,
      elementLabel: elementLabel,
      elementDescription: elementDescription,
    );
    notifyListeners();
  }

  /// Clear the selected text / visual element (e.g. after sending a message).
  void clearTransientSelections() {
    _currentWorkspace = _currentWorkspace.copyWith(
      selectedText: '',
      activeVisualElement: '',
    );
    notifyListeners();
  }

  /// Classify the user's message intent before sending to AI.
  Future<ClassifiedIntent> classifyIntent(String message) async {
    if (_activeSessionId == null) {
      return const ClassifiedIntent(
        action: 'explain',
        target: '',
        responseMode: 'text',
        isFollowup: false,
        isVisualRequest: false,
        isAudioRequest: false,
        isQuizRequest: false,
        isTeachingMode: false,
        isInterrupt: false,
        confidence: 0.5,
      );
    }
    try {
      final response = await _api.post('/context/intent', body: {
        'message': message,
        'session_id': _activeSessionId,
      });
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _lastIntent = ClassifiedIntent.fromJson(json);
      notifyListeners();
      return _lastIntent!;
    } catch (e) {
      debugPrint('Intent classification failed: $e');
      return const ClassifiedIntent(
        action: 'explain',
        target: '',
        responseMode: 'text',
        isFollowup: false,
        isVisualRequest: false,
        isAudioRequest: false,
        isQuizRequest: false,
        isTeachingMode: false,
        isInterrupt: false,
        confidence: 0.5,
      );
    }
  }

  /// Explicitly set the response mode for the session.
  Future<void> setResponseMode(String mode) async {
    if (_activeSessionId == null) return;
    try {
      await _api.post('/context/response-mode', body: {
        'session_id': _activeSessionId,
        'mode': mode,
      });
    } catch (e) {
      debugPrint('Set response mode failed: $e');
    }
  }

  // -- Private helpers --

  void _syncWorkspaceToBackend() {
    if (_activeSessionId == null || _isSending) return;
    _isSending = true;
    _api
        .post('/context/workspace', body: {
          'session_id': _activeSessionId,
          'workspace': _currentWorkspace.toJson(),
        })
        .then((_) {})
        .catchError((e) {
          debugPrint('Workspace sync failed: $e');
        })
        .whenComplete(() {
          _isSending = false;
        });
  }

  void _sendVisualSelection({
    required String visualId,
    required String visualType,
    required String element,
    String elementLabel = '',
    String elementDescription = '',
  }) {
    if (_activeSessionId == null) return;
    _api
        .post('/context/visual-selection', body: {
          'session_id': _activeSessionId,
          'visual_id': visualId,
          'visual_type': visualType,
          'selected_element': element,
          'element_label': elementLabel,
          'element_description': elementDescription,
        })
        .then((_) {})
        .catchError((e) {
          debugPrint('Visual selection sync failed: $e');
        });
  }

  /// Clear context for a session (e.g. when leaving the chat).
  Future<void> clearSession(int sessionId) async {
    try {
      await _api.delete('/context/session/$sessionId');
    } catch (e) {
      debugPrint('Clear context failed: $e');
    }
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
      _currentWorkspace = const WorkspaceState();
      _lastIntent = null;
      notifyListeners();
    }
  }
}
