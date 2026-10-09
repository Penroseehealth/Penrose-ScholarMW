import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/screens/physics/physics_tutor_screen.dart';
import 'package:penrose_scholar/services/math_tutor_api.dart';
import 'package:penrose_scholar/services/physics_tutor_api.dart';
import 'package:penrose_scholar/widgets/physics_tutor/physics_solution.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A remote tutor stub that returns the real server contract for a flagship
/// problem, so the physics workspace can be smoke-tested end to end without a
/// network.
class _FakePhysicsTutorApi extends PhysicsTutorApi {
  _FakePhysicsTutorApi() : super();

  @override
  Future<PhysicsSolution?> solve(String problem) async => PhysicsSolution.fromJson(<String, dynamic>{
        'problem': problem,
        'subject': 'physics',
        'topic': 'newtons_second_law',
        'principle': 'Weight is the force of gravity on a mass, W = mg.',
        'given': <Map<String, dynamic>>[
          {'symbol': 'm', 'latex': r'm = 10\ \text{kg}', 'quantity': '10 kg'},
          {'symbol': 'g', 'latex': r'g = 9.81\ \text{m/s}^2', 'quantity': '9.81 m/s^2'},
        ],
        'find': <String>['weight'],
        'final_answer_latex': r'W = 98.1\ \text{N}',
        'final_answer_text': '98.1 N',
        'verification_status': 'verified',
        'verification_detail': 'Recomputed from W = mg and matched to 3 significant figures.',
        'steps': <Map<String, dynamic>>[
          {
            'id': 1,
            'title': 'Write down what is given',
            'explanation': 'The mass is 10 kg and g is 9.81 m/s^2.',
            'narration': 'First we note the mass and the gravitational field strength.',
            'latex_lines': <String>[r'm = 10\ \text{kg}', r'g = 9.81\ \text{m/s}^2'],
          },
          {
            'id': 2,
            'title': 'Apply the weight equation',
            'explanation': 'Weight is mass times gravitational field strength.',
            'narration': 'Next we apply W equals m g.',
            'latex_lines': <String>[r'W = mg'],
          },
          {
            'id': 3,
            'title': 'State the answer',
            'explanation': 'Multiplying gives 98.1 newtons.',
            'narration': 'So the weight is ninety eight point one newtons.',
            'latex_lines': <String>[r'W = 98.1\ \text{N}'],
          },
        ],
      });

  @override
  Future<TutorReply?> explain({
    required String problem,
    required String question,
    required PhysicsSolution? solution,
    int? stepId,
    String? topic,
    String? currentEquation,
    List<String> conceptsExplained = const <String>[],
    List<Map<String, String>> history = const <Map<String, String>>[],
  }) async =>
      const TutorReply(
        text: 'Weight is just mg, so a 10 kg mass weighs 98.1 newtons on Earth.',
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

  testWidgets('physics workspace renders a verified worked solution', (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(MaterialApp(home: PhysicsTutorScreen(api: _FakePhysicsTutorApi())));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Calculate the weight of a 10 kg object.');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Given'), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
    expect(find.textContaining('1. Write down what is given'), findsOneWidget);
    expect(find.textContaining('2. Apply the weight equation'), findsOneWidget);
    expect(find.textContaining('Answer: 98.1 N'), findsOneWidget);
  });

  testWidgets('conversational panel answers a typed follow-up', (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(MaterialApp(home: PhysicsTutorScreen(api: _FakePhysicsTutorApi())));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Calculate the weight of a 10 kg object.');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final chatField = find.widgetWithText(TextField, 'Ask about a step\u2026');
    expect(chatField, findsOneWidget);

    await tester.enterText(chatField, 'Why is weight mg?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Weight is just mg'), findsOneWidget);
  });

  testWidgets('offline mode reports that the service is unreachable', (tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: PhysicsTutorScreen(enableRemote: false)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Calculate the weight of a 10 kg object.');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('could not reach the physics tutor service'), findsOneWidget);
  });
}
