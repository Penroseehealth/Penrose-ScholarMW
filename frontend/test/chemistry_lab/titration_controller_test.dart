import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/modules/chemistry_lab/experiments/titration_acid_base.dart';
import 'package:penrose_scholar/modules/chemistry_lab/simulation/titration_controller.dart';

void main() {
  group('TitrationController quantitative model', () {
    test('starts unstarted with no delivered volume', () {
      final c = TitrationController();
      expect(c.phase, TitrationPhase.notStarted);
      expect(c.deliveredMl, 0);
      expect(c.currentPh, closeTo(1.0, 1e-9)); // 0.100 M HCl
      expect(c.indicatorColour, 'colourless');
      c.dispose();
    });

    test('fillBurette → ready with 0.00 initial reading', () {
      final c = TitrationController();
      c.fillBurette();
      expect(c.phase, TitrationPhase.ready);
      expect(c.initialReadingMl, 0.00);
      c.dispose();
    });

    test('delivering reagents: pH curve follows calculated model', () {
      final c = TitrationController()..fillBurette();

      c.deliver(20.0); // still acidic
      expect(c.phase, TitrationPhase.titrating);
      expect(c.currentPh, lessThan(7));

      c.deliver(4.9); // 24.90 cm³ — near equivalence
      expect(c.deliveredMl, closeTo(24.90, 1e-9));
      expect(c.currentPh, closeTo(3.70, 0.05));

      c.deliver(0.1); // 25.00 cm³ exactly → pH 7
      expect(c.currentPh, closeTo(7.0, 1e-6));
      expect(c.atEndpoint, isFalse);

      c.deliverDrop(); // slightly past → phenolphthalein pink
      expect(c.currentPh, greaterThan(8.2));
      expect(c.atEndpoint, isTrue);
      expect(c.indicatorColour, isNot('colourless'));
      c.dispose();
    });

    test('cannot record endpoint before the colour change', () {
      final c = TitrationController()..fillBurette();
      c.deliver(10.0);
      expect(c.recordEndpoint(), isFalse);
      c.dispose();
    });

    test('full run reproduces the authored titre and concentration', () {
      final c = TitrationController()
        ..fillBurette()
        ..deliver(25.00);
      expect(c.atEndpoint, isFalse); // exactly pH 7 — indicator still colourless
      c.deliverDrop(); // cross into pH ≥ 8.2
      expect(c.recordEndpoint(), isTrue);
      expect(c.phase, TitrationPhase.endpointReached);

      final titre = c.finalReadingMl! - c.initialReadingMl!;
      expect(titre, closeTo(25.00 + 0.05, 0.001)); // 25.00 + one drop (0.05)
      final calc = c.calculatedTitrantConcentration!;
      expect(calc, closeTo(0.100, 0.005));
      c.dispose();
    });

    test('burette capacity is enforced (no over-delivery)', () {
      final c = TitrationController()..fillBurette();
      c.deliver(60.0);
      expect(c.deliveredMl, closeTo(AcidBaseTitration.buretteCapacityMl, 1e-9));
      c.dispose();
    });

    test('reset restores a fully repeatable run', () {
      final c = TitrationController()
        ..fillBurette()
        ..prepareFlask()
        ..deliver(25.05)
        ..recordEndpoint()
        ..submitAnswer(0, 'x');
      expect(c.phase, TitrationPhase.endpointReached);
      expect(c.answers, isNotEmpty);

      c.reset();
      expect(c.phase, TitrationPhase.notStarted);
      expect(c.deliveredMl, 0);
      expect(c.initialReadingMl, isNull);
      expect(c.finalReadingMl, isNull);
      expect(c.flaskPrepared, isFalse);
      expect(c.answers, isEmpty);
      expect(c.currentStep, 0);
      c.dispose();
    });

    test('actions are guarded before the burette is filled', () {
      final c = TitrationController();
      c.deliver(5.0);
      expect(c.deliveredMl, 0);
      expect(c.recordEndpoint(), isFalse);
      c.dispose();
    });

    test('scene params track delivered volume (burette level falls)', () {
      final c = TitrationController()..fillBurette();
      c.deliver(12.5);
      // Half the burette should be emptied: scale.y ≈ 0.75 of the
      // original liquid column (12.5 of 50 cm³ delivered).
      c.deliver(12.5);
      expect(c.deliveredMl, closeTo(25.0, 1e-9));
      c.dispose();
    });

    test('procedure navigation stays within bounds', () {
      final c = TitrationController();
      final steps = AcidBaseTitration.definition.procedure.length;
      c.goToStep(steps + 5);
      expect(c.currentStep, 0);
      c.goToStep(-1);
      expect(c.currentStep, 0);
      c.nextStep();
      expect(c.currentStep, 1);
      c.dispose();
    });
  });
}
