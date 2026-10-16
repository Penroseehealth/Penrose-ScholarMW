import 'package:flutter/material.dart';

import '../../../core/theme/theme_colors.dart';
import 'neuron_painter.dart';
import 'neuron_scene.dart';
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
class NeuronCommunicationScreen extends StatelessWidget {
  const NeuronCommunicationScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Neuron Communication'),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _intro(colors),
              const SizedBox(height: 14),
              ProcessSimulationViewer(
                stages: _stages,
                accent: _neuronAccent,
                title: 'How two neurones communicate',
                subtitle: 'Electrical within the neurone · Chemical across the synapse',
                buildFrame: (context, frame) => CustomPaint(
                  painter: NeuronPainter(
                    scene: NeuronScene(
                      stage: frame.stageIndex,
                      progress: frame.progress,
                      labelsOn: frame.labelsOn,
                      dark: frame.dark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
