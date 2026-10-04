import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/widgets/math_tutor/math_solver.dart';

void main() {
  test('pythagoras hypotenuse', () {
    final s = TutorSolver.solve('Find the hypotenuse of a right triangle with legs 3 and 4 cm')!;
    expect(s.topic, 'pythagorean_theorem');
    expect(s.sideC, closeTo(5, 1e-9));
    expect(s.finalAnswer, '5 centimetres');
    expect(s.steps.length, greaterThanOrEqualTo(8));
    expect(s.steps.last.narration.toLowerCase(), contains('verify'));
  });

  test('pythagoras missing leg', () {
    final s = TutorSolver.solve(
        'A right angled triangle has a hypotenuse of 10 cm and one side of 6 cm, find the other side')!;
    expect(s.sideB, closeTo(8, 1e-9));
    expect(s.finalAnswer, '8 centimetres');
  });

  test('linear equation', () {
    final s = TutorSolver.solve('Solve 3x + 5 = 20')!;
    expect(s.topic, 'linear_equation');
    expect(s.finalAnswer, 'x = 5');
    expect(s.steps.last.narration.toLowerCase(), contains('correct'));
  });

  test('percentage', () {
    final s = TutorSolver.solve('What is 15% of 240?')!;
    expect(s.finalAnswer, '36');
  });

  test('arithmetic with precedence', () {
    final s = TutorSolver.solve('Calculate 12 + 6 * 2')!;
    expect(s.finalAnswer, '24');
  });

  test('arithmetic with brackets and fractions', () {
    final s = TutorSolver.solve('Evaluate 1/2 + 1/4')!;
    expect(s.finalAnswer, '0.75');
  });

  test('unknown input returns null', () {
    expect(TutorSolver.solve('Tell me about the Roman empire'), isNull);
  });

  test('ambiguous triangle asks for clarification', () {
    final s = TutorSolver.solve('Solve the triangle')!;
    expect(s.topic, 'needs_more_information');
    expect(s.steps.single.narration, contains('two known side lengths'));
  });
}
