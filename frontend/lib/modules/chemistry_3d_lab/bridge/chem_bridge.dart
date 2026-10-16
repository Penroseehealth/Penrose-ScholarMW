import 'dart:async';

/// Command/event contract between Flutter and the Chemistry 3D Lab engine
/// (JavaScript/Three.js). The JS side lives in
/// `web/chemistry_3d_lab/chem-scene.js`.
///
/// Dart never touches Three.js directly — everything goes through this
/// interface. The web implementation is wired in via conditional import in
/// [createChemBridge].
abstract class ChemBridge {
  /// Whether the 3D engine can run on this platform at all.
  bool get isSupported;

  /// Events emitted by the 3D engine (ready, errors, selection, state).
  Stream<ChemEvent> get events;

  /// Loads `chemistry_3d_lab/chem-scene.js` and initialises the renderer
  /// inside the DOM element [hostId]. Completes when the engine reports `ready`.
  Future<void> init({required String hostId});

  /// Rebuilds the scene from a spec map (see docs/INTEGRATION.md).
  void loadScene(Map<String, dynamic> spec);

  void selectObject(String? id);

  void setLabelsVisible(bool visible);

  void setVisibility(Map<String, bool> groups);

  /// 0 = fully opaque, 1 = ghost mode on non-selected objects.
  void setTransparency(double value);

  void focusObject(String id);

  void resetCamera();

  /// Sets the camera to look at a specific molecule/object bounding box.
  void frameObject(String id);

  void loadAnimation(String id);
  void play();
  void pause();
  void resume();
  void restart();

  /// 0.25–8× multiplier; clamped by the engine.
  void setSpeed(double value);

  /// Scrub to absolute timeline position `t` (0.0–1.0).
  void setTimeline(double t);

  /// Show a transition overlay with [text] and optional [scaleLabel].
  void showTransition({required String text, String? scaleLabel});

  /// Swaps the viewport to the Mol* molecular viewer iframe loading the
  /// local PDB file at [pdbUrl] (relative to `frontend/web/`).
  void showMolecule({required String pdbUrl, required String label});

  void hideMolecule();

  /// Releases the renderer, geometries, materials, listeners and host
  /// element contents. Safe to call more than once.
  void dispose();
}

/// Events flowing from the 3D engine back to Flutter.
sealed class ChemEvent {
  const ChemEvent();
}

/// The engine loaded and the renderer initialised successfully.
class ChemReadyEvent extends ChemEvent {
  const ChemReadyEvent();
}

/// Load/initialisation progress (0.0–1.0) with an optional message.
class ChemProgressEvent extends ChemEvent {
  final double value;
  final String? message;

  const ChemProgressEvent(this.value, {this.message});
}

/// Playback state: `idle | running | paused | molecular`.
class ChemStateEvent extends ChemEvent {
  final String state;

  const ChemStateEvent(this.state);
}

/// An object was selected in the 3D viewport (or cleared: both null).
class ChemSelectionEvent extends ChemEvent {
  final String? id;
  final String? name;

  const ChemSelectionEvent({this.id, this.name});
}

/// Animation timeline position 0.0–1.0.
class ChemTimeEvent extends ChemEvent {
  final double t;

  const ChemTimeEvent(this.t);
}

/// Mol* molecular viewer iframe reported `ready` or `error`.
class ChemMoleculeEvent extends ChemEvent {
  final String type;
  final String? message;

  const ChemMoleculeEvent(this.type, {this.message});
}

/// Something went wrong. [code] is a stable machine-readable identifier;
/// [message] is human-readable and surfaced in the UI.
class ChemErrorEvent extends ChemEvent {
  final String code;
  final String message;

  const ChemErrorEvent(this.code, this.message);
}

/// Thrown by [ChemBridge.init] when the engine cannot start.
class ChemBridgeException implements Exception {
  final String code;
  final String message;

  const ChemBridgeException(this.code, this.message);

  @override
  String toString() => 'ChemBridgeException($code): $message';
}
