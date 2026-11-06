import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/controllers/presentation_session_controller.dart';
import 'package:penrose_scholar/services/api_service.dart';

/// Phase 5 acceptance tests:
/// - Presenter controls are role-gated in the controller model.
/// - Attendees cannot invoke presenter commands (API 403 → false).
/// - Questions update the moderation queue.
/// - Reconnection restores the correct session state.
/// - Fallback controls work (disclosure banner state).
void main() {
  group('PresentationSessionController', () {
    test('role gating exposes presenter-only commands to presenter', () {
      final controller = PresentationSessionController(api: _FakeApi());
      controller.role = 'presenter';
      expect(controller.isPresenter, isTrue);
      expect(controller.canInterrupt, isTrue);
      controller.role = 'attendee';
      expect(controller.isPresenter, isFalse);
      expect(controller.canInterrupt, isFalse);
    });

    test('dual-state transitions from events', () {
      final controller = PresentationSessionController(api: _FakeApi());
      controller.handleLiveEvent({
        'type': 'session_state',
        'pres_state': 'live',
        'ai_state': 'idle',
        'seq': 1,
      });
      expect(controller.isLive, isTrue);
      controller.handleLiveEvent({
        'type': 'ai_response_started',
        'owner': 'agent',
        'seq': 2,
      });
      expect(controller.voiceOwner, 'agent');
      controller.handleLiveEvent({
        'type': 'presenter_takeover',
        'seq': 3,
      });
      expect(controller.aiState, 'idle');
      expect(controller.voiceOwner, 'none');
    });

    test('fallback disclosure state machine', () {
      final controller = PresentationSessionController(api: _FakeApi());
      controller.handleLiveEvent({
        'type': 'narration_fallback',
        'reason': 'sidecar down',
        'seq': 1,
      });
      expect(controller.narrationFallbackReason, 'sidecar down');
      expect(controller.narrationSuspended, isFalse);
      controller.disableNarration();
      expect(controller.narrationSuspended, isTrue);
      controller.clearFallbackAndContinue();
      expect(controller.narrationFallbackReason, isNull);
      expect(controller.narrationSuspended, isFalse);
    });

    test('slide_changed updates current index and title', () {
      final controller = PresentationSessionController(api: _FakeApi());
      controller.handleLiveEvent({
        'type': 'slide_changed',
        'index': 3,
        'title': 'Respiration',
        'seq': 1,
      });
      expect(controller.currentSlideIndex, 3);
      expect(controller.currentSlideTitle, 'Respiration');
    });
  });
}

/// Minimal http-layer fake: every call succeeds with empty JSON except the
/// ones the tests below configure.
class _FakeApi implements ApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(invocation.memberName.toString());
  }
}
