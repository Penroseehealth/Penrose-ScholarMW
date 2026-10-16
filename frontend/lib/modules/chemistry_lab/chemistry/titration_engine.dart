import 'dart:math' as math;

import 'indicator_model.dart';

/// Configurable educational starting values. These are simulation settings,
/// not universal laboratory requirements.
class TitrationSettings {
  final String acidId;
  final String baseId;
  final String acidName;
  final String baseName;
  final String acidFormula;
  final String baseFormula;

  /// Acid concentration \(C_a\) in mol/L.
  final double acidConcentrationMolPerL;

  /// Initial acid aliquot \(V_a\) in millilitres.
  final double acidVolumeMl;

  /// Base (titrant) concentration \(C_b\) in mol/L.
  final double baseConcentrationMolPerL;

  /// Initial burette reading in millilitres (usually 0.00).
  final double initialBuretteReadingMl;

  /// Nominal burette capacity.
  final double buretteCapacityMl;

  /// Conical flask working capacity used for liquid-level visuals.
  final double flaskCapacityMl;

  final IndicatorModel indicator;

  /// Acid:base stoichiometric coefficient ratio (both 1 for HCl + NaOH).
  final double acidStoich;
  final double baseStoich;

  const TitrationSettings({
    this.acidId = 'hcl',
    this.baseId = 'naoh',
    this.acidName = 'Hydrochloric acid',
    this.baseName = 'Sodium hydroxide',
    this.acidFormula = 'HCl',
    this.baseFormula = 'NaOH',
    this.acidConcentrationMolPerL = 0.100,
    this.acidVolumeMl = 25.00,
    this.baseConcentrationMolPerL = 0.100,
    this.initialBuretteReadingMl = 0.00,
    this.buretteCapacityMl = 50.00,
    this.flaskCapacityMl = 150.00,
    this.indicator = IndicatorModel.phenolphthalein,
    this.acidStoich = 1,
    this.baseStoich = 1,
  });

  TitrationSettings copyWith({
    String? acidId,
    String? baseId,
    String? acidName,
    String? baseName,
    String? acidFormula,
    String? baseFormula,
    double? acidConcentrationMolPerL,
    double? acidVolumeMl,
    double? baseConcentrationMolPerL,
    double? initialBuretteReadingMl,
    double? buretteCapacityMl,
    double? flaskCapacityMl,
    IndicatorModel? indicator,
    double? acidStoich,
    double? baseStoich,
  }) {
    return TitrationSettings(
      acidId: acidId ?? this.acidId,
      baseId: baseId ?? this.baseId,
      acidName: acidName ?? this.acidName,
      baseName: baseName ?? this.baseName,
      acidFormula: acidFormula ?? this.acidFormula,
      baseFormula: baseFormula ?? this.baseFormula,
      acidConcentrationMolPerL: acidConcentrationMolPerL ?? this.acidConcentrationMolPerL,
      acidVolumeMl: acidVolumeMl ?? this.acidVolumeMl,
      baseConcentrationMolPerL: baseConcentrationMolPerL ?? this.baseConcentrationMolPerL,
      initialBuretteReadingMl: initialBuretteReadingMl ?? this.initialBuretteReadingMl,
      buretteCapacityMl: buretteCapacityMl ?? this.buretteCapacityMl,
      flaskCapacityMl: flaskCapacityMl ?? this.flaskCapacityMl,
      indicator: indicator ?? this.indicator,
      acidStoich: acidStoich ?? this.acidStoich,
      baseStoich: baseStoich ?? this.baseStoich,
    );
  }
}

enum TitrationPhase { emptyFlask, beforeEquivalence, atEquivalence, afterEquivalence }

/// Immutable chemical and volumetric snapshot. Rendering must not recompute this.
class TitrationSnapshot {
  final TitrationSettings settings;
  final bool aliquotTransferred;
  final double deliveredVolumeMl;
  final double currentBuretteReadingMl;
  final double remainingBuretteMl;
  final double flaskVolumeMl;
  final double acidAmountMol;
  final double baseAmountMol;
  final double pH;
  final TitrationPhase phase;
  final double equivalenceVolumeMl;
  final bool endpointReached;
  final String indicatorColour;
  final int flaskRgb;
  final double flaskOpacity;
  final String statusLabel;
  final String? warning;

  const TitrationSnapshot({
    required this.settings,
    required this.aliquotTransferred,
    required this.deliveredVolumeMl,
    required this.currentBuretteReadingMl,
    required this.remainingBuretteMl,
    required this.flaskVolumeMl,
    required this.acidAmountMol,
    required this.baseAmountMol,
    required this.pH,
    required this.phase,
    required this.equivalenceVolumeMl,
    required this.endpointReached,
    required this.indicatorColour,
    required this.flaskRgb,
    required this.flaskOpacity,
    required this.statusLabel,
    this.warning,
  });

  double get buretteFill01 {
    final capacity = settings.buretteCapacityMl;
    if (capacity <= 0) return 0;
    return (remainingBuretteMl / capacity).clamp(0.0, 1.0);
  }

  double get flaskFill01 {
    final capacity = settings.flaskCapacityMl;
    if (capacity <= 0) return 0;
    return (flaskVolumeMl / capacity).clamp(0.02, 1.0);
  }

  List<({double volumeMl, double pH})> get curveHint => const [];
}

/// Strong acid–strong base titration calculation engine.
///
/// Approximations appropriate for MSCE / junior-secondary simulation:
/// - HCl and NaOH are fully dissociated.
/// - Volumes are additive; millilitres are converted to litres by ×10⁻³.
/// - Water autodissociation is neglected except at equivalence, where pH = 7.00
///   at 25 °C.
/// - Activity coefficients are 1.
/// - Mixing is instantaneous and isothermal.
///
/// The theoretical equivalence volume is
/// \( V_{\mathrm{eq}} = (C_a V_a / C_b) \times (n_a/n_b) \) and is never
/// hard-coded.
class TitrationEngine {
  TitrationSettings _settings;
  bool _aliquotTransferred = false;
  double _deliveredMl = 0;

  TitrationEngine({TitrationSettings? settings}) : _settings = settings ?? const TitrationSettings();

  TitrationSettings get settings => _settings;

  void applySettings(TitrationSettings settings) {
    _settings = settings;
    reset();
  }

  void reset() {
    _aliquotTransferred = false;
    _deliveredMl = 0;
  }

  /// Restores chemical amounts and readings without clearing saved trials.
  void resetRun() {
    _aliquotTransferred = false;
    _deliveredMl = 0;
  }

  void transferAliquot() {
    _aliquotTransferred = true;
    _deliveredMl = 0;
  }

  /// Sets delivered titrant volume in millilitres. Negative values are rejected.
  void setDeliveredVolumeMl(double millilitres) {
    if (!_aliquotTransferred) {
      _deliveredMl = 0;
      return;
    }
    _deliveredMl = _clampDelivered(millilitres);
  }

  void addDeliveredVolumeMl(double deltaMl) {
    if (!_aliquotTransferred) return;
    setDeliveredVolumeMl(_deliveredMl + deltaMl);
  }

  TitrationSnapshot snapshot() => compute(
        settings: _settings,
        aliquotTransferred: _aliquotTransferred,
        deliveredVolumeMl: _deliveredMl,
      );

  double _clampDelivered(double millilitres) {
    if (millilitres.isNaN || millilitres.isInfinite) return _deliveredMl;
    final maxDeliverable = _settings.buretteCapacityMl - _settings.initialBuretteReadingMl;
    if (millilitres < 0) return 0;
    if (millilitres > maxDeliverable) return maxDeliverable;
    return millilitres;
  }

  /// Pure function used by tests and by the live session.
  static TitrationSnapshot compute({
    required TitrationSettings settings,
    required bool aliquotTransferred,
    required double deliveredVolumeMl,
  }) {
    final warning = _validate(settings, deliveredVolumeMl);
    final equivalenceMl = equivalenceVolumeMl(settings);
    if (!aliquotTransferred) {
      return TitrationSnapshot(
        settings: settings,
        aliquotTransferred: false,
        deliveredVolumeMl: 0,
        currentBuretteReadingMl: settings.initialBuretteReadingMl,
        remainingBuretteMl: settings.buretteCapacityMl - settings.initialBuretteReadingMl,
        flaskVolumeMl: 0,
        acidAmountMol: 0,
        baseAmountMol: 0,
        pH: double.nan,
        phase: TitrationPhase.emptyFlask,
        equivalenceVolumeMl: equivalenceMl,
        endpointReached: false,
        indicatorColour: 'no solution',
        flaskRgb: 0xD7E8F0,
        flaskOpacity: 0.08,
        statusLabel: 'Transfer the acid aliquot into the conical flask.',
        warning: warning,
      );
    }

    final maxDeliverable = settings.buretteCapacityMl - settings.initialBuretteReadingMl;
    var delivered = deliveredVolumeMl;
    if (delivered.isNaN || delivered.isInfinite || delivered < 0) delivered = 0;
    if (delivered > maxDeliverable) delivered = maxDeliverable;

    final vaL = settings.acidVolumeMl / 1000.0;
    final vbL = delivered / 1000.0;
    final na = settings.acidConcentrationMolPerL * vaL;
    final nb = settings.baseConcentrationMolPerL * vbL;
    final flaskMl = settings.acidVolumeMl + delivered;
    final reading = settings.initialBuretteReadingMl + delivered;
    final remaining = settings.buretteCapacityMl - reading;
    final ph = strongAcidStrongBasePh(
      acidAmountMol: na,
      baseAmountMol: nb,
      totalVolumeL: flaskMl / 1000.0,
      acidStoich: settings.acidStoich,
      baseStoich: settings.baseStoich,
    );
    final phase = _phase(na, nb, settings.acidStoich, settings.baseStoich);
    final pink = settings.indicator.pinkAmount(ph);
    final endpoint = pink >= 0.05;
    return TitrationSnapshot(
      settings: settings,
      aliquotTransferred: true,
      deliveredVolumeMl: delivered,
      currentBuretteReadingMl: reading,
      remainingBuretteMl: remaining < 0 ? 0 : remaining,
      flaskVolumeMl: flaskMl,
      acidAmountMol: na,
      baseAmountMol: nb,
      pH: ph,
      phase: phase,
      equivalenceVolumeMl: equivalenceMl,
      endpointReached: endpoint,
      indicatorColour: settings.indicator.colourLabel(ph),
      flaskRgb: settings.indicator.flaskRgb(ph),
      flaskOpacity: settings.indicator.flaskOpacity(ph),
      statusLabel: _status(phase, endpoint, delivered, equivalenceMl),
      warning: warning,
    );
  }

  /// \( V_{\mathrm{eq}} \) in millilitres from the configured concentrations.
  static double equivalenceVolumeMl(TitrationSettings settings) {
    if (settings.baseConcentrationMolPerL <= 0) {
      return double.infinity;
    }
    final vaL = settings.acidVolumeMl / 1000.0;
    final na = settings.acidConcentrationMolPerL * vaL;
    final vbL = (na * settings.baseStoich) / (settings.baseConcentrationMolPerL * settings.acidStoich);
    return vbL * 1000.0;
  }

  /// Idealised pH for a fully dissociated monoprotic strong acid / strong base.
  static double strongAcidStrongBasePh({
    required double acidAmountMol,
    required double baseAmountMol,
    required double totalVolumeL,
    double acidStoich = 1,
    double baseStoich = 1,
    double equivalenceToleranceMol = 5e-8,
  }) {
    if (totalVolumeL <= 0) return double.nan;
    final acidEquivalents = acidAmountMol * acidStoich;
    final baseEquivalents = baseAmountMol * baseStoich;
    final excessBase = baseEquivalents - acidEquivalents;
    if (excessBase.abs() <= equivalenceToleranceMol) {
      return 7.00;
    }
    if (excessBase < 0) {
      final hydrogen = -excessBase / totalVolumeL;
      if (hydrogen <= 0) return 7.00;
      return -_log10(hydrogen);
    }
    final hydroxide = excessBase / totalVolumeL;
    final pOh = -_log10(hydroxide);
    return 14.0 - pOh;
  }

  static List<({double volumeMl, double pH})> curvePoints({
    required TitrationSettings settings,
    required double deliveredVolumeMl,
    double stepMl = 0.50,
  }) {
    final points = <({double volumeMl, double pH})>[];
    final end = deliveredVolumeMl < 0 ? 0.0 : deliveredVolumeMl;
    var v = 0.0;
    while (v < end - 1e-9) {
      final snap = compute(settings: settings, aliquotTransferred: true, deliveredVolumeMl: v);
      points.add((volumeMl: v, pH: snap.pH));
      v += stepMl;
    }
    final last = compute(settings: settings, aliquotTransferred: true, deliveredVolumeMl: end);
    points.add((volumeMl: end, pH: last.pH));
    return points;
  }

  static TitrationPhase _phase(double na, double nb, double acidStoich, double baseStoich) {
    final excess = nb * baseStoich - na * acidStoich;
    if (excess.abs() <= 5e-8) return TitrationPhase.atEquivalence;
    if (excess < 0) return TitrationPhase.beforeEquivalence;
    return TitrationPhase.afterEquivalence;
  }

  static String _status(TitrationPhase phase, bool endpoint, double delivered, double equivalence) {
    switch (phase) {
      case TitrationPhase.emptyFlask:
        return 'No aliquot in the flask.';
      case TitrationPhase.beforeEquivalence:
        return 'Acid remains in excess. Continue adding sodium hydroxide slowly.';
      case TitrationPhase.atEquivalence:
        return 'Theoretical equivalence point. Phenolphthalein is still colourless at pH 7.';
      case TitrationPhase.afterEquivalence:
        if (endpoint) {
          return 'Indicator endpoint: persistent faint pink. This approximates, but is not identical to, theoretical equivalence (${equivalence.toStringAsFixed(2)} mL).';
        }
        return 'Base is in excess (${delivered.toStringAsFixed(2)} mL delivered).';
    }
  }

  static String? _validate(TitrationSettings settings, double delivered) {
    if (settings.acidConcentrationMolPerL < 0 || settings.baseConcentrationMolPerL < 0) {
      return 'Concentrations cannot be negative.';
    }
    if (settings.acidVolumeMl < 0 || delivered < 0) {
      return 'Volumes cannot be negative.';
    }
    if (settings.acidId == 'agno3' && settings.baseId == 'hcl') {
      return 'Silver nitrate and hydrochloric acid are not a supported titration pair in this practical.';
    }
    return null;
  }

  static double _log10(double value) => value <= 0 ? double.nan : math.log(value) / math.ln10;
}
