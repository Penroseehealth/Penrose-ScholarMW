import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/screens/biology/neuron/neuron_anatomy.dart';
import 'package:penrose_scholar/screens/biology/neuron/neuron_info_panel.dart';
import 'package:penrose_scholar/screens/biology/neuron/neuron_painter.dart';
import 'package:penrose_scholar/screens/biology/neuron/neuron_structure_list.dart';

void main() {
  group('NeuronPainter hit testing (Phase 2/4)', () {
    const size = Size(1200, 744);

    test('tap on an anchor returns its structure id', () {
      for (final s in neuronStructures) {
        final id = NeuronPainter.hitTestStructure(Offset(s.anchorDx, s.anchorDy + 8), size);
        expect(id, s.id, reason: 'anchor of ${s.id} should hit itself');
      }
    });

    test('tap far from everything returns null', () {
      expect(NeuronPainter.hitTestStructure(const Offset(600, 20), size), isNull);
    });

    test('degenerate size is safe', () {
      expect(NeuronPainter.hitTestStructure(Offset.zero, Size.zero), isNull);
    });
  });

  group('NeuronStructureList (Phase 2 accessibility)', () {
    testWidgets('renders every structure and reports selection', (tester) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NeuronStructureList(
                accent: const Color(0xFF7C3AED),
                onSelect: (id) => picked = id,
              ),
            ),
          ),
        ),
      );
      for (final s in neuronStructures) {
        expect(find.text(s.shortName), findsWidgets, reason: 'missing ${s.shortName}');
      }
      await tester.tap(find.text('Axon').first);
      expect(picked, 'axon');
    });
  });

  group('NeuronInfoPanel (Phase 4)', () {
    testWidgets('shows name, function and role, and reports close', (tester) async {
      var closed = false;
      final s = neuronStructureById['receptors']!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NeuronInfoPanel(
              structure: s,
              accent: const Color(0xFF7C3AED),
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      expect(find.text(s.name), findsOneWidget);
      expect(find.textContaining('What to observe'), findsOneWidget);
      expect(find.textContaining(s.function), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(closed, isTrue);
    });
  });
}
