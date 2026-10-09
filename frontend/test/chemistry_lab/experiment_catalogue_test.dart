import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/modules/chemistry_lab/chemistry/equations.dart';
import 'package:penrose_scholar/modules/chemistry_lab/experiments/experiment_catalogue.dart';
import 'package:penrose_scholar/modules/chemistry_lab/experiments/titration_acid_base.dart';

void main() {
  group('ExperimentCatalogue', () {
    test('contains the acid–base titration demo', () {
      expect(ExperimentCatalogue.all, isNotEmpty);
      expect(ExperimentCatalogue.byId(AcidBaseTitration.id), isNotNull);
    });

    test('every experiment is complete (objectives, safety, steps, questions)', () {
      for (final e in ExperimentCatalogue.all) {
        expect(e.isComplete, isTrue, reason: '${e.id} is incomplete');
      }
    });

    test('procedure and expected observations stay aligned', () {
      for (final e in ExperimentCatalogue.all) {
        expect(e.expectedObservations.length, e.procedure.length, reason: e.id);
      }
    });

    test('every balanced equation is actually atom-balanced', () {
      for (final e in ExperimentCatalogue.all) {
        if (e.balancedEquation == null) continue;
        final eq = ChemicalEquation.parse(e.balancedEquation!);
        expect(eq.isBalanced, isTrue, reason: '${e.id}: ${e.balancedEquation}');
      }
    });

    test('titration constants reproduce the authored equivalence point', () {
      expect(AcidBaseTitration.expectedTitreMl, closeTo(25.00, 1e-9));
      expect(AcidBaseTitration.equation.isBalanced, isTrue);
    });

    test('every experiment labels its accuracy tiers', () {
      for (final e in ExperimentCatalogue.all) {
        expect(e.accuracyNotes, isNotEmpty, reason: '${e.id} lacks accuracy notes');
        for (final tier in e.accuracyNotes.values) {
          expect(
            {
              'validated',
              'calculated',
              'illustrative rendering of a validated pH range',
              'simulated measurement (0.05 cm³ resolution)'
            },
            contains(tier),
            reason: '${e.id}: unknown accuracy tier "$tier"',
          );
        }
      }
    });
  });
}
