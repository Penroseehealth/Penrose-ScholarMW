import 'dart:async';

import 'bio_lab_bridge.dart';

/// Non-web implementation: the Three.js engine only exists in the browser.
///
/// Mirrors `chemistry_lab/bridge/lab_bridge_stub.dart`.
class StubBioLabBridge implements BioLabBridge {
  final StreamController<BioLabEvent> _events = StreamController<BioLabEvent>.broadcast();

  @override
  bool get isSupported => false;

  @override
  Stream<BioLabEvent> get events => _events.stream;

  @override
  Future<void> init({required String hostId}) async {
    _events.add(const BioErrorEvent(
      'unsupported-platform',
      'The Biology 3D Laboratory requires a web browser with WebGL. '
          'Use the guided walkthrough and diagrams instead.',
    ));
    throw const BioBridgeException(
      'unsupported-platform',
      'The Biology 3D Laboratory is only available on Flutter web with WebGL.',
    );
  }

  @override
  void loadScene(Map<String, dynamic> spec) => _unsupported();

  @override
  void selectObject(String? id) => _unsupported();

  @override
  void setLabelsVisible(bool visible) => _unsupported();

  @override
  void setVisibility(Map<String, bool> groups) => _unsupported();

  @override
  void setTransparency(double value) => _unsupported();

  @override
  void focusObject(String id) => _unsupported();

  @override
  void resetCamera() => _unsupported();

  @override
  void loadAnimation(String id) => _unsupported();

  @override
  void play() => _unsupported();

  @override
  void pause() => _unsupported();

  @override
  void resume() => _unsupported();

  @override
  void restart() => _unsupported();

  @override
  void setSpeed(double value) => _unsupported();

  @override
  void setTimeline(double t) => _unsupported();

  @override
  void setStep(int index, int total) => _unsupported();

  @override
  void showTransition({required String text, required String scaleLabel}) => _unsupported();

  @override
  void showMolecule({required String pdbUrl, required String label}) => _unsupported();

  @override
  void hideMolecule() => _unsupported();

  @override
  void dispose() {
    // No resources to release on this platform.
  }

  void _unsupported() {
    // Intentionally silent: widgets should consult [isSupported] first.
  }
}

/// Factory used by `bio_lab_bridge_factory.dart` via conditional import.
BioLabBridge createBioLabBridge() => StubBioLabBridge();
