/// Stoichiometry and solution chemistry — **calculated simulation outputs**,
/// all deterministic and unit-tested. Values are computed from authored
/// inputs (concentrations, volumes); nothing here invents data.
library;

import 'dart:math';

import 'equations.dart' show parseFormula;

/// Base-10 logarithm — `dart:math` only ships natural `log`.
double _log10(double x) => log(x) / ln10;

/// Amount of substance `n = c × V` (V in dm³).
double molesFromConcentration(double concentrationMolPerDm3, double volumeDm3) => concentrationMolPerDm3 * volumeDm3;

/// Concentration `c = n / V` (V in dm³, must be > 0).
double concentrationFromMoles(double moles, double volumeDm3) {
  if (volumeDm3 <= 0) throw ArgumentError.value(volumeDm3, 'volumeDm3', 'must be > 0');
  return moles / volumeDm3;
}

/// mL → dm³ (1 dm³ = 1000 mL).
double mLtoDm3(double mL) => mL / 1000.0;

/// pH of a strong monoprotic acid/base mixture after adding
/// [titrantMolesAdded] to [analyteMoles] in total volume [totalVolumeDm3].
///
/// This is the exact strong-acid/strong-base titration curve:
/// - excess acid  → pH = -log10([H+])
/// - equivalence  → pH = 7.0 (25 °C, autoionisation of water)
/// - excess base  → pOH = -log10([OH-]), pH = 14 - pOH
double titrationPh({
  required double analyteMoles,
  required double titrantMolesAdded,
  required double totalVolumeDm3,
}) {
  if (totalVolumeDm3 <= 0) throw ArgumentError.value(totalVolumeDm3, 'totalVolumeDm3');
  final excess = analyteMoles - titrantMolesAdded;
  const equivalenceTolerance = 1e-12; // mol — treat as exact equivalence
  if (excess.abs() < equivalenceTolerance) return 7.0;
  if (excess > 0) {
    final h = excess / totalVolumeDm3;
    return -_log10(h);
  }
  final oh = -excess / totalVolumeDm3;
  return 14.0 + _log10(oh); // 14 - (-log10([OH-]))
}

/// Volume of titrant (mL) needed to reach equivalence for a
/// `aA + bB` reaction: `V_b = (c_a × V_a × b) / (c_b × a)`.
double equivalenceVolumeMl({
  required double analyteConcentration,
  required double analyteVolumeMl,
  required double titrantConcentration,
  int analyteStoichiometry = 1,
  int titrantStoichiometry = 1,
}) {
  if (titrantConcentration <= 0) {
    throw ArgumentError.value(titrantConcentration, 'titrantConcentration', 'must be > 0');
  }
  final analyteMoles = analyteConcentration * mLtoDm3(analyteVolumeMl);
  final titrantMolesNeeded = analyteMoles * titrantStoichiometry / analyteStoichiometry;
  return titrantMolesNeeded / titrantConcentration * 1000.0;
}

/// Indicator colour class for phenolphthalein at [ph]:
/// colourless below 8.2, pink from 8.3 up (Malawi Form 4 practical range).
String phenolphthaleinColour(double ph) {
  if (ph < 8.2) return 'colourless';
  if (ph < 10.0) return 'pale pink';
  return 'deep pink';
}

/// Molar masses computed from an authored element-mass table
/// (g/mol, IUPAC standard atomic weights, rounded to 3 dp).
const Map<String, double> standardAtomicWeights = {
  'H': 1.008,
  'C': 12.011,
  'N': 14.007,
  'O': 15.999,
  'Na': 22.990,
  'Cl': 35.45,
  'S': 32.06,
  'K': 39.098,
  'Ca': 40.078,
  'Fe': 55.845,
  'Cu': 63.546,
  'Zn': 65.38,
  'Mg': 24.305,
  'Al': 26.982,
};

/// Molar mass of [formula] using [parseFormula] element counts.
/// Throws [ArgumentError] for unknown elements — authored-data guard.
double molarMass(String formula, {Map<String, double> weights = standardAtomicWeights}) {
  final counts = parseFormula(formula);
  var total = 0.0;
  counts.forEach((element, n) {
    final w = weights[element];
    if (w == null) {
      throw ArgumentError('Unknown element "$element" in formula "$formula"');
    }
    total += w * n;
  });
  return total;
}
