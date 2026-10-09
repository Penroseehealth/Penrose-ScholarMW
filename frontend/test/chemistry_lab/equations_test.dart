import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/modules/chemistry_lab/chemistry/equations.dart';

void main() {
  group('parseFormula', () {
    test('water', () {
      expect(parseFormula('H2O'), {'H': 2, 'O': 1});
    });

    test('two-letter symbols are not split', () {
      expect(parseFormula('NaCl'), {'Na': 1, 'Cl': 1});
      expect(parseFormula('CaCO3'), {'Ca': 1, 'C': 1, 'O': 3});
    });

    test('nested-free parentheses with multiplier', () {
      expect(parseFormula('Ca(OH)2'), {'Ca': 1, 'O': 2, 'H': 2});
    });

    test('explicit counts', () {
      expect(parseFormula('C6H12O6'), {'C': 6, 'H': 12, 'O': 6});
    });

    test('bad character rejected', () {
      expect(() => parseFormula('H2O!'), throwsFormatException);
    });
  });

  group('ChemicalEquation.parse', () {
    test('titration equation parses 1:1', () {
      final eq = ChemicalEquation.parse('HCl + NaOH -> NaCl + H2O');
      expect(eq.reactants.length, 2);
      expect(eq.products.length, 2);
      expect(eq.isBalanced, isTrue);
    });

    test('coefficients multiply into counts', () {
      final eq = ChemicalEquation.parse('2H2 + O2 -> 2H2O');
      expect(eq.isBalanced, isTrue);
      expect(eq.reactantAtomCounts, {'H': 4, 'O': 2});
      expect(eq.productAtomCounts, {'H': 4, 'O': 2});
    });

    test('unicode and equals separators are normalised', () {
      expect(ChemicalEquation.parse('2H2 + O2 → 2H2O').isBalanced, isTrue);
      expect(ChemicalEquation.parse('CH4 + 2O2 = CO2 + 2H2O').isBalanced, isTrue);
    });

    test('state symbols are captured and ignored in counting', () {
      final eq = ChemicalEquation.parse('HCl(aq) + NaOH(aq) -> NaCl(aq) + H2O(l)');
      expect(eq.isBalanced, isTrue);
      expect(eq.reactants.first.state, 'aq');
      expect(eq.products.last.state, 'l');
    });

    test('unbalanced equation is detected (guard against bad authored data)', () {
      final eq = ChemicalEquation.parse('H2 + O2 -> H2O');
      expect(eq.isBalanced, isFalse);
    });

    test('missing arrow is a FormatException', () {
      expect(() => ChemicalEquation.parse('HCl NaOH NaCl H2O'), throwsFormatException);
    });
  });
}
