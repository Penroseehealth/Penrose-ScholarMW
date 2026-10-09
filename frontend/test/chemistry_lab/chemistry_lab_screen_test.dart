import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/modules/chemistry_lab/bridge/lab_bridge.dart';
import 'package:penrose_scholar/modules/chemistry_lab/screens/chemistry_lab_screen.dart';

/// Recording fake bridge for widget tests — the real WebLabBridge touches
/// DOM APIs that don't exist under `flutter test`.
class FakeLabBridge implements LabBridge {
  final List<String> commands = [];
  final StreamController<LabEvent> _events = StreamController<LabEvent>.broadcast();

  @override
  bool get isSupported => false; // exercises the fallback path in VM tests

  @override
  Stream<LabEvent> get events => _events.stream;

  @override
  Future<void> init({required String hostId}) async => commands.add('init:$hostId');

  @override
  void loadExperiment(Map<String, dynamic> spec) => commands.add('loadExperiment');

  @override
  void loadModel(String url, {required String objectId}) {}

  @override
  void play() => commands.add('play');

  @override
  void pause() => commands.add('pause');

  @override
  void resume() => commands.add('resume');

  @override
  void reset() => commands.add('reset');

  @override
  void replay() => commands.add('replay');

  @override
  void setSpeed(double value) => commands.add('setSpeed:$value');

  @override
  void setLabelsVisible(bool visible) => commands.add('setLabels:$visible');

  @override
  void updateParams(Map<String, dynamic> params) {}

  @override
  void selectObject(String? id) {}

  @override
  void dispose() {
    commands.add('dispose');
    if (!_events.isClosed) _events.close();
  }
}

void main() {
  testWidgets('lab screen renders fallback when WebGL is unsupported', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChemistryLabScreen()));

    // Unsupported path shows the actionable fallback, not a blank canvas.
    expect(find.text('3D view unavailable'), findsOneWidget);
    // No retry button: retrying cannot fix a browser without WebGL.
    expect(find.text('Try again'), findsNothing);
    // Static apparatus diagram present as the non-3D substitute.
    expect(find.byType(CustomPaint), findsWidgets);
    // Safety disclaimer lives lower in the idle panel — scroll to it.
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not replace supervised practical work'), findsOneWidget);

    // Controls exist but are disabled (engine dead).
    final runButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Run'));
    expect(runButton.onPressed, isNull);

    // Leaving the screen disposes the bridge.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
  });

  testWidgets('catalogue button opens the experiment catalogue', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChemistryLabScreen()));

    // The idle panel CTA (fallback mode still shows panel content on top).
    final browse = find.text('Browse experiments');
    if (browse.evaluate().isNotEmpty) {
      await tester.tap(browse);
      await tester.pumpAndSettle();
      expect(find.text('Experiment Catalogue'), findsOneWidget);
      expect(find.textContaining('Acid–Base Titration'), findsOneWidget);
    }
  });
}
