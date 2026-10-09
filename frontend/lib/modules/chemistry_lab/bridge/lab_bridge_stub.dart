import 'dart:async';

import 'lab_bridge.dart';

/// Non-web implementation: the Three.js engine only exists in the browser.
///
/// Every method reports `unsupported-platform` so screens can fall back to
/// the static illustration + explanation path instead of hanging.
class StubLabBridge implements LabBridge {
  final StreamController<LabEvent> _events = StreamController<LabEvent>.broadcast();

  @override
  bool get isSupported => false;

  @override
  Stream<LabEvent> get events => _events.stream;

  @override
  Future<void> init({required String hostId}) async {
    _events.add(const LabErrorEvent(
      'unsupported-platform',
      'The 3D laboratory requires a web browser with WebGL. Use the guided '
          'walkthrough and diagrams instead.',
    ));
    throw const LabBridgeException(
      'unsupported-platform',
      'The 3D laboratory is only available on Flutter web with WebGL.',
    );
  }

  @override
  void loadExperiment(Map<String, dynamic> spec) => _unsupported();

  @override
  void loadModel(String url, {required String objectId}) => _unsupported();

  @override
  void play() => _unsupported();

  @override
  void pause() => _unsupported();

  @override
  void resume() => _unsupported();

  @override
  void reset() => _unsupported();

  @override
  void replay() => _unsupported();

  @override
  void setSpeed(double value) => _unsupported();

  @override
  void setLabelsVisible(bool visible) => _unsupported();

  @override
  void updateParams(Map<String, dynamic> params) => _unsupported();

  @override
  void selectObject(String? id) => _unsupported();

  @override
  void dispose() {
    // No resources to release on this platform.
  }

  void _unsupported() {
    // Intentionally silent: widgets should consult [isSupported] first and
    // already show the fallback UI, so post-init commands cannot arrive.
  }
}

/// Factory used by the conditional import in `lab_bridge_factory.dart`.
LabBridge createLabBridge() => StubLabBridge();
