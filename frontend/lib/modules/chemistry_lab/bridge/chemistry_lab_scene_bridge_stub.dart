import 'dart:async';

import 'chemistry_lab_events.dart';
import 'chemistry_lab_scene_bridge.dart';

class StubChemistryLabSceneBridge implements ChemistryLabSceneBridge {
  final StreamController<ChemistryLabEvent> _events = StreamController<ChemistryLabEvent>.broadcast();
  final List<Map<String, dynamic>> visualStates = [];

  @override
  bool get isSupported => false;

  @override
  Stream<ChemistryLabEvent> get events => _events.stream;

  @override
  Future<void> init({required String hostId}) async {
    throw UnsupportedError('The orbitable Chemistry Laboratory requires Flutter web and WebGL.');
  }

  @override
  void resetCamera() {}

  @override
  void focusTitrationBench() {}

  @override
  void selectObject(String? id) {}

  @override
  void setVisualState(Map<String, dynamic> state) {
    visualStates.add(Map<String, dynamic>.from(state));
  }

  @override
  void dispose() {}
}

ChemistryLabSceneBridge createChemistryLabSceneBridge() => StubChemistryLabSceneBridge();
