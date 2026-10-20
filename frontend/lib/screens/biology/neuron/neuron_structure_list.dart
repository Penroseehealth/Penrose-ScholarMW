import 'package:flutter/material.dart';

import 'neuron_anatomy.dart';

/// Accessible, text-based structure list for the neuron diagram (Phase 2/4).
///
/// Renders every [NeuronStructure] grouped by [NeuronRegion], each with its
/// colour-independent marker. Used as the way to explore structures on narrow
/// screens and by assistive technology, so labels are never the only means of
/// identifying a structure. Selecting an entry reports the structure id.
class NeuronStructureList extends StatelessWidget {
  const NeuronStructureList({
    super.key,
    required this.accent,
    required this.onSelect,
    this.selectedId,
    this.dark = false,
  });

  final Color accent;
  final ValueChanged<String> onSelect;
  final String? selectedId;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final groups = <NeuronRegion, List<NeuronStructure>>{};
    for (final s in neuronStructures) {
      groups.putIfAbsent(s.region, () => []).add(s);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final region in NeuronRegion.values)
          if (groups[region] != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                region.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in groups[region]!) _chip(context, s),
              ],
            ),
          ],
      ],
    );
  }

  Widget _chip(BuildContext context, NeuronStructure s) {
    final selected = s.id == selectedId;
    final ink = dark ? const Color(0xFFF2F1F8) : const Color(0xFF1E1E2A);
    final mut = dark ? const Color(0xFF9A98AC) : const Color(0xFF6B6B7E);
    return Semantics(
      button: true,
      selected: selected,
      label: '${s.name}. ${s.function}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelect(s.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? accent.withValues(alpha: 0.55) : mut.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  s.marker,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: selected ? accent : ink),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                s.shortName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? accent : ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
