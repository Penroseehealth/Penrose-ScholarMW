/// School-level phenolphthalein indicator model.
///
/// Transition range follows the usual aqueous values: colourless below pH 8.2
/// and red-pink above pH 10, with a smooth ramp in between. Colourless near
/// neutrality is therefore expected, including at the strong-acid/strong-base
/// equivalence point (pH ≈ 7).
class IndicatorModel {
  final String id;
  final String name;
  final double colourlessBelowPh;
  final double fullyPinkAbovePh;

  const IndicatorModel({
    required this.id,
    required this.name,
    required this.colourlessBelowPh,
    required this.fullyPinkAbovePh,
  });

  static const phenolphthalein = IndicatorModel(
    id: 'phenolphthalein',
    name: 'Phenolphthalein',
    colourlessBelowPh: 8.2,
    fullyPinkAbovePh: 10.0,
  );

  /// 0 = colourless, 1 = fully pink.
  double pinkAmount(double ph) {
    if (ph <= colourlessBelowPh) return 0;
    if (ph >= fullyPinkAbovePh) return 1;
    return (ph - colourlessBelowPh) / (fullyPinkAbovePh - colourlessBelowPh);
  }

  String colourLabel(double ph) {
    final pink = pinkAmount(ph);
    if (pink <= 0) return 'colourless';
    if (pink < 0.18) return 'faint pink';
    if (pink < 0.7) return 'pink';
    return 'deep pink';
  }

  /// Packed RGB used by the 3D flask liquid. Colourless solutions keep a faint
  /// glass-water tint so the liquid surface remains visible.
  int flaskRgb(double ph) {
    final t = pinkAmount(ph);
    const waterR = 0xD7;
    const waterG = 0xE8;
    const waterB = 0xF0;
    const pinkR = 0xE8;
    const pinkG = 0x6A;
    const pinkB = 0xA0;
    final r = (waterR + (pinkR - waterR) * t).round();
    final g = (waterG + (pinkG - waterG) * t).round();
    final b = (waterB + (pinkB - waterB) * t).round();
    return (r << 16) | (g << 8) | b;
  }

  double flaskOpacity(double ph) => 0.28 + 0.42 * pinkAmount(ph);
}
