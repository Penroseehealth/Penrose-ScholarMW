import 'dart:async';

import 'chemistry_lab_events.dart';

/// Lifecycle and visual-state bridge for the orbitable Chemistry Laboratory.
abstract class ChemistryLabSceneBridge {
  bool get isSupported;

  Stream<ChemistryLabEvent> get events;

  Future<void> init({required String hostId});

  void resetCamera();

  void focusTitrationBench();

  void selectObject(String? id);

  /// Pushes the latest chemical visual state. The 3D engine does not calculate pH.
  void setVisualState(Map<String, dynamic> state);

  void dispose();
}
