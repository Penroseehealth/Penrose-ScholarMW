import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bridge/lab_bridge.dart';
import '../bridge/lab_bridge_factory.dart';

/// Lifecycle phase of the Chemistry Lab 3D engine.
enum LabPhase {
  /// Not started yet (no host element created).
  idle,

  /// `bridge.init` in flight.
  initialising,

  /// Scene loaded, not animating.
  ready,

  /// Parameter interpolation running.
  running,

  /// Paused by the user (scene visible, frozen).
  paused,

  /// Terminal failure — the screen shows the fallback illustration.
  error,
}

/// Selection reported by the 3D viewport (null id = nothing selected).
class LabSelection {
  final String? id;
  final String? name;
  final String? kind;

  const LabSelection({this.id, this.name, this.kind});

  bool get isEmpty => id == null;
}

/// Module-local state for the Chemistry Lab.
///
/// Owns the [LabBridge] (creates it via the conditional-import factory, or
/// accepts a fake in tests) and translates engine events into a simple
/// state machine the widgets can render. Deliberately NOT registered in the
/// app-wide `main.dart` provider list: it lives and dies with the lab route.
class ChemistryLabProvider extends ChangeNotifier {
  ChemistryLabProvider({LabBridge? bridge}) : _bridge = bridge ?? createLabBridge() {
    if (!_bridge.isSupported) {
      _phase = LabPhase.error;
      _errorCode = 'unsupported-platform';
      _errorMessage =
          'The 3D laboratory needs a browser with WebGL. Use the guided walkthrough and diagrams below instead.';
    }
    _subscription = _bridge.events.listen(_onEvent);
  }

  final LabBridge _bridge;
  StreamSubscription<LabEvent>? _subscription;

  LabPhase _phase = LabPhase.idle;
  String? _errorCode;
  String? _errorMessage;
  LabSelection _selection = const LabSelection();
  double _progress = 0;
  String? _progressMessage;
  double _speed = 1.0;
  bool _labelsVisible = true;
  Map<String, dynamic>? _experimentSpec;

  LabPhase get phase => _phase;
  bool get isSupported => _bridge.isSupported;
  String? get errorCode => _errorCode;
  String? get errorMessage => _errorMessage;
  LabSelection get selection => _selection;
  double get progress => _progress;
  String? get progressMessage => _progressMessage;
  double get speed => _speed;
  bool get labelsVisible => _labelsVisible;
  Map<String, dynamic>? get experimentSpec => _experimentSpec;

  /// True while the engine exists and accepts commands.
  bool get engineLive => _phase == LabPhase.ready || _phase == LabPhase.running || _phase == LabPhase.paused;

  /// Called by [LabViewport] once the DOM host element exists.
  Future<void> init(String hostId) async {
    if (_phase == LabPhase.error || _phase == LabPhase.initialising) return;
    _phase = LabPhase.initialising;
    _errorCode = null;
    _errorMessage = null;
    _notify();
    try {
      await _bridge.init(hostId: hostId);
      if (_phase == LabPhase.initialising) _phase = LabPhase.ready;
    } on LabBridgeException catch (e) {
      _fail(e.code, e.message);
    } catch (e) {
      _fail('init-failed', 'The 3D renderer could not start: $e');
    }
    _notify();
  }

  /// Builds the scene described by [spec] (see [LabBridge.loadExperiment]).
  void loadExperiment(Map<String, dynamic> spec) {
    if (!engineLive) return;
    _experimentSpec = spec;
    _bridge.loadExperiment(spec);
    _phase = LabPhase.ready;
    _notify();
  }

  void play() {
    if (!engineLive) return;
    _bridge.play();
    _phase = LabPhase.running;
    _notify();
  }

  void pause() {
    if (_phase != LabPhase.running) return;
    _bridge.pause();
    _phase = LabPhase.paused;
    _notify();
  }

  void resume() {
    if (_phase != LabPhase.paused) return;
    _bridge.resume();
    _phase = LabPhase.running;
    _notify();
  }

  void reset() {
    if (!engineLive) return;
    _bridge.reset();
    _phase = LabPhase.ready;
    _notify();
  }

  void replay() {
    if (!engineLive) return;
    _bridge.replay();
    _phase = LabPhase.running;
    _notify();
  }

  void setSpeed(double value) {
    final clamped = value.clamp(0.25, 8.0);
    _speed = clamped;
    if (engineLive) _bridge.setSpeed(clamped);
    _notify();
  }

  void setLabelsVisible(bool visible) {
    _labelsVisible = visible;
    if (engineLive) _bridge.setLabelsVisible(visible);
    _notify();
  }

  void selectObject(String? id) {
    if (!engineLive) return;
    _bridge.selectObject(id);
  }

  /// Sends visual property targets to the engine (positions, colours, …).
  /// Chemistry values are computed in Dart first — never in JS.
  void updateSceneParams(Map<String, dynamic> params) {
    if (!engineLive) return;
    _bridge.updateParams(params);
  }

  void clearSelection() {
    if (_selection.isEmpty) return;
    _selection = const LabSelection();
    if (engineLive) _bridge.selectObject(null);
    _notify();
  }

  void _onEvent(LabEvent event) {
    switch (event) {
      case LabReadyEvent():
        if (_phase == LabPhase.initialising) _phase = LabPhase.ready;
      case LabProgressEvent(:final value, :final message):
        _progress = value;
        _progressMessage = message;
      case LabStateEvent(:final state):
        // The engine is authoritative about its own playback state.
        switch (state) {
          case 'running':
            if (engineLive || _phase == LabPhase.ready) _phase = LabPhase.running;
          case 'paused':
            if (engineLive) _phase = LabPhase.paused;
          case 'ready':
            if (engineLive) _phase = LabPhase.ready;
          default:
            break;
        }
      case LabSelectionEvent(:final id, :final name, :final kind):
        _selection = LabSelection(id: id, name: name, kind: kind);
      case LabErrorEvent(:final code, :final message):
        if (_fatalCodes.contains(code)) {
          _fail(code, message);
        } else {
          // Non-fatal (e.g. model-loader-unavailable): report but keep the
          // scene alive; widgets may surface the message transiently.
          _errorCode = code;
          _errorMessage = message;
        }
    }
    _notify();
  }

  /// Errors that make the 3D session unusable → fallback UI.
  static const Set<String> _fatalCodes = {
    'no-webgl',
    'host-missing',
    'renderer-failed',
    'script-load-failed',
    'init-timeout',
    'context-lost',
    'unsupported-platform',
    'init-failed',
  };

  void _fail(String code, String message) {
    _phase = LabPhase.error;
    _errorCode = code;
    _errorMessage = message;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _bridge.dispose();
    super.dispose();
  }
}
