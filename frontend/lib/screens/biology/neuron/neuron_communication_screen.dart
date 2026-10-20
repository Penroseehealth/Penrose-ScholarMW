import 'package:flutter/material.dart';

import '../../../core/theme/theme_colors.dart';
import 'neuron_anatomy.dart';
import 'neuron_info_panel.dart';
import 'neuron_painter.dart';
import 'neuron_scene.dart';
import 'neuron_structure_list.dart';
import 'process_simulation.dart';
import 'process_simulation_viewer.dart';

const Color _neuronAccent = Color(0xFF7C3AED);

/// Neuron Communication Module.
///
/// Animated, curriculum-accurate two-neuron communication built on the reusable
/// [ProcessSimulationViewer]. The [NeuronPainter] renders every stage
/// (resting state, action potential, saltatory propagation, arrival,
/// neurotransmitter release, synaptic transmission, receptor binding,
/// postsynaptic response and signal continuation) with the same electrical /
/// chemical separation rules the learner is expected to distinguish.
class NeuronCommunicationScreen extends StatefulWidget {
  const NeuronCommunicationScreen({super.key});

  @override
  State<NeuronCommunicationScreen> createState() => _NeuronCommunicationScreenState();
}

class _NeuronCommunicationScreenState extends State<NeuronCommunicationScreen> {
  /// Teaching modes (Phase 5): Mode A electrical conduction, Mode B chemical
  /// synaptic transmission, Mode C guided step-by-step (the full lesson).
  static const List<SimulationMode> _modes = [
    SimulationMode(
      id: 'electrical',
      title: 'A · Electrical impulse',
      subtitle: 'Action potential travels along the axon (saltatory conduction).',
      firstStage: 1,
      lastStage: 3,
    ),
    SimulationMode(
      id: 'chemical',
      title: 'B · Chemical transmission',
      subtitle: 'Vesicle release, diffusion across the cleft and receptor binding.',
      firstStage: 3,
      lastStage: 8,
      isSimplified: true,
    ),
    SimulationMode(
      id: 'lesson',
      title: 'C · Guided lesson',
      subtitle: 'Every stage, one at a time, with explanations.',
      firstStage: 0,
      lastStage: 8,
    ),
  ];

  static const List<SimulationStage> _stages = [
    SimulationStage(
      id: 'resting_state',
      title: 'Resting neurone',
      explanation: 'A neurone at rest is polarised: the inside of the membrane is more '
          'negative than the outside (resting potential of about -70 mV) because '
          'the sodium-potassium pump keeps more K⁺ inside and more Na⁺ outside.',
      teachGroup: '1. Neurone structure',
    ),
    SimulationStage(
      id: 'stimulus',
      title: 'Stimulus and depolarisation',
      explanation: 'A stimulus of threshold strength causes Na⁺ gates at the trigger zone '
          'to open. Sodium ions rush in and the membrane potential rises, '
          'reversing the polarity (depolarisation).',
      teachGroup: '2. Action potential',
    ),
    SimulationStage(
      id: 'propagation',
      title: 'Saltatory conduction',
      explanation: 'The action potential travels along the axon because the depolarised '
          'patch of membrane depolarises the next patch. Between the myelin '
          'sheath gaps (nodes of Ranvier) the impulse jumps from node to node, '
          'which is faster and saves energy — this is saltatory conduction.',
      teachGroup: '3. Signal propagation',
    ),
    SimulationStage(
      id: 'arrival',
      title: 'Arrival at the axon terminal',
      explanation: 'When the impulse reaches the axon terminal, membrane depolarisation '
          'opens voltage-gated calcium channels. Calcium ions flow into the '
          'terminal and trigger the synaptic vesicles to move towards the '
          'presynaptic membrane.',
      teachGroup: '4. Synaptic vesicles',
    ),
    SimulationStage(
      id: 'release',
      title: 'Neurotransmitter release',
      explanation: 'Vesicles fuse with the presynaptic membrane and release '
          'neurotransmitter molecules into the synaptic cleft by exocytosis. '
          'This is the chemical step — the signal becomes chemical.',
      teachGroup: '5. Neurotransmitter release',
    ),
    SimulationStage(
      id: 'transmission',
      title: 'Diffusion across the cleft',
      explanation: 'Neurotransmitters diffuse across the narrow synaptic cleft. Because '
          'the gap is tiny (about 20 nm), transmission of nerve impulses across '
          'the synapse takes only a fraction of a millisecond.',
      teachGroup: '6. Synaptic cleft',
    ),
    SimulationStage(
      id: 'binding',
      title: 'Receptor binding',
      explanation: 'Neurotransmitter molecules bind to specific receptors on the '
          'postsynaptic membrane. Binding is like a lock and key — only the '
          'matching neurotransmitter fits its receptor.',
      teachGroup: '7. Postsynaptic receptors',
    ),
    SimulationStage(
      id: 'ion_influx',
      title: 'Ion influx and depolarisation',
      explanation: 'Binding opens ion channels in the postsynaptic membrane. Sodium ions '
          'flow in, depolarising the membrane of the second neurone and '
          'generating a new action potential if the threshold is reached.',
      teachGroup: '8. Postsynaptic response',
    ),
    SimulationStage(
      id: 'continuation',
      title: 'Signal continues',
      explanation: 'The action potential is re-generated in the postsynaptic neurone and '
          'continues along its dendrites, carrying the message onward. '
          'Meanwhile enzymes in the cleft break down neurotransmitter so the '
          'synapse is ready for the next signal.',
      teachGroup: '8. Postsynaptic response',
    ),
  ];

  String? _selectedId;

  void _select(String? id) {
    setState(() => _selectedId = _selectedId == id ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Neuron Communication'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          final selected = _selectedId == null ? null : neuronStructureById[_selectedId];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _intro(colors),
                const SizedBox(height: 14),
                if (narrow) ...[
                  _structureList(dark),
                  const SizedBox(height: 12),
                ],
                ProcessSimulationViewer(
                  stages: _stages,
                  modes: _modes,
                  accent: _neuronAccent,
                  title: 'How two neurones communicate',
                  subtitle: 'Electrical within the neurone · Chemical across the synapse',
                  buildFrame: (context, frame) => _tappableCanvas(frame),
                ),
                const SizedBox(height: 12),
                if (selected != null) ...[
                  NeuronInfoPanel(
                    structure: selected,
                    accent: _neuronAccent,
                    dark: dark,
                    onClose: () => _select(null),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!narrow)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tap a structure or choose it below',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 8),
                        _structureList(dark),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _structureList(bool dark) => NeuronStructureList(
        accent: _neuronAccent,
        dark: dark,
        selectedId: _selectedId,
        onSelect: (id) => _select(id),
      );

  /// The neuron canvas wrapped in a tap detector that resolves the tapped
  /// structure from the painter's hit test. GestureDetector + a Focus wrapper
  /// keeps touch and pointer input working; the structure list provides the
  /// keyboard-accessible path.
  Widget _tappableCanvas(SimulationFrame frame) => LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final id = NeuronPainter.hitTestStructure(details.localPosition, size);
            _select(id);
          },
          child: CustomPaint(
            painter: NeuronPainter(
              scene: NeuronScene(
                stage: frame.stageIndex,
                progress: frame.progress,
                labelsOn: frame.labelsOn,
                dark: frame.dark,
                selectedId: _selectedId,
              ),
            ),
          ),
        ),
      );

  Widget _intro(ThemeColors colors) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _neuronAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _neuronAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bolt_rounded, color: _neuronAccent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Neurones transmit information as electrical impulses that carry '
                'nerve impulses along the axon, but the gap between two neurones '
                '(the synapse) cannot conduct electricity — so the message is '
                'carried across by chemicals called neurotransmitters. Watch the '
                'nine stages, then use Teach Mode to reveal the process step by step.',
                style: TextStyle(fontSize: 13, height: 1.5, color: colors.textPrimary),
              ),
            ),
          ],
        ),
      );
}
