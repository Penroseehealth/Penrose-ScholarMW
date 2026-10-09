import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/modules/chemistry_lab/chemistry/stoichiometry.dart';

void main() {
  group('mole / concentration conversions', () {
    test('n = c × V', () {
      expect(molesFromConcentration(0.100, 0.025), closeTo(0.0025, 1e-12));
    });

    test('c = n / V', () {
      expect(concentrationFromMoles(0.0025, 0.025), closeTo(0.100, 1e-12));
    });

    test('c = n / V rejects zero volume', () {
      expect(() => concentrationFromMoles(1, 0), throwsArgumentError);
    });

    test('mL → dm³', () {
      expect(mLtoDm3(25.00), closeTo(0.025, 1e-12));
      expect(mLtoDm3(1000), closeTo(1.0, 1e-12));
    });
  });

  group('titration pH curve (strong acid + strong base)', () {
    // 25.00 cm³ of 0.100 M HCl titrated with 0.100 M NaOH.
    const analyteMoles = 0.100 * 0.025; // 2.5e-3

    double phAt(double addedMl) => titrationPh(
          analyteMoles: analyteMoles,
          titrantMolesAdded: 0.100 * (addedMl / 1000),
          totalVolumeDm3: (25.00 + addedMl) / 1000,
        );

    test('before any titrant: pH of 0.100 M HCl is 1', () {
      expect(phAt(0), closeTo(1.0, 1e-9));
    });

    test('half-equivalence: pH 1.5 not needed — mid-run stays acidic', () {
      expect(phAt(12.5), lessThan(1.7));
      expect(phAt(12.5), greaterThan(1.3));
    });

    test('at equivalence (25.00 cm³): pH exactly 7', () {
      expect(phAt(25.00), closeTo(7.0, 1e-9));
    });

    test('past equivalence: pH is basic and rises', () {
      expect(phAt(25.10), greaterThan(7.0));
      expect(phAt(30.00), greaterThan(phAt(25.10)));
      // 0.10 cm³ past: excess OH = 1e-5 mol in 50.10 cm³ → pOH ≈ 3.7
      expect(phAt(25.10), closeTo(14 - 3.7, 0.15));
    });

    test('just before equivalence: pH is acidic', () {
      // 0.10 cm³ of acid left in 49.90 cm³ → [H+] = 2.00e-4 → pH ≈ 3.70.
      expect(phAt(24.90), lessThan(7.0));
      expect(phAt(24.90), closeTo(3.70, 0.05));
    });
  });

  group('equivalence volume', () {
    test('25.00 cm³ of 0.100 M HCl vs 0.100 M NaOH → 25.00 cm³', () {
      final v = equivalenceVolumeMl(
        analyteConcentration: 0.100,
        analyteVolumeMl: 25.00,
        titrantConcentration: 0.100,
      );
      expect(v, closeTo(25.00, 1e-9));
    });

    test('1:2 stoichiometry doubles the titrant volume', () {
      final v = equivalenceVolumeMl(
        analyteConcentration: 0.100,
        analyteVolumeMl: 25.00,
        titrantConcentration: 0.100,
        titrantStoichiometry: 2,
      );
      expect(v, closeTo(50.00, 1e-9));
    });

    test('zero titrant concentration rejected', () {
      expect(
        () => equivalenceVolumeMl(
          analyteConcentration: 0.1,
          analyteVolumeMl: 25,
          titrantConcentration: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('phenolphthalein indicator', () {
    test('acidic solution is colourless', () {
      expect(phenolphthaleinColour(1.0), 'colourless');
      expect(phenolphthaleinColour(7.0), 'colourless');
      expect(phenolphthaleinColour(8.1), 'colourless');
    });

    test('endpoint range (8.2–10) shows pink', () {
      expect(phenolphthaleinColour(8.3), 'pale pink');
      expect(phenolphthaleinColour(9.5), 'pale pink');
    });

    test('strongly basic shows deep pink', () {
      expect(phenolphthaleinColour(11.0), 'deep pink');
    });
  });

  group('molar mass (authored weights)', () {
    test('H2O ≈ 18.015', () {
      expect(molarMass('H2O'), closeTo(18.015, 0.001));
    });

    test('NaCl ≈ 58.44', () {
      expect(molarMass('NaCl'), closeTo(58.44, 0.01));
    });

    test('Ca(OH)2 handles parentheses', () {
      expect(molarMass('Ca(OH)2'), closeTo(74.093, 0.01));
    });

    test('unknown element is rejected (authored-data guard)', () {
      expect(() => molarMass('Xx2'), throwsArgumentError);
    });
  });
}
