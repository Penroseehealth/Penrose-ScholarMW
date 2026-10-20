import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/models/biology_visualization.dart';
import 'package:penrose_scholar/screens/biology/visualization/neuron_diagram_renderer.dart';

void main() {
  test('dump neuron svg', () {
    final spec = BiologySpec(
      kind: 'neuron',
      app: 'neuron',
      title: 'Neuron (Nerve Cell)',
      background: 'white',
      structures: const [
        'dendrites',
        'soma',
        'nucleus',
        'axon',
        'myelin_sheath',
        'nodes_of_ranvier',
        'axon_terminal',
        'synaptic_cleft',
        'postsynaptic_membrane',
        'synaptic_vesicles',
        'receptors',
        'neurotransmitter',
      ].map((e) => StructureSpec(id: e, name: e, kind: 'component')).toList(),
    );
    final svg = NeuronDiagramRenderer.render(spec);
    File(r'C:\Users\AMINIL~1\AppData\Local\Temp\opencode\neuron_out.svg').writeAsStringSync(svg);
    // ignore: avoid_print
    print('LEN=${svg.length}');
  });
}
