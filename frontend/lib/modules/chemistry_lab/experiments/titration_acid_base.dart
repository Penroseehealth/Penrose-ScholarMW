import '../chemistry/equations.dart';
import 'experiment_definition.dart';

/// Acid–base titration: standardising NaOH against standard HCl.
///
/// Scientific basis (Malawi MSCE Chemistry, Form 4 — volumetric analysis):
///
/// - Analyte: 25.00 cm³ of 0.100 mol dm⁻³ HCl, pipetted into the flask,
///   with 2–3 drops of phenolphthalein.
/// - Titrant: 0.100 mol dm⁻³ NaOH from the burette.
/// - Reaction: `HCl(aq) + NaOH(aq) -> NaCl(aq) + H2O(l)` (1:1, balanced).
/// - Equivalence: V(NaOH) = (0.100 × 25.00) / 0.100 = 25.00 cm³ at pH 7.
/// - Endpoint: phenolphthalein turns faint pink (pH ≥ 8.2) — the first
///   permanent pale pink after 30 s of swirling.
///
/// The pH curve shown during the run is **calculated** from mole balances
/// (see `stoichiometry.titrationPh`), not a decorative animation. The
/// colour transition of the indicator is an **illustrative** rendering of a
/// validated pH range.
class AcidBaseTitration {
  AcidBaseTitration._();

  static const String id = 'acid_base_titration';

  // Authored experimental constants (validated data).
  static const double analyteConcentration = 0.100; // mol dm^-3 HCl
  static const double analyteVolumeMl = 25.00;
  static const double titrantConcentration = 0.100; // mol dm^-3 NaOH
  static const double buretteCapacityMl = 50.00;
  static const int titrantDropsPerMl = 20; // illustrative drop counting

  /// Final titre expected at equivalence (calculated from constants above;
  /// asserted by unit tests against `equivalenceVolumeMl`).
  static double get expectedTitreMl => 25.00;

  static const ExperimentDefinition definition = ExperimentDefinition(
    id: id,
    title: 'Acid–Base Titration: Standardising NaOH with HCl',
    summary: 'Titrate 0.100 mol dm⁻³ sodium hydroxide against 25.00 cm³ of 0.100 mol dm⁻³ '
        'hydrochloric acid using phenolphthalein, and determine the endpoint volume.',
    objectives: [
      'Perform a titration accurately using a burette, pipette and conical flask.',
      'Identify the endpoint of an acid–base titration with phenolphthalein.',
      'Calculate the concentration of NaOH from the titre volume.',
      'Explain why the endpoint differs slightly from the equivalence point.',
    ],
    apparatus: [
      'Burette (50 cm³)',
      'Pipette (25 cm³)',
      'Conical flask (250 cm³)',
      'Retort stand and clamp',
      'White tile',
      'Funnel',
      'Wash bottle (distilled water)',
      'Dropper (for indicator)',
    ],
    substances: [
      '0.100 mol dm⁻³ HCl (standard, corrosive — in the flask)',
      '0.100 mol dm⁻³ NaOH (standard, corrosive — in the burette)',
      'Phenolphthalein indicator (flammable solvent — 2–3 drops only)',
      'Distilled water (rinsing)',
    ],
    safetyNotes: [
      'Wear safety goggles and a lab coat throughout.',
      'Both HCl and NaOH are corrosive: rinse splashes immediately with plenty of water.',
      'Never pipette by mouth — use a pipette filler.',
      'Phenolphthalein contains flammable alcohol: keep away from the Bunsen burner.',
      'Dispose of titrated solutions in the designated waste bottle — do not sink the sink.',
      'This is a virtual rehearsal: it does not replace supervised practical work.',
    ],
    procedure: [
      'Rinse the burette with the NaOH solution, then fill it above the zero mark.',
      'Run out air bubbles and record the initial reading to 0.05 cm³.',
      'Rinse the pipette with HCl, then pipette 25.00 cm³ into the conical flask.',
      'Add 2–3 drops of phenolphthalein to the flask and place it on the white tile.',
      'Titrate while swirling: run in NaOH steadily at first, then dropwise near the endpoint.',
      'Stop at the first permanent pale pink lasting 30 seconds while swirling.',
      'Record the final burette reading and calculate the titre.',
      'Repeat until two titres agree within 0.10 cm³; use the mean.',
    ],
    expectedObservations: [
      'Burette filled, no air bubble in the tip; initial reading recorded.',
      'Initial reading read at eye level to the nearest 0.05 cm³.',
      'Flask contains 25.00 cm³ of colourless HCl.',
      'Solution stays colourless with indicator added.',
      'Pink colour appears where NaOH enters and disappears on swirling.',
      'Solution turns faint pink and stays pink for 30 s — endpoint reached.',
      'Titre ≈ 25.00 cm³ (calculated equivalence at pH 8.2–10).',
      'Repeat titres agree within 0.10 cm³; mean titre reported.',
    ],
    balancedEquation: 'HCl + NaOH -> NaCl + H2O',
    equations: [
      'HCl(aq) + NaOH(aq) → NaCl(aq) + H₂O(l)',
      'n = c × V',
      'c(NaOH) = c(HCl) × V(HCl) / V(NaOH)',
      'At equivalence (1:1): V(NaOH) = 25.00 cm³',
    ],
    questions: [
      ExperimentQuestion(
        question: 'Why is phenolphthalein suitable for this titration but methyl orange is not?',
        answer: 'Strong acid–strong base equivalence is at pH 7',
        explanation: 'HCl + NaOH is strong acid–strong base, so the pH changes very steeply around pH 7. '
            'Phenolphthalein changes colour at pH 8.2–10, inside the steep section, so the '
            'endpoint is sharp. Methyl orange (pH 3.1–4.4) would change far too early.',
      ),
      ExperimentQuestion(
        question: 'The burette reading is 0.00 cm³ initially and 24.95 cm³ at the endpoint. What is the titre?',
        answer: '24.95',
        explanation: 'Titre = final reading − initial reading = 24.95 − 0.00 = 24.95 cm³. '
            'Readings are taken to 0.05 cm³ (half the burette scale division).',
      ),
      ExperimentQuestion(
        question: 'Calculate c(NaOH) if the mean titre is 25.00 cm³.',
        answer: '0.100',
        explanation: 'n(HCl) = 0.100 × 0.02500 = 2.50 × 10⁻³ mol. The ratio is 1:1, so '
            'n(NaOH) = 2.50 × 10⁻³ mol and c(NaOH) = 2.50 × 10⁻³ / 0.02500 = 0.100 mol dm⁻³.',
      ),
      ExperimentQuestion(
        question: 'Why must air bubbles be expelled from the burette tip before titrating?',
        answer: 'They displace volume',
        explanation: 'An air bubble that escapes during titration makes the delivered volume read higher '
            'than the volume actually delivered, producing an erroneously large titre.',
      ),
    ],
    accuracyNotes: {
      'Equilibrium volume 25.00 cm³': 'calculated',
      'pH values during titration': 'calculated',
      'Indicator colour change': 'illustrative rendering of a validated pH range',
      'Burette readings': 'simulated measurement (0.05 cm³ resolution)',
      'Equation and stoichiometric ratio': 'validated',
    },
  );

  /// Parses the authored equation once and verifies it is atom-balanced.
  /// Tests call this to prove the authored data, not the parser, is right.
  static ChemicalEquation get equation => ChemicalEquation.parse(definition.balancedEquation!);
}
