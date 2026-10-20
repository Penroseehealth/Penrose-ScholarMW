import 'package:flutter/material.dart';

import 'neuron_anatomy.dart';

/// Explanation panel for a selected [NeuronStructure] (Phase 4).
///
/// Shows the correct name, a plain-language function, a more detailed
/// explanation, its role in signal transmission and a short "What to observe"
/// note — everything sourced from the shared anatomy catalogue so the panel
/// never contradicts the diagram.
class NeuronInfoPanel extends StatelessWidget {
  const NeuronInfoPanel({
    super.key,
    required this.structure,
    required this.accent,
    required this.onClose,
    this.dark = false,
  });

  final NeuronStructure structure;
  final Color accent;
  final VoidCallback onClose;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? const Color(0xFFF2F1F8) : const Color(0xFF1E1E2A);
    final mut = dark ? const Color(0xFF9A98AC) : const Color(0xFF6B6B7E);
    final signalColor = structure.signal == NeuronSignal.electrical ? const Color(0xFFF59E0B) : const Color(0xFF14B8A6);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  structure.marker,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  structure.name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: signalColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${structure.signal.label} · ${structure.signal.detail}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: signalColor),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: mut,
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('Function', structure.function, ink, mut),
          const SizedBox(height: 6),
          _row('In detail', structure.detail, ink, mut),
          const SizedBox(height: 6),
          _row('Role in transmission', structure.roleInTransmission, ink, mut),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.visibility_outlined, size: 15, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'What to observe: ${structure.observe}',
                  style: TextStyle(fontSize: 12, height: 1.4, fontStyle: FontStyle.italic, color: ink),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color ink, Color mut) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: mut)),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 13, height: 1.4, color: ink)),
        ],
      );
}
