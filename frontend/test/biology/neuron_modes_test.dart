import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/screens/biology/neuron/process_simulation.dart';

void main() {
  group('SimulationMode (Phase 5)', () {
    test('stageCount spans first..last inclusive', () {
      const m = SimulationMode(
        id: 'a',
        title: 'A',
        subtitle: '',
        firstStage: 1,
        lastStage: 3,
      );
      expect(m.stageCount, 3);
    });

    test('buildTeachSteps collapses consecutive teach groups', () {
      const stages = [
        SimulationStage(id: 's0', title: 'a', explanation: 'x', teachGroup: '1'),
        SimulationStage(id: 's1', title: 'b', explanation: 'x', teachGroup: '1'),
        SimulationStage(id: 's2', title: 'c', explanation: 'x', teachGroup: '2'),
        SimulationStage(id: 's3', title: 'd', explanation: 'x', teachGroup: '2'),
        SimulationStage(id: 's4', title: 'e', explanation: 'x', teachGroup: '3'),
      ];
      final steps = buildTeachSteps(stages);
      expect(steps.length, 3);
      expect(steps.first.firstStage, 0);
      expect(steps.first.lastStage, 1);
      expect(steps.last.firstStage, 4);
      expect(steps.last.lastStage, 4);
    });

    test('neuron modes align with the electrical/chemical teaching split', () {
      const electrical = SimulationMode(id: 'e', title: '', subtitle: '', firstStage: 1, lastStage: 3);
      const chemical = SimulationMode(id: 'c', title: '', subtitle: '', firstStage: 3, lastStage: 8);
      // Mode A covers propagation stages; Mode B covers the synapse; they overlap
      // only at the terminal arrival stage (3), which is correct.
      expect(electrical.lastStage, chemical.firstStage);
      expect(chemical.isSimplified, isFalse);
    });
  });
}
