import 'dart:async';

import 'package:flutter/foundation.dart';

import '../apparatus/apparatus_catalog.dart';
import '../bridge/chemistry_lab_events.dart';
import '../bridge/chemistry_lab_scene_bridge.dart';
import '../chemistry/reagent.dart';
import '../chemistry/reagent_registry.dart';
import '../chemistry/titration_engine.dart';
import '../experiments/experiment_definition.dart';
import '../experiments/observation_log.dart';

enum TitrationRunState { idle, running, paused, completed }

/// Owns the titration engine, trial records and visual-state push to Three.js.
class ChemistryLabProvider extends ChangeNotifier {
  ChemistryLabProvider({required ChemistryLabSceneBridge bridge}) : _bridge = bridge {
    _eventSub = _bridge.events.listen(_onEngineEvent);
  }

  final ChemistryLabSceneBridge _bridge;
  final TitrationEngine _engine = TitrationEngine();
  final ObservationLog observations = ObservationLog();
  final TrialDataset trials = TrialDataset();
  StreamSubscription<ChemistryLabEvent>? _eventSub;
  Timer? _deliveryTimer;
  bool _endpointLogged = false;

  ExperimentDefinition currentExperiment = ExperimentCatalog.acidBaseTitration;
  ApparatusItem? selectedApparatus;
  Reagent? selectedReagent;
  TitrationRunState runState = TitrationRunState.idle;
  bool inventoryOpen = true;
  bool helpOpen = false;
  String? sceneError;

  /// Stopcock opening from 0 (closed) to 1 (fully open).
  double stopcockOpening = 0;

  /// Fast delivery when fully open: about 0.40 mL/s. Dropwise when barely open.
  static const double _maxRateMlPerS = 0.40;

  TitrationSnapshot get snapshot => _engine.snapshot();

  List<({double volumeMl, double pH})> get curvePoints {
    final snap = snapshot;
    if (!snap.aliquotTransferred) return const [];
    return TitrationEngine.curvePoints(
      settings: snap.settings,
      deliveredVolumeMl: snap.deliveredVolumeMl,
      stepMl: 0.50,
    );
  }

  void _onEngineEvent(ChemistryLabEvent event) {
    switch (event) {
      case ChemistryLabSelectionEvent(:final id, :final name):
        selectedApparatus = id == null ? null : ApparatusCatalog.byId(id);
        selectedApparatus ??= id == null
            ? null
            : ApparatusItem(id: id, name: name ?? id, category: 'Laboratory', description: name ?? id);
        notifyListeners();
      case ChemistryLabStopcockEvent(:final open):
        setStopcockOpening(open ? (stopcockOpening < 0.15 ? 0.35 : stopcockOpening) : 0);
      case ChemistryLabErrorEvent(:final message):
        sceneError = message;
        notifyListeners();
      case ChemistryLabReadyEvent():
        _pushVisual();
    }
  }

  void selectApparatus(String? id) {
    selectedApparatus = id == null ? null : ApparatusCatalog.byId(id);
    _bridge.selectObject(id);
    notifyListeners();
  }

  void selectReagent(Reagent reagent) {
    selectedReagent = reagent;
    notifyListeners();
  }

  void selectExperiment(ExperimentDefinition definition) {
    currentExperiment = definition;
    observations.add('Selected practical: ${definition.title}.');
    if (definition.id == ExperimentCatalog.acidBaseTitration.id) {
      _bridge.focusTitrationBench();
    }
    notifyListeners();
  }

  void applySettings(TitrationSettings settings) {
    if (settings.acidConcentrationMolPerL < 0 || settings.baseConcentrationMolPerL < 0 || settings.acidVolumeMl < 0) {
      observations.add('Rejected invalid settings: concentrations and volumes must not be negative.');
      notifyListeners();
      return;
    }
    _stopDelivery(pauseOnly: true);
    _engine.applySettings(settings);
    runState = TitrationRunState.idle;
    stopcockOpening = 0;
    _endpointLogged = false;
    observations.add(
      'Settings updated: ${settings.acidFormula} ${settings.acidConcentrationMolPerL.toStringAsFixed(3)} mol/L, '
      '${settings.acidVolumeMl.toStringAsFixed(2)} mL; ${settings.baseFormula} '
      '${settings.baseConcentrationMolPerL.toStringAsFixed(3)} mol/L.',
    );
    _pushVisual();
    notifyListeners();
  }

  void transferAliquot() {
    _engine.transferAliquot();
    runState = TitrationRunState.idle;
    _endpointLogged = false;
    observations.add(
      'Transferred ${snapshot.settings.acidVolumeMl.toStringAsFixed(2)} mL of '
      '${snapshot.settings.acidName} into the conical flask. Added phenolphthalein.',
    );
    _pushVisual();
    notifyListeners();
  }

  void setStopcockOpening(double value) {
    stopcockOpening = value.clamp(0.0, 1.0);
    if (stopcockOpening <= 0) {
      _stopDelivery(pauseOnly: true);
    } else if (snapshot.aliquotTransferred && runState != TitrationRunState.completed) {
      startDelivery();
    }
    _pushVisual();
    notifyListeners();
  }

  void startDelivery() {
    if (!snapshot.aliquotTransferred) {
      observations.add('Transfer the acid aliquot before opening the stopcock.');
      notifyListeners();
      return;
    }
    if (stopcockOpening <= 0) stopcockOpening = 0.25;
    final alreadyRunning = runState == TitrationRunState.running && _deliveryTimer != null;
    runState = TitrationRunState.running;
    if (alreadyRunning) {
      _pushVisual();
      notifyListeners();
      return;
    }
    _deliveryTimer?.cancel();
    var last = DateTime.now();
    _deliveryTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final now = DateTime.now();
      final dt = now.difference(last).inMilliseconds / 1000.0;
      last = now;
      if (runState != TitrationRunState.running || stopcockOpening <= 0) return;
      final before = snapshot.deliveredVolumeMl;
      _engine.addDeliveredVolumeMl(_maxRateMlPerS * stopcockOpening * dt);
      final after = snapshot.deliveredVolumeMl;
      if (after <= before + 1e-9 &&
          after >= snapshot.settings.buretteCapacityMl - snapshot.settings.initialBuretteReadingMl - 1e-9) {
        _complete('Burette emptied.');
        return;
      }
      if (snapshot.endpointReached && !_endpointLogged) {
        _endpointLogged = true;
        observations.add(
          'Persistent faint pink observed at ${snapshot.currentBuretteReadingMl.toStringAsFixed(2)} mL '
          '(${snapshot.deliveredVolumeMl.toStringAsFixed(2)} mL delivered).',
        );
      }
      _pushVisual();
      notifyListeners();
    });
    observations.add('Stopcock opened. Titrant is being delivered.');
    _pushVisual();
    notifyListeners();
  }

  void pauseDelivery() {
    _stopDelivery(pauseOnly: true);
    if (runState == TitrationRunState.running) {
      runState = TitrationRunState.paused;
      observations.add('Delivery paused at ${snapshot.currentBuretteReadingMl.toStringAsFixed(2)} mL.');
    }
    stopcockOpening = 0;
    _pushVisual();
    notifyListeners();
  }

  void completeTrial() {
    if (!snapshot.aliquotTransferred) return;
    _complete('Trial recorded by the learner.');
  }

  void _complete(String reason) {
    _stopDelivery(pauseOnly: true);
    stopcockOpening = 0;
    runState = TitrationRunState.completed;
    final trial = TitrationTrial(
      number: trials.trials.length + 1,
      initialReadingMl: snapshot.settings.initialBuretteReadingMl,
      finalReadingMl: snapshot.currentBuretteReadingMl,
    );
    trials.add(trial);
    observations.add(
      '$reason Trial ${trial.number}: initial ${trial.initialReadingMl.toStringAsFixed(2)} mL, '
      'final ${trial.finalReadingMl.toStringAsFixed(2)} mL, titre ${trial.titreMl.toStringAsFixed(2)} mL.',
    );
    _pushVisual();
    notifyListeners();
  }

  void resetRun() {
    _stopDelivery(pauseOnly: true);
    _engine.resetRun();
    runState = TitrationRunState.idle;
    stopcockOpening = 0;
    _endpointLogged = false;
    selectedApparatus = null;
    observations.add('Run reset. Flask emptied. Burette restored to the initial reading. Trial records kept.');
    _pushVisual();
    notifyListeners();
  }

  void clearTrials() {
    trials.clear();
    observations.add('Trial dataset cleared.');
    notifyListeners();
  }

  void toggleTrial(int index, bool included) {
    if (index < 0 || index >= trials.trials.length) return;
    trials.trials[index].includedInMean = included;
    notifyListeners();
  }

  void toggleInventory() {
    inventoryOpen = !inventoryOpen;
    notifyListeners();
  }

  void resetCamera() => _bridge.resetCamera();

  void focusTitration() => _bridge.focusTitrationBench();

  void _stopDelivery({required bool pauseOnly}) {
    _deliveryTimer?.cancel();
    _deliveryTimer = null;
    if (!pauseOnly) runState = TitrationRunState.idle;
  }

  void _pushVisual() {
    final snap = snapshot;
    try {
      _bridge.setVisualState({
        'buretteFill01': snap.buretteFill01,
        'buretteReadingMl': snap.currentBuretteReadingMl,
        'flaskFill01': snap.aliquotTransferred ? snap.flaskFill01 : 0.0,
        'flaskRgb': snap.flaskRgb,
        'flaskOpacity': snap.flaskOpacity,
        'dripping': runState == TitrationRunState.running && stopcockOpening > 0,
        'stopcockOpening': stopcockOpening,
        'swirl': runState == TitrationRunState.running ? 1.0 : 0.0,
        'selectedId': selectedApparatus?.id,
      });
    } catch (_) {
      // Visual push is best-effort when the 3D engine is not running.
    }
  }

  List<Reagent> get reagents => ReagentRegistry.all;

  @override
  void dispose() {
    _deliveryTimer?.cancel();
    _eventSub?.cancel();
    _bridge.dispose();
    super.dispose();
  }
}
