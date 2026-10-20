/// Reusable foundation for animated biological process simulations.
///
/// A [SimulationStage] is a step of a multi-part biological process. The
/// generic [ProcessSimulationViewer] (see `process_simulation_viewer.dart`)
/// plays, pauses, steps through and zooms the stages, supports label /
/// explanation toggles, speed control, fullscreen and a progressive "Teach
/// Mode". Each stage is drawn by the caller through a `SimulationFrame` so
/// future simulations (muscle contraction, cardiac conduction, reflex arc,
/// neuromuscular junction, hormonal signalling, DNA replication, protein
/// synthesis, mitosis/meiosis, gas exchange, photosynthesis, ...) reuse the
/// same player without changing player code.
library;

/// One labelled, explainable step of a biological process simulation.
class SimulationStage {
  /// Stable id (e.g. `'neurotransmitter_release'`).
  final String id;

  /// Short display title (e.g. `'Neurotransmitter release'`).
  final String title;

  /// Curriculum-appropriate description shown in the explanation panel.
  final String explanation;

  /// Heading of the teach-mode group this stage belongs to. Stages sharing a
  /// group are revealed together by "Teach Mode" (e.g. all synapse stages).
  final String teachGroup;

  const SimulationStage({
    required this.id,
    required this.title,
    required this.explanation,
    required this.teachGroup,
  });
}

/// What the caller's frame builder receives each tick.
///
/// `progress` is the normalised position (0..1) inside the current stage, so a
/// painter can smoothly animate intra-stage movement (signal pulses,
/// neurotransmitter particles, vesicle fusion, ...).
class SimulationFrame {
  /// Index into the full [SimulationStage] list (teach mode excluded still
  /// reports the global index so the painter knows which structure slice to
  /// render).
  final int stageIndex;

  final SimulationStage stage;

  /// 0..1 position within the current stage.
  final double progress;

  final bool labelsOn;

  /// True when the surrounding theme is dark.
  final bool dark;

  const SimulationFrame({
    required this.stageIndex,
    required this.stage,
    required this.progress,
    required this.labelsOn,
    required this.dark,
  });

  bool get isFirstStage => stageIndex == 0;
}

/// A user-controlled teaching mode (Phase 5).
///
/// Each mode is a named, ordered slice of the global stage timeline so the
/// learner can focus on one biological process at a time while the painter
/// still receives the true global stage index. `isSimplified` marks animations
/// that intentionally omit biological detail (the screen shows a "simplified
/// model" note for those).
class SimulationMode {
  final String id;
  final String title;
  final String subtitle;

  /// First global stage index included in this mode (inclusive).
  final int firstStage;

  /// Last global stage index included in this mode (inclusive).
  final int lastStage;

  final bool isSimplified;

  const SimulationMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.firstStage,
    required this.lastStage,
    this.isSimplified = false,
  });

  int get stageCount => lastStage - firstStage + 1;
}

/// The static disciplines a painter can visualise independently of the stage
/// timeline (anatomical view vs functional animation).
enum SimulationView { structure, function }

/// Convenience definition of a teach group derived from the stage list.
class TeachStep {
  final String title;
  final int firstStage;
  final int lastStage;
  final List<SimulationStage> stages;

  const TeachStep({
    required this.title,
    required this.firstStage,
    required this.lastStage,
    required this.stages,
  });
}

/// Build the progressive teach-mode reveal from an ordered stage list.
///
/// Consecutive stages sharing a [SimulationStage.teachGroup] collapse into one
/// teach step, preserving the requested reveal order.
List<TeachStep> buildTeachSteps(List<SimulationStage> stages) {
  final steps = <TeachStep>[];
  var start = 0;
  var cursor = 0;
  while (cursor < stages.length) {
    final group = stages[start].teachGroup;
    while (cursor + 1 < stages.length && stages[cursor + 1].teachGroup == group) {
      cursor++;
    }
    steps.add(TeachStep(
      title: group,
      firstStage: start,
      lastStage: cursor,
      stages: stages.sublist(start, cursor + 1),
    ));
    start = cursor + 1;
    cursor = start;
  }
  return steps;
}
