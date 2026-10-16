import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'chemistry_lab_events.dart';
import 'chemistry_lab_scene_bridge.dart';

class WebChemistryLabSceneBridge implements ChemistryLabSceneBridge {
  static Completer<void>? _apiReady;
  static Completer<void>? _sceneReady;
  static WebChemistryLabSceneBridge? _active;
  static JSFunction? _engineLoadedCallback;
  static JSFunction? _readyCallback;
  static JSFunction? _errorCallback;
  static JSFunction? _eventCallback;

  final StreamController<ChemistryLabEvent> _events = StreamController<ChemistryLabEvent>.broadcast();

  @override
  bool get isSupported {
    try {
      final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
      return canvas.getContext('webgl2') != null || canvas.getContext('webgl') != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<ChemistryLabEvent> get events => _events.stream;

  static void _installCallbacks() {
    _engineLoadedCallback ??= (() {
      final ready = _apiReady;
      if (ready != null && !ready.isCompleted) ready.complete();
    }).toJS;
    _readyCallback ??= (() {
      final ready = _sceneReady;
      if (ready != null && !ready.isCompleted) ready.complete();
      _active?._events.add(const ChemistryLabReadyEvent());
    }).toJS;
    _errorCallback ??= ((String message) {
      final ready = _sceneReady;
      if (ready != null && !ready.isCompleted) {
        ready.completeError(StateError(message));
      }
      _active?._events.add(ChemistryLabErrorEvent(message));
    }).toJS;
    _eventCallback ??= ((String type, String payload) {
      _active?._onEngineEvent(type, payload);
    }).toJS;
    globalContext.setProperty('__penroseChemLabEngineLoaded'.toJS, _engineLoadedCallback);
    globalContext.setProperty('__penroseChemLabReady'.toJS, _readyCallback);
    globalContext.setProperty('__penroseChemLabError'.toJS, _errorCallback);
    globalContext.setProperty('__penroseChemLabEvent'.toJS, _eventCallback);
  }

  void _onEngineEvent(String type, String payload) {
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
    switch (type) {
      case 'selection':
        _events.add(ChemistryLabSelectionEvent(id: data['id'] as String?, name: data['name'] as String?));
      case 'stopcock':
        _events.add(ChemistryLabStopcockEvent(data['open'] == true));
      default:
        break;
    }
  }

  Future<void> _ensureEngine() async {
    if (globalContext.hasProperty('PenroseChemLab'.toJS).toDart) return;
    final existingReady = _apiReady;
    if (existingReady != null) return existingReady.future;

    _apiReady = Completer<void>();
    _installCallbacks();
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    script.type = 'module';
    script.textContent = '''
import './chemistry_lab/chemistry-scene.js';
if (window.PenroseChemLab) window.__penroseChemLabEngineLoaded();
''';
    script.onerror = ((JSAny _) {
      final ready = _apiReady;
      if (ready != null && !ready.isCompleted) {
        ready.completeError(StateError('Could not load the Chemistry Lab 3D engine.'));
      }
    }).toJS;
    web.document.head!.appendChild(script);
    final apiReady = _apiReady!;
    try {
      await apiReady.future.timeout(const Duration(seconds: 20));
    } catch (_) {
      if (identical(_apiReady, apiReady)) _apiReady = null;
      rethrow;
    }
  }

  void _send(Map<String, dynamic> command) {
    final api = globalContext.getProperty<JSObject?>('PenroseChemLab'.toJS);
    if (api == null) throw StateError('The Chemistry Lab 3D engine is not initialized.');
    api.callMethod('handle'.toJS, jsonEncode(command).toJS);
  }

  @override
  Future<void> init({required String hostId}) async {
    if (!isSupported) throw UnsupportedError('WebGL is not available in this browser.');
    _active = this;
    _installCallbacks();
    await _ensureEngine();
    final ready = Completer<void>();
    _sceneReady = ready;
    _send({'cmd': 'init', 'hostId': hostId});
    try {
      await ready.future.timeout(const Duration(seconds: 20));
    } finally {
      if (identical(_sceneReady, ready)) _sceneReady = null;
    }
  }

  @override
  void resetCamera() => _send({'cmd': 'resetCamera'});

  @override
  void focusTitrationBench() => _send({'cmd': 'focusTitration'});

  @override
  void selectObject(String? id) => _send({'cmd': 'selectObject', 'id': id});

  @override
  void setVisualState(Map<String, dynamic> state) {
    _send({'cmd': 'setVisualState', ...state});
  }

  @override
  void dispose() {
    if (identical(_active, this)) {
      _active = null;
      if (globalContext.hasProperty('PenroseChemLab'.toJS).toDart) {
        _send({'cmd': 'dispose'});
      }
    }
  }
}

ChemistryLabSceneBridge createChemistryLabSceneBridge() => WebChemistryLabSceneBridge();
