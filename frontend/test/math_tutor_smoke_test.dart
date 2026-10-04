import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/screens/mathematics/math_tutor_screen.dart';
import 'package:penrose_scholar/services/math_tutor_api.dart';
import 'package:penrose_scholar/widgets/math_tutor/math_solution.dart';
import 'package:penrose_scholar/widgets/math_tutor/tutor_visual.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A remote tutor stub that returns the real server contract for the flagship
/// quadratic, so the redesigned workspace can be smoke-tested end to end
/// without a network.
class _FakeTutorApi extends MathTutorApi {
  _FakeTutorApi() : super();

  @override
  Future<TutorSolution?> solve(String problem) async => TutorSolution.fromJson(<String, dynamic>{
        'problem': problem,
        'subject': 'algebra',
        'topic': 'quadratic_equation',
        'final_answer_latex': r'x_{1} = -3, \quad x_{2} = -2',
        'final_answer_text': '-3, -2',
        'verification_status': 'verified',
        'verification_detail': 'Residual after substitution: 0, 0',
        'visual': <String, dynamic>{
          'kind': 'parabola',
          'params': <String, dynamic>{
            'a': 1,
            'b': 5,
            'c': 6,
            'has_real_roots': true,
            'roots': <double>[-3, -2],
          },
          'caption': 'The parabola crosses the x-axis where the roots are.',
        },
        'steps': <Map<String, dynamic>>[
          {
            'id': 1,
            'title': 'Identify the coefficients',
            'explanation': 'Compare with ax^2 + bx + c = 0 to read off a, b and c.',
            'narration': 'First we identify the coefficients.',
            'latex_lines': <String>[r'ax^{2} + bx + c = 0', r'a = 1, \quad b = 5, \quad c = 6'],
          },
          {
            'id': 2,
            'title': 'Apply the quadratic formula',
            'explanation': 'The roots come from the quadratic formula.',
            'narration': 'Next we apply the quadratic formula.',
            'latex_lines': <String>[r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}'],
          },
          {
            'id': 3,
            'title': 'State the answer',
            'explanation': 'The two roots are -3 and -2.',
            'narration': 'So the roots are minus three and minus two.',
            'latex_lines': <String>[r'x_{1} = -3, \quad x_{2} = -2'],
          },
        ],
      });

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
      const TutorReply(
        text: 'We use the quadratic formula because the equation is quadratic; it always gives both roots.',
        stepRef: 2,
        source: 'ai',
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  void useWideSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('redesigned workspace renders a verified, typeset worked solution', (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(MaterialApp(home: MathTutorScreen(api: _FakeTutorApi())));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Solve x^2 + 5x + 6 = 0');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verified server solution upgraded the on-device result.
    expect(find.text('Verified'), findsOneWidget);
    expect(find.textContaining('1. Identify the coefficients'), findsOneWidget);
    expect(find.textContaining('2. Apply the quadratic formula'), findsOneWidget);
    expect(find.textContaining('Answer: -3, -2'), findsOneWidget);

    // The contextual visual is present (no generic decorative panel).
    expect(find.byType(TutorVisualCard), findsOneWidget);
  });

  testWidgets('conversational voice panel answers a typed follow-up', (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(MaterialApp(home: MathTutorScreen(api: _FakeTutorApi())));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Solve x^2 + 5x + 6 = 0');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The chat field unlocks once there is a solution to talk about.
    final chatField = find.widgetWithText(TextField, 'Ask about a step\u2026');
    expect(chatField, findsOneWidget);

    await tester.enterText(chatField, 'Why the quadratic formula?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('We use the quadratic formula because'), findsOneWidget);
  });

  testWidgets('offline mode solves deterministically with no network', (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: MathTutorScreen(enableRemote: false)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Find the hypotenuse of a right triangle with legs 3 and 4 cm');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Worked solution'), findsOneWidget);
    expect(find.textContaining('Answer: 5'), findsOneWidget);
  });
}
