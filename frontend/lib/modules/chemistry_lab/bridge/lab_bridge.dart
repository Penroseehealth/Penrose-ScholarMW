import 'dart:async';

/// Command/event contract between Flutter and the Chemistry Lab 3D engine
/// (JavaScript/Three.js). The JS side lives in `web/chemistry_lab/lab-scene.js`.
///
/// Dart never touches Three.js directly: everything goes through this
/// interface so the rest of the application (and the unit tests) depend only
/// on abstractions. The web implementation is wired in via conditional import
/// in `lab_bridge_factory.dart`.
///
/// Commands are JSON objects of the form `{"cmd": "...", ...}` and events are
/// delivered as [LabEvent]s on [events]. The full contract is documented in
/// `lib/modules/chemistry_lab/docs/INTEGRATION.md`.
abstract class LabBridge {
  /// Whether the 3D engine can run on this platform at all.
  ///
  /// Always `false` on non-web platforms (stub implementation) and on web
  /// browsers that fail the WebGL capability probe.
  bool get isSupported;

  /// Events emitted by the 3D engine (ready, errors, selection, state).
  Stream<LabEvent> get events;

  /// Loads `chemistry_lab/lab-scene.js` (which pulls in three.js) and
  /// initialises the renderer inside the DOM element [hostId].
  ///
  /// Completes when the engine reports `ready`. Throws [LabBridgeException]
  /// on load failure, missing WebGL, or engine errors during startup.
  Future<void> init({required String hostId});

  /// Instructs the engine to build the scene described by [spec].
  ///
  /// The spec is a plain JSON-serialisable map:
  /// `{"objects": [{"id", "type", "params", "position", "color", ...}],
  ///   "camera": {"position": [x,y,z], "target": [x,y,z]}}`.
  /// Object types: box, cylinder, sphere, cone, torus.
  void loadExperiment(Map<String, dynamic> spec);

  /// Attempts to load an external 3D model (GLB/GLTF) from [url] as
  /// [objectId]. Reports a `model-loader-unavailable` error until the loader
  /// is vendored (Stage 6).
  void loadModel(String url, {required String objectId});

  void play();

  void pause();

  void resume();

  /// Restores every object to its initial transform/colour and stops
  /// interpolation.
  void reset();

  /// [reset] followed by [play].
  void replay();

  /// Animation speed multiplier (0.25–8). Values outside the range are
  /// clamped by the engine.
  void setSpeed(double value);

  void setLabelsVisible(bool visible);

  /// Queues visual property targets for one or more scene objects.
  ///
  /// `params.objects` maps object id → partial properties
  /// (`position`, `scale`, `color`, `opacity`, `visible`). The engine
  /// interpolates towards these targets while playing. Science-side values
  /// (concentrations, pH, volumes) are computed in Dart, never here.
  void updateParams(Map<String, dynamic> params);

  /// Selects (or with `null`, clears the selection of) a scene object by id.
  void selectObject(String? id);

  /// Releases the renderer, geometries, materials, listeners and the host
  /// element contents. Safe to call more than once.
  void dispose();
}

/// Events flowing from the 3D engine back to Flutter.
sealed class LabEvent {
  const LabEvent();
}

/// The engine loaded and the renderer initialised successfully.
class LabReadyEvent extends LabEvent {
  const LabReadyEvent();
}

/// Load/initialisation progress (0.0–1.0) with an optional message.
class LabProgressEvent extends LabEvent {
  final double value;
  final String? message;

  const LabProgressEvent(this.value, {this.message});
}

/// Rendering/playback state change reported by the engine:
/// `ready`, `running`, `paused`.
class LabStateEvent extends LabEvent {
  final String state;

  const LabStateEvent(this.state);
}

/// An object was selected in the 3D viewport (or selection cleared: both
/// [id] and [name] null).
class LabSelectionEvent extends LabEvent {
  final String? id;
  final String? name;
  final String? kind;

  const LabSelectionEvent({this.id, this.name, this.kind});
}

/// Something went wrong. [code] is a stable machine-readable identifier
/// (`no-webgl`, `script-load-failed`, `context-lost`, `host-missing`,
/// `not-initialised`, `command-failed`, `unsupported-platform`, ...);
/// [message] is a human-readable, actionable description surfaced in the UI.
class LabErrorEvent extends LabEvent {
  final String code;
  final String message;

  const LabErrorEvent(this.code, this.message);
}

/// Thrown by [LabBridge.init] when the engine cannot start.
class LabBridgeException implements Exception {
  final String code;
  final String message;

  const LabBridgeException(this.code, this.message);

  @override
  String toString() => 'LabBridgeException($code): $message';
}
