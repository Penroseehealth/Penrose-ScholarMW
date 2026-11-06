import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// Client mirror of the backend's dual session state machine (Phase 0D §4).
///
/// Presentation lifecycle: idle → live → paused → completed.
/// AI interaction: idle → listening → awaiting_approval → responding → suspended.
///
/// The controller polls nothing: it follows persistent events from the
/// backend (`/events?after_seq=`) and applies server states from command
/// responses. A sequence gap triggers a full re-fetch — the approved
/// recovery path.
class PresentationSessionController extends ChangeNotifier {
  PresentationSessionController({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  // Session identity
  String? sessionId;
  String? roomName;
  String role = 'attendee';
  int participantId = 0;
  String? guestToken;

  // Dual state mirror
  String presState = 'idle';
  String aiState = 'idle';
  String aiPolicy = 'approval';
  String voiceOwner = 'none';
  bool recordingActive = false;

  // Content
  int currentSlideIndex = 0;
  int slideCount = 0;
  String currentSlideTitle = '';

  // Queue
  final List<Map<String, dynamic>> questions = [];
  final List<Map<String, dynamic>> participants = [];

  // Event tracking
  int lastSeq = 0;

  // Fallback disclosure (Phase 4): narration_fallback shows the banner.
  String? narrationFallbackReason;
  bool narrationSuspended = false;

  bool get isPresenter => role == 'presenter';
  bool get canInterrupt => role == 'presenter' || role == 'co_presenter';
  bool get isLive => presState == 'live';
  bool get isPaused => presState == 'paused';
  bool get isCompleted => presState == 'completed';

  // ------------------------------------------------------------------
  // Session bootstrap
  // ------------------------------------------------------------------

  Future<bool> createSession(String presentationId, {String policy = 'approval'}) async {
    final resp = await _api.post('/presentation-sessions/', body: {
      'presentation_id': presentationId,
      'ai_policy': policy,
    });
    if (resp.statusCode != 201) {
      debugPrint('create session failed: ${resp.statusCode} ${resp.body}');
      return false;
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    sessionId = data['session_id'] as String?;
    roomName = data['room_name'] as String?;
    role = 'presenter';
    presState = 'idle';
    return true;
  }

  Future<bool> joinAsUser({required String sessionIdOrCode, bool byCode = false}) async {
    final resp = await _api.post('/presentation-sessions/join', body: {
      if (byCode) 'join_code': sessionIdOrCode else 'session_id': sessionIdOrCode,
      'display_name': '',
    });
    if (resp.statusCode != 200) return false;
    return _applyJoin(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<bool> joinAsGuest({required String joinCode, required String displayName}) async {
    final resp = await _api.post('/presentation-sessions/join-guest', body: {
      'join_code': joinCode,
      'display_name': displayName,
    });
    if (resp.statusCode != 200) {
      debugPrint('guest join failed: ${resp.statusCode}');
      return false;
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    guestToken = data['guest_token'] as String?;
    return _applyJoin(data);
  }

  bool _applyJoin(Map<String, dynamic> data) {
    sessionId = data['session_id'] as String?;
    roomName = data['room_name'] as String?;
    role = (data['role'] as String?) ?? 'attendee';
    participantId = (data['participant_id'] as num?)?.toInt() ?? 0;
    presState = (data['pres_state'] as String?) ?? 'idle';
    aiState = (data['ai_state'] as String?) ?? 'idle';
    notifyListeners();
    return true;
  }

  /// Full state read — the recovery checkpoint.
  Future<bool> refresh() async {
    if (sessionId == null) return false;
    final resp = await _api.get('/presentation-sessions/$sessionId');
    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    presState = (data['pres_state'] as String?) ?? presState;
    aiState = (data['ai_state'] as String?) ?? aiState;
    aiPolicy = (data['ai_policy'] as String?) ?? aiPolicy;
    voiceOwner = (data['voice_owner'] as String?) ?? 'none';
    recordingActive = (data['recording_active'] as bool?) ?? false;
    questions
      ..clear()
      ..addAll(((data['questions'] as List?) ?? [])
          .whereType<Map<String, dynamic>>());
    participants
      ..clear()
      ..addAll(((data['participants'] as List?) ?? [])
          .whereType<Map<String, dynamic>>());
    notifyListeners();
    return true;
  }

  /// Replay persistent events after a gap/reconnect.
  Future<void> replayEvents({int afterSeq = 0}) async {
    if (sessionId == null) return;
    final resp = await _api
        .get('/presentation-sessions/$sessionId/events?after_seq=$afterSeq');
    if (resp.statusCode != 200) return;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    for (final event in (data['events'] as List? ?? [])) {
      if (event is Map<String, dynamic>) {
        _applyEvent(event['event_type'] as String?, event['payload'] as Map<String, dynamic>?);
        lastSeq = (event['seq'] as num?)?.toInt() ?? lastSeq;
      }
    }
    notifyListeners();
  }

  /// Feed one live data-channel event (from LiveKitService listener).
  void handleLiveEvent(Map<String, dynamic> message) {
    final seq = (message['seq'] as num?)?.toInt();
    if (seq != null && seq > lastSeq + 1) {
      // Gap detected: re-fetch authoritative state, then replay.
      unawaited(_recoverFromGap());
      return;
    }
    if (seq != null) lastSeq = seq;
    _applyEvent(message['type'] as String?, message);
    notifyListeners();
  }

  Future<void> _recoverFromGap() async {
    await refresh();
    await replayEvents(afterSeq: lastSeq);
  }

  void _applyEvent(String? type, Map<String, dynamic>? payload) {
    switch (type) {
      case 'session_started':
        presState = 'live';
      case 'presentation_paused':
        presState = 'paused';
      case 'presentation_resumed':
        presState = 'live';
      case 'session_completed':
        presState = 'completed';
      case 'presentation_interrupted':
      case 'presenter_takeover':
        aiState = 'idle';
        voiceOwner = 'none';
      case 'ai_response_started':
        voiceOwner = (payload?['owner'] as String?) ?? 'agent';
      case 'ai_response_ended':
        voiceOwner = 'none';
      case 'session_state':
        presState = (payload?['pres_state'] as String?) ?? presState;
        aiState = (payload?['ai_state'] as String?) ?? aiState;
      case 'slide_changed':
        currentSlideIndex = (payload?['index'] as num?)?.toInt() ?? currentSlideIndex;
        currentSlideTitle = (payload?['title'] as String?) ?? currentSlideTitle;
      case 'question_raised':
        if (payload?['question_id'] != null) {
          questions.add({
            'id': payload!['question_id'],
            'text': payload['preview'] ?? '',
            'status': 'raised',
          });
        }
      case 'narration_fallback':
        narrationFallbackReason = (payload?['reason'] as String?) ?? 'clone unavailable';
      case 'narration_suspended':
        narrationSuspended = true;
      case 'recording_started':
        recordingActive = true;
      case 'recording_stopped':
        recordingActive = false;
      default:
        break;
    }
  }

  // ------------------------------------------------------------------
  // Presenter / co-presenter commands
  // ------------------------------------------------------------------

  Future<bool> _command(String action, {Map<String, dynamic>? body}) async {
    if (sessionId == null) return false;
    final resp = await _api.post('/presentation-sessions/$sessionId/$action',
        body: body ?? const {});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['pres_state'] != null) presState = data['pres_state'] as String;
      if (data['ai_state'] != null) aiState = data['ai_state'] as String;
      if (data.containsKey('index')) {
        currentSlideIndex = (data['index'] as num).toInt();
        currentSlideTitle = (data['title'] as String?) ?? currentSlideTitle;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> start() => _command('start');
  Future<bool> pause() => _command('pause');
  Future<bool> resume() => _command('resume');
  Future<bool> end() => _command('end');
  Future<bool> interrupt() => _command('interrupt');
  Future<bool> takeover() => _command('takeover');
  Future<bool> gotoSlide(int index) => _command('interrupt', body: const {})
      .then((_) => _slideCommand('goto_slide', {'index': index}));
  Future<bool> addSlide({int? afterIndex, Map<String, dynamic>? slide}) =>
      _slideCommand('add_slide', {
        if (afterIndex != null) 'index': afterIndex,
        if (slide != null) 'slide': slide,
      });
  Future<bool> deleteSlide(String slideId, {int index = 0}) =>
      _slideCommand('delete_slide', {'slide_id': slideId, 'index': index});
  Future<bool> reorderSlide(String slideId, int toIndex) =>
      _slideCommand('reorder', {'slide_id': slideId, 'to_index': toIndex});

  Future<bool> _slideCommand(String action, Map<String, dynamic> params) async {
    // Slide ops ride the internal command relay via the HTTP surface in
    // Phase 5: they are presenter-only actions on the session router.
    if (sessionId == null) return false;
    final resp = await _api.post(
      '/presentation-sessions/$sessionId/command',
      body: {'action': action, 'params': params},
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      currentSlideIndex = (data['index'] as num?)?.toInt() ?? currentSlideIndex;
      currentSlideTitle = (data['title'] as String?) ?? currentSlideTitle;
      slideCount = (data['count'] as num?)?.toInt() ?? slideCount;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ------------------------------------------------------------------
  // Audience actions
  // ------------------------------------------------------------------

  Future<bool> askQuestion(String text, {String source = 'text'}) async {
    if (sessionId == null || participantId == 0) return false;
    final resp = await _api.post('/presentation-sessions/$sessionId/questions', body: {
      'participant_id': participantId,
      'text': text,
      'source': source,
    });
    if (resp.statusCode == 201) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      questions.add({'id': data['question_id'], 'text': text, 'status': data['status']});
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> moderate(int questionId, String decision, {String? answerText}) async {
    if (sessionId == null) return false;
    final resp = await _api.post(
      '/presentation-sessions/$sessionId/questions/$questionId/moderate',
      body: {'decision': decision, if (answerText != null) 'answer_text': answerText},
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      for (final q in questions) {
        if (q['id'] == questionId) {
          q['status'] = data['status'];
          break;
        }
      }
      aiState = data['ai_state'] ?? aiState;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> setPolicy(String policy) async {
    if (sessionId == null) return false;
    final resp = await _api.patch('/presentation-sessions/$sessionId/ai-policy',
        body: {'ai_policy': policy});
    if (resp.statusCode == 200) {
      aiPolicy = policy;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> sendCorrection(String text, {String kind = 'correction'}) async {
    if (sessionId == null) return false;
    final resp = await _api.post('/presentation-sessions/$sessionId/instructions',
        body: {'text': text, 'kind': kind});
    return resp.statusCode == 201;
  }

  /// Presenter fallback choices (Phase 4 disclosure): continue with the
  /// fallback voice, or disable narration entirely.
  void clearFallbackAndContinue() {
    narrationFallbackReason = null;
    narrationSuspended = false;
    notifyListeners();
  }

  void disableNarration() {
    narrationSuspended = true;
    narrationFallbackReason = null;
    notifyListeners();
  }

  Future<bool> heartbeat() async {
    if (sessionId == null) return false;
    final resp = await _api.post('/presentation-sessions/$sessionId/heartbeat');
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final newState = data['pres_state'] as String?;
      if (newState != null && newState != presState) {
        presState = newState;
        notifyListeners();
      }
      return true;
    }
    return false;
  }
}
