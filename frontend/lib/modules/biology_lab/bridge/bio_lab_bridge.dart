import 'dart:async';

/// Command/event contract between Flutter and the Biology Lab 3D engine
/// (JavaScript/Three.js). The JS side lives in
/// `web/biology_lab/bio-scene.js`; the full contract is documented in
/// `docs/INTEGRATION.md`.
///
/// Mirrors the Chemistry Lab bridge (`chemistry_lab/bridge/lab_bridge.dart`):
/// Dart never touches Three.js directly — everything goes through this
/// interface. The web implementation is wired in via conditional import in
/// `bio_lab_bridge_factory.dart`.
abstract class BioLabBridge {
  /// Whether the 3D engine can run on this platform at all.
  bool get isSupported;

  /// Events emitted by the 3D engine (ready, errors, selection, state).
  Stream<BioLabEvent> get events;

  /// Loads `biology_lab/bio-scene.js` and initialises the renderer inside
  /// the DOM element [hostId]. Completes when the engine reports `ready`.
  Future<void> init({required String hostId});

  /// Rebuilds the scene from a spec map documented in `docs/INTEGRATION.md`.
  void loadScene(Map<String, dynamic> spec);

  void selectObject(String? id);

  void setLabelsVisible(bool visible);

  void setVisibility(Map<String, bool> groups);

  /// 0 = fully opaque, 1 = ghost mode on non-selected objects.
  void setTransparency(double value);

  void focusObject(String id);

  void resetCamera();

  void loadAnimation(String id);

  void play();
  void pause();
  void resume();
  void restart();

  /// 0.25–8× multiplier; clamped by the engine.
  void setSpeed(double value);

  /// Scrub to absolute timeline position `t` (0.0–1.0).
  void setTimeline(double t);

  /// Step-by-step learning: [index] of [total] steps.
  void setStep(int index, int total);

  void showTransition({required String text, required String scaleLabel});

  /// Swaps the viewport to the Mol* molecular viewer iframe loading the
  /// local PDB file at [pdbUrl] (relative to `frontend/web/`).
  void showMolecule({required String pdbUrl, required String label});

  void hideMolecule();

  /// Releases the renderer, geometries, materials, listeners and host
  /// element contents. Safe to call more than once.
  void dispose();
}

/// Events flowing from the 3D engine back to Flutter.
sealed class BioLabEvent {
  const BioLabEvent();
}

/// The engine loaded and the renderer initialised successfully.
class BioReadyEvent extends BioLabEvent {
  const BioReadyEvent();
}

/// Load/initialisation progress (0.0–1.0) with an optional message.
class BioProgressEvent extends BioLabEvent {
  final double value;
  final String? message;

  const BioProgressEvent(this.value, {this.message});
}

/// Playback state: `idle | running | paused | molecular`.
class BioStateEvent extends BioLabEvent {
  final String state;

  const BioStateEvent(this.state);
}

/// An object was selected in the 3D viewport (or cleared: both null).
class BioSelectionEvent extends BioLabEvent {
  final String? id;
  final String? name;

  const BioSelectionEvent({this.id, this.name});
}

/// Animation timeline position 0.0–1.0.
class BioTimeEvent extends BioLabEvent {
  final double t;

  const BioTimeEvent(this.t);
}

/// Mol* molecular viewer iframe reported `ready` or `error`.
class BioMoleculeEvent extends BioLabEvent {
  final String type;
  final String? message;

  const BioMoleculeEvent(this.type, {this.message});
}

/// Something went wrong. [code] is a stable machine-readable identifier
/// (`no-webgl`, `script-load-failed`, `context-lost`, `host-missing`,
/// `not-initialised`, `command-failed`, `unsupported-platform`, ...);
/// [message] is human-readable and surfaced in the UI.
class BioErrorEvent extends BioLabEvent {
  final String code;
  final String message;

  const BioErrorEvent(this.code, this.message);
}

/// Thrown by [BioLabBridge.init] when the engine cannot start.
class BioBridgeException implements Exception {
  final String code;
  final String message;

  const BioBridgeException(this.code, this.message);

  @override
  String toString() => 'BioBridgeException($code): $message';
}
