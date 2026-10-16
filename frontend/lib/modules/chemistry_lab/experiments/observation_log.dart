class ObservationEntry {
  final DateTime at;
  final String text;

  const ObservationEntry({required this.at, required this.text});
}

class ObservationLog {
  final List<ObservationEntry> entries = [];

  void add(String text, {DateTime? at}) {
    entries.add(ObservationEntry(at: at ?? DateTime.now(), text: text));
  }

  void clear() => entries.clear();
}

class TitrationTrial {
  final int number;
  final double initialReadingMl;
  final double finalReadingMl;
  bool includedInMean;

  TitrationTrial({
    required this.number,
    required this.initialReadingMl,
    required this.finalReadingMl,
    this.includedInMean = true,
  });

  double get titreMl => finalReadingMl - initialReadingMl;
}

class TrialDataset {
  final List<TitrationTrial> trials = [];

  /// School-level concordant-titre window, typically 0.20 mL.
  double concordantWindowMl = 0.20;

  void add(TitrationTrial trial) => trials.add(trial);

  void clear() => trials.clear();

  List<TitrationTrial> get selected => trials.where((trial) => trial.includedInMean).toList();

  /// Concordant if every selected titre lies within [concordantWindowMl] of the others.
  bool get selectedAreConcordant {
    final values = selected.map((trial) => trial.titreMl).toList();
    if (values.length < 2) return values.isNotEmpty;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    return (maxV - minV) <= concordantWindowMl + 1e-9;
  }

  double? get meanSelectedTitreMl {
    final values = selected;
    if (values.isEmpty) return null;
    final sum = values.fold<double>(0, (total, trial) => total + trial.titreMl);
    return sum / values.length;
  }
}
