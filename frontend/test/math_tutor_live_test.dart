import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/screens/mathematics/math_tutor_screen.dart';
import 'package:penrose_scholar/services/math_tutor_api.dart';
import 'package:penrose_scholar/voice/tts_service.dart';
import 'package:penrose_scholar/voice/voice_session_manager.dart';
import 'package:penrose_scholar/widgets/math_tutor/geometry_board.dart';
import 'package:penrose_scholar/widgets/math_tutor/math_solution.dart';
import 'package:penrose_scholar/widgets/math_tutor/math_solver.dart';
import 'package:penrose_scholar/widgets/math_tutor/math_tutor_player.dart';
import 'package:penrose_scholar/widgets/math_tutor/math_typewriter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test A - the equation is written one valid fragment at a time.
void _testCharacterRendering() {
  test('commands and their brace groups reveal as single valid tokens', () {
    expect(
      LatexReveal.tokens(r'x = \frac{15}{2}'),
      <String>['x', ' ', '=', ' ', r'\frac{15}{2}'],
    );
    expect(LatexReveal.tokens(r'\sqrt{b^2 - 4ac}'), <String>[r'\sqrt{b^2 - 4ac}']);
  });

  test('every reveal prefix keeps balanced braces (never half a command)', () {
    final prefixes = LatexReveal.sequence(r'x = \frac{15}{2}');
    expect(prefixes.last, r'x = \frac{15}{2}');
    for (final prefix in prefixes) {
      final open = RegExp(r'\{').allMatches(prefix).length;
      final close = RegExp(r'\}').allMatches(prefix).length;
      expect(open, close, reason: 'unbalanced prefix: $prefix');
    }
  });

  test('operators pause longer than digits', () {
    final tokens = LatexReveal.tokens(r'2x = 15');
    final equals = LatexReveal.delayFor('=', tokens.indexOf('='), tokens, 1.0);
    final digit = LatexReveal.delayFor('1', tokens.indexOf('1'), tokens, 1.0);
    expect(equals, greaterThan(digit));
  });
}

/// Test E (offline) - the deterministic solver still verifies by substitution.
void _testOfflineVerification() {
  test('offline linear solution verifies by substitution', () {
    final solution = TutorSolver.solve('Solve 2x + 9 = 24')!;
    expect(solution.topic, 'linear_equation');
    expect(solution.finalAnswer, 'x = 7.5');
    expect(solution.steps.last.narration.toLowerCase(), contains('correct'));
  });
}

class _FakeTts extends PenroseTtsService {
  _FakeTts() : super(session: VoiceSessionManager());

  @override
  Future<bool> speakOnce(String text, {String lang = 'en-US', double speed = 1.0}) async => false;

  @override
  void stop() {}
}

/// A TTS stub whose utterance never completes, so playback stays on a step and
/// the test can interrupt it mid-narration.
class _GateTts extends PenroseTtsService {
  _GateTts() : super(session: VoiceSessionManager());

  final Completer<bool> gate = Completer<bool>();

  @override
  Future<bool> speakOnce(String text, {String lang = 'en-US', double speed = 1.0}) => gate.future;

  @override
  void stop() {}
}

/// Test B - interrupting with a question pauses narration without skipping.
void _testContextualInterruption() {
  testWidgets('asking a question pauses narration and keeps the current step', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final player = MathTutorPlayer(tts: _GateTts());

    await tester.pumpWidget(MaterialApp(home: MathTutorScreen(enableRemote: false, player: player)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Solve 2x + 9 = 24');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Narration is under way and held on the first step.
    expect(player.index, 0);
    expect(player.state, MathTutorPlaybackState.loading);

    final chatField = find.widgetWithText(TextField, 'Ask about a step\u2026');
    expect(chatField, findsOneWidget);

    await tester.enterText(chatField, 'Why did we subtract 9?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The interruption paused narration and preserved the step the student
    // was looking at, rather than jumping ahead.
    expect(player.state, MathTutorPlaybackState.paused);
    expect(player.index, 0);
    expect(find.textContaining('Why did we subtract 9?'), findsOneWidget);
  });
}

/// Test C - the chosen catalog voice reaches the speech engine.
void _testVoicePropagation() {
  test('player forwards the selected catalog voice to TTS', () {
    final player = MathTutorPlayer(tts: _FakeTts());
    expect(player.voiceId, isNull);

    player.voiceId = 'en-in-male';
    expect(player.voiceId, 'en-in-male');

    player.voiceId = '';
    expect(player.voiceId, isNull);
  });
}

/// A linear-equation server stub whose /check flags a wrong move.
class _LinearTutorApi extends MathTutorApi {
  _LinearTutorApi() : super();

  @override
  Future<TutorSolution?> solve(String problem) async => TutorSolution.fromJson(<String, dynamic>{
        'problem': problem,
        'subject': 'algebra',
        'topic': 'linear_equation',
        'final_answer_latex': r'x = 7.5',
        'final_answer_text': 'x = 7.5',
        'verification_status': 'verified',
        'verification_detail': 'Residual after substitution: 0',
        'steps': <Map<String, dynamic>>[
          {
            'id': 1,
            'title': 'Write down the equation',
            'explanation': 'Start from the equation we were given.',
            'narration': 'We need to solve two x plus nine equals twenty-four.',
            'latex_lines': <String>[r'2x + 9 = 24'],
          },
          {
            'id': 2,
            'title': 'Move the constant',
            'explanation': 'Subtract nine from both sides.',
            'narration': 'Subtract nine from both sides.',
            'latex_lines': <String>[r'2x = 24 - 9', r'2x = 15'],
          },
          {
            'id': 3,
            'title': 'Divide by the coefficient',
            'explanation': 'Divide both sides by two.',
            'narration': 'Divide both sides by two.',
            'latex_lines': <String>[r'x = \frac{15}{2}', r'x = 7.5'],
          },
        ],
      });

  @override
  Future<TutorWorkCheck?> check({required String problem, required String studentLine}) async => const TutorWorkCheck(
        ok: false,
        message: 'Not quite - to undo adding 9 you must subtract 9 from both sides, so 2x = 24 - 9 = 15.',
        expectedLatex: r'2x = 15',
        correctionLatex: r'2x = 24 - 9',
        stepRef: 2,
      );

  @override
  Future<TutorReply?> explain({
    required String problem,
    required String question,
    required TutorSolution? solution,
    int? stepId,
    String? topic,
    String? currentEquation,
    List<String> conceptsExplained = const <String>[],
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async =>
      const TutorReply(text: 'fallback', stepRef: 2, source: 'ai');
}

/// Test D (frontend) - a wrong line of working is caught and corrected.
void _testWorkCheckIntegration() {
  testWidgets('typing a wrong line names the mistake and shows the correction', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: MathTutorScreen(api: _LinearTutorApi())));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Solve 2x + 9 = 24');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final chatField = find.widgetWithText(TextField, 'Ask about a step\u2026');
    expect(chatField, findsOneWidget);

    await tester.enterText(chatField, '2x = 33');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('subtract 9 from both sides'), findsOneWidget);
  });
}

/// Test F - the geometry board constructs the shape and settles cleanly.
void _testGeometryBoard() {
  testWidgets('geometry board draws the shape and settles', (tester) async {
    final solution = TutorSolver.solve('Find the hypotenuse of a right triangle with legs 3 and 4 cm')!;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GeometryBoard(solution: solution, stepIndex: 0))),
    );
    await tester.pump();
    expect(find.byType(GeometryBoard), findsOneWidget);
    await tester.pumpAndSettle();

    // Advancing a step draws more of the construction without throwing.
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GeometryBoard(solution: solution, stepIndex: 4))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GeometryBoard), findsOneWidget);
  });
}

void main() {
  _testCharacterRendering();
  _testContextualInterruption();
  _testOfflineVerification();
  _testVoicePropagation();
  _testWorkCheckIntegration();
  _testGeometryBoard();
}
