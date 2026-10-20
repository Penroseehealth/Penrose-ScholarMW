import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/screens/biology/neuron/neuron_anatomy.dart';

void main() {
  group('neuron anatomy catalogue (Phase 1)', () {
    test('covers every required structure with a stable id', () {
      const required = {
        'dendrites',
        'soma',
        'nucleus',
        'axon_hillock',
        'axon',
        'myelin_sheath',
        'nodes_of_ranvier',
        'axon_terminal',
        'synaptic_vesicles',
        'neurotransmitter',
        'synaptic_cleft',
        'postsynaptic_membrane',
        'receptors',
      };
      final ids = neuronStructures.map((s) => s.id).toSet();
      expect(ids.containsAll(required), isTrue, reason: 'missing: ${required.difference(ids)}');
      expect(neuronStructures.length, required.length, reason: 'unexpected extra structures');
    });

    test('every structure has non-empty, distinct teaching fields', () {
      for (final s in neuronStructures) {
        expect(s.name.trim().isNotEmpty, isTrue, reason: '${s.id} name');
        expect(s.shortName.trim().isNotEmpty, isTrue, reason: '${s.id} shortName');
        expect(s.function.trim().isNotEmpty, isTrue, reason: '${s.id} function');
        expect(s.detail.trim().isNotEmpty, isTrue, reason: '${s.id} detail');
        expect(s.roleInTransmission.trim().isNotEmpty, isTrue, reason: '${s.id} roleInTransmission');
        expect(s.observe.trim().isNotEmpty, isTrue, reason: '${s.id} observe');
        expect(s.marker.trim().isNotEmpty, isTrue, reason: '${s.id} marker');
      }
    });

    test('markers are unique so colour is never the only cue', () {
      final markers = neuronStructures.map((s) => s.marker).toList();
      expect(markers.toSet().length, markers.length);
    });

    test('direction of signal follows dendrites -> soma -> hillock -> axon -> terminal', () {
      final order = neuronStructures.map((s) => s.id).toList();
      int at(String id) => order.indexOf(id);
      expect(at('dendrites') < at('soma'), isTrue);
      expect(at('soma') < at('axon_hillock'), isTrue);
      expect(at('axon_hillock') < at('axon'), isTrue);
      expect(at('axon') < at('myelin_sheath'), isTrue);
      expect(at('myelin_sheath') < at('nodes_of_ranvier'), isTrue);
      expect(at('nodes_of_ranvier') < at('axon_terminal'), isTrue);
      expect(at('axon_terminal') < at('synaptic_vesicles'), isTrue);
      expect(at('synaptic_vesicles') < at('synaptic_cleft'), isTrue);
      expect(at('synaptic_cleft') < at('postsynaptic_membrane'), isTrue);
      expect(at('postsynaptic_membrane') < at('receptors'), isTrue);
    });

    test('electrical/chemical split is scientifically correct', () {
      NeuronSignal signalOf(String id) => neuronStructures.firstWhere((s) => s.id == id).signal;
      // Electrical within the neuron up to and including the terminal bouton.
      for (final id in ['dendrites', 'soma', 'nucleus', 'axon_hillock', 'axon', 'myelin_sheath', 'nodes_of_ranvier']) {
        expect(signalOf(id), NeuronSignal.electrical, reason: id);
      }
      // Chemical across the synapse only.
      for (final id in [
        'axon_terminal',
        'synaptic_vesicles',
        'synaptic_cleft',
        'neurotransmitter',
        'postsynaptic_membrane',
        'receptors',
      ]) {
        expect(signalOf(id), NeuronSignal.chemical, reason: id);
      }
    });

    test('receptors are on the postsynaptic side, not presynaptic/cleft', () {
      final r = neuronStructureById['receptors']!;
      expect(r.region, NeuronRegion.responding);
      final cleft = neuronStructureById['synaptic_cleft']!;
      expect(cleft.region, NeuronRegion.transmitting);
      // Receptor label sits to the right of the cleft anchor (postsynaptic side).
      expect(r.anchorDx >= cleft.anchorDx, isTrue);
    });

    test('lookup helper resolves ids', () {
      expect(neuronStructureById['axon']!.name, 'Axon');
      expect(neuronMarkerFor('axon'), 'A');
      expect(neuronMarkerFor('does_not_exist'), '?');
    });
  });
}
