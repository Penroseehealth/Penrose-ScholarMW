import 'package:flutter/material.dart';

/// Parameters describing what the [NeuronPainter] should draw for one frame.
///
/// `stage` is the global stage index (0..8) into the neuron communication
/// timeline; `progress` is the intra-stage position (0..1). When [animate] is
/// false the painter renders the static anatomical scene only - this powers the
/// "Anatomical view" mode while the viewer drives the functional animation.
@immutable
class NeuronScene {
  final int stage;
  final double progress;
  final bool labelsOn;
  final bool dark;
  final bool animate;

  /// Id of the currently selected structure (Phase 4), or null.
  final String? selectedId;

  const NeuronScene({
    this.stage = 0,
    this.progress = 0,
    this.labelsOn = true,
    this.dark = false,
    this.animate = true,
    this.selectedId,
  });

  NeuronScene copyWith({
    int? stage,
    double? progress,
    bool? labelsOn,
    bool? dark,
    bool? animate,
    String? selectedId,
    bool clearSelection = false,
  }) =>
      NeuronScene(
        stage: stage ?? this.stage,
        progress: progress ?? this.progress,
        labelsOn: labelsOn ?? this.labelsOn,
        dark: dark ?? this.dark,
        animate: animate ?? this.animate,
        selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
      );
}

/// Color scheme for the neuron scene (light/dark aware).
@immutable
class NeuronPalette {
  const NeuronPalette({required this.dark});

  final bool dark;

  static const Color _signal = Color(0xFFFFB020);
  static const Color _nt = Color(0xFF2DD4BF);

  Color get signal => _signal;
  Color get neurotransmitter => _nt;

  Color get presynapticFill => dark ? const Color(0xFF41406E) : const Color(0xFFB7C4FF);
  Color get presynapticStroke => dark ? const Color(0xFF9AA0FF) : const Color(0xFF4F5AA8);
  Color get postFill => dark ? const Color(0xFF3E3A5C) : const Color(0xFFC9B8FF);
  Color get postStroke => dark ? const Color(0xFFA78BFA) : const Color(0xFF6D4FC9);
  Color get postDendrite => dark ? const Color(0xFF8B7AD8) : const Color(0xFF7D6BC4);
  Color get axon => dark ? const Color(0xFFC9C2FF) : const Color(0xFF6B79C9);
  Color get myelinFill => dark ? const Color(0xFF4A4A6A) : const Color(0xFFEFEAF2);
  Color get myelinStroke => dark ? const Color(0xFF7C7A9C) : const Color(0xFFB9B0C9);
  Color get nucleusFill => dark ? const Color(0xFF574080) : const Color(0xFF8A5BD6);
  Color get nucleusStroke => dark ? const Color(0xFFB79CFF) : const Color(0xFF6B3FB8);
  Color get nucleusNucleolus => dark ? const Color(0xFF8B5CF6) : const Color(0xFFB79CFF);
  Color get vesicle => const Color(0xFFFFC857);
  Color get vesicleStroke => dark ? const Color(0xFF917A22) : const Color(0xFFB38B1B);
  Color get cleftFill => dark ? const Color(0xFF23233A) : const Color(0xFFEDEBF5);
  Color get cleftFrame => dark ? const Color(0xFF3A3A58) : const Color(0xFFD6D2E6);
  Color get receptor => dark ? const Color(0xFF8B5CF6) : const Color(0xFF7C3AED);
  Color get receptorGlow => dark ? const Color(0xFFFFB020) : const Color(0xFFF59E0B);
  Color get ion => dark ? const Color(0xFF9AA0FF) : const Color(0xFF52608F);
  Color get ionHalo => dark ? const Color(0x229AA0FF) : const Color(0x224F5AA8);
  Color get ionText => dark ? const Color(0xFF0A0A14) : const Color(0xFFFFFFFF);
  Color get naIon => dark ? const Color(0xFF60A5FA) : const Color(0xFF2B6FC2);
  Color get postGlow => _nt;
  Color get signalCore => dark ? const Color(0xFF0A0A14) : const Color(0xFFFFFFFF);
  Color get labelInk => dark ? const Color(0xFFF2F1F8) : const Color(0xFF2A2A40);
  Color get halo => _haloColor();
  Color get leader => dark ? const Color(0xB39AA0FF) : const Color(0xB34F5AA8);
  Color get leaderDot => dark ? const Color(0xFF9AA0FF) : const Color(0xFF4F5AA8);

  Color _haloColor() {
    if (!dark) return const Color(0xFFF6F5FA);
    return const Color(0xFF0A0A14);
  }
}
