import 'dart:async';

import '../chemistry/stoichiometry.dart';
import '../experiments/titration_acid_base.dart';
import '../state/chemistry_lab_provider.dart';

/// Simulation phase of the titration run.
enum TitrationPhase {
  /// Before the burette is filled.
  notStarted,

  /// Burette ready, flask prepared.
  ready,

  /// NaOH is being delivered.
  titrating,

  /// First permanent pale pink observed.
  endpointReached,

  /// Results and assessment shown.
  analysed,
}

/// Quantitative titration controller — **calculated simulation**, the
/// scientific counterpart of the 3D animation.
///
/// All displayed chemistry (burette volume, pH, concentration results)
/// comes from this pure-Dart model via `stoichiometry.dart`; the 3D scene
/// only visualises the values it is sent. Reset makes the run fully
/// repeatable (acceptance: reset + replay without reload).
class TitrationController {
  TitrationController({ChemistryLabProvider? provider}) : _provider = provider;

  final ChemistryLabProvider? _provider;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  TitrationPhase _phase = TitrationPhase.notStarted;
  double _deliveredMl = 0;
  double? _initialReadingMl;
  double? _finalReadingMl;
  bool _indicatorAdded = false;
  bool _flaskPrepared = false;
  int _currentStep = 0;
  final Map<int, String> _answers = {};

  TitrationPhase get phase => _phase;
  double get deliveredMl => _deliveredMl;
  double? get initialReadingMl => _initialReadingMl;
  double? get finalReadingMl => _finalReadingMl;
  bool get indicatorAdded => _indicatorAdded;
  bool get flaskPrepared => _flaskPrepared;
  int get currentStep => _currentStep;
  Map<int, String> get answers => Map.unmodifiable(_answers);

  Stream<void> get changes => _changes.stream;

  // ── Derived, calculated values ────────────────────────────────────────

  /// Total volume in the flask (analyte + delivered titrant), dm³.
  double get totalVolumeDm3 => mLtoDm3(AcidBaseTitration.analyteVolumeMl + _deliveredMl);

  /// Moles of HCl initially in the flask.
  double get analyteMoles => molesFromConcentration(
        AcidBaseTitration.analyteConcentration,
        mLtoDm3(AcidBaseTitration.analyteVolumeMl),
      );

  /// Moles of NaOH delivered so far.
  double get titrantMoles => molesFromConcentration(
        AcidBaseTitration.titrantConcentration,
        mLtoDm3(_deliveredMl),
      );

  /// pH of the flask contents at the current delivered volume (calculated).
  double get currentPh => titrationPh(
        analyteMoles: analyteMoles,
        titrantMolesAdded: titrantMoles,
        totalVolumeDm3: totalVolumeDm3,
      );

  /// Indicator colour at the current pH (illustrative rendering of a
  /// validated range).
  String get indicatorColour => phenolphthaleinColour(currentPh);

  /// True once pH ≥ 8.2 (phenolphthalein endpoint range).
  bool get atEndpoint => currentPh >= 8.2;

  /// Distance from equivalence in mL (negative = not yet there).
  double get deviationFromEquivalence => _deliveredMl - AcidBaseTitration.expectedTitreMl;

  /// Concentration of NaOH calculated from the current run once the
  /// endpoint is recorded (null until [recordEndpoint]).
  double? get calculatedTitrantConcentration {
    final init = _initialReadingMl;
    final fin = _finalReadingMl;
    if (init == null || fin == null) return null;
    final titre = fin - init;
    if (titre <= 0) return null;
    return concentrationFromMoles(analyteMoles, mLtoDm3(titre));
  }

  /// Burette reading at the current delivered volume (0.00 baseline until
  /// an initial reading is captured).
  double get buretteReading => (_initialReadingMl ?? 0) + _deliveredMl;

  // ── Workflow actions ──────────────────────────────────────────────────

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void goToStep(int index) {
    if (index < 0 || index >= AcidBaseTitration.definition.procedure.length) return;
    _currentStep = index;
    _emit();
  }

  void nextStep() => goToStep(_currentStep + 1);

  /// Steps 1–2: burette prepared; captures the initial reading.
  void fillBurette() {
    if (_phase != TitrationPhase.notStarted) return;
    _initialReadingMl = 0.00;
    _phase = TitrationPhase.ready;
    _emit();
  }

  /// Steps 3–4: flask prepared with indicator.
  void prepareFlask() {
    _flaskPrepared = true;
    _indicatorAdded = true;
    _emit();
  }

  /// Main action: deliver [amountMl] of NaOH (dropwise near the endpoint).
  void deliver(double amountMl) {
    if (_phase != TitrationPhase.ready && _phase != TitrationPhase.titrating) return;
    if (amountMl <= 0) return;
    final capacityLeft = AcidBaseTitration.buretteCapacityMl - _deliveredMl;
    final actual = amountMl.clamp(0.0, capacityLeft);
    if (actual == 0) return;
    _deliveredMl += actual;
    _phase = TitrationPhase.titrating;
    _provider?.updateSceneParams(_sceneParamsForDelivery());
    _emit();
  }

  /// Convenience: single drop (1/20 mL) — the careful endgame action.
  void deliverDrop() => deliver(1 / AcidBaseTitration.titrantDropsPerMl);

  /// Step 7: lock in the endpoint (only valid at/after the colour change).
  bool recordEndpoint() {
    if (_phase != TitrationPhase.titrating && _phase != TitrationPhase.ready) return false;
    if (!atEndpoint) return false;
    _finalReadingMl = buretteReading;
    _phase = TitrationPhase.endpointReached;
    _provider?.updateSceneParams(_sceneParamsEndpoint());
    _emit();
    return true;
  }

  /// Move to the analysis/assessment stage.
  void analyse() {
    if (_phase != TitrationPhase.endpointReached) return;
    _phase = TitrationPhase.analysed;
    _emit();
  }

  void submitAnswer(int questionIndex, String answer) {
    _answers[questionIndex] = answer.trim();
    _emit();
  }

  /// Full reset — the experiment is repeatable without reloading.
  void reset() {
    _phase = TitrationPhase.notStarted;
    _deliveredMl = 0;
    _initialReadingMl = null;
    _finalReadingMl = null;
    _indicatorAdded = false;
    _flaskPrepared = false;
    _currentStep = 0;
    _answers.clear();
    _provider?.reset();
    _emit();
  }

  // ── Scene parameter mapping (visual, driven by calculated values) ─────

  Map<String, dynamic> _sceneParamsForDelivery() {
    // Burette liquid drops as titrant is delivered; flask liquid stays
    // colourless until the endpoint. Fractions are derived from real
    // volumes, so the picture stays consistent with the numbers.
    final buretteFraction = 1 - _deliveredMl / AcidBaseTitration.buretteCapacityMl;
    final flaskColour = atEndpoint ? '#f9a8d4' : '#e8f4ff';
    return {
      'objects': {
        'burette_liquid': {
          'scale': [1.0, buretteFraction.clamp(0.0, 1.0), 1.0],
          'position': [0, 0, 0],
        },
        'flask_liquid': {'color': flaskColour},
      },
    };
  }

  Map<String, dynamic> _sceneParamsEndpoint() => {
        'objects': {
          'flask_liquid': {'color': '#f472b6'},
        },
      };

  void dispose() {
    _changes.close();
  }
}
