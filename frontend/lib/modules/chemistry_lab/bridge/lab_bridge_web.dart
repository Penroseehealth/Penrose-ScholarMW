import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'lab_bridge.dart';

/// Web implementation of [LabBridge]: lazily injects
/// `chemistry_lab/lab-scene.js` (which static-imports three.js), installs the
/// JS→Dart event sink, and forwards commands as JSON strings.
///
/// Only this file knows about `dart:js_interop` / `package:web`; the rest of
/// the app depends solely on the abstract [LabBridge].
class WebLabBridge implements LabBridge {
  /// Events emitted by the JS engine, already parsed.
  final StreamController<LabEvent> _events = StreamController<LabEvent>.broadcast();

  /// Completes when `window.PenroseChemLab` becomes available.
  Completer<void>? _apiReady;

  /// Completes when the current [init] command resolves (ready or error).
  Completer<void>? _initCompleter;

  /// The script tag has been injected (once per page load).
  static bool _scriptInjected = false;
  static bool _sinkInstalled = false;

  /// Reusable webhook: JS calls `window.__penroseChemLabEvent(type, json)`.
  static JSFunction? _eventSink;
  static JSFunction? _loadedCallback;
  static WebLabBridge? _active;

  @override
  bool get isSupported {
    try {
      final canvas = web.document.createElement('canvas');
      final probe = canvas as web.HTMLCanvasElement;
      return probe.getContext('webgl2') != null || probe.getContext('webgl') != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<LabEvent> get events => _events.stream;

  /// Installs the static JS→Dart callbacks. Idempotent.
  static void _installSink() {
    if (_sinkInstalled) return;
    _sinkInstalled = true;
    _eventSink = ((String type, String payload) {
      final bridge = _active;
      if (bridge != null) bridge._onEvent(type, payload);
    }).toJS;
    _loadedCallback = (() {
      final bridge = _active;
      final ready = bridge?._apiReady;
      if (ready != null && !ready.isCompleted) ready.complete();
    }).toJS;
    globalContext.setProperty('__penroseChemLabEvent'.toJS, _eventSink);
    globalContext.setProperty('__penroseChemLabEngineLoaded'.toJS, _loadedCallback);
  }

  void _onEvent(String type, String payload) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(payload);
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      data = <String, dynamic>{};
    }
    switch (type) {
      case 'ready':
        final init = _initCompleter;
        _initCompleter = null;
        if (init != null && !init.isCompleted) init.complete();
        _events.add(const LabReadyEvent());
      case 'progress':
        _events.add(LabProgressEvent(
          (data['value'] as num?)?.toDouble() ?? 0,
          message: data['message'] as String?,
        ));
      case 'stateChanged':
        _events.add(LabStateEvent(data['state'] as String? ?? 'ready'));
      case 'selection':
        _events.add(LabSelectionEvent(
          id: data['id'] as String?,
          name: data['name'] as String?,
          kind: data['kind'] as String?,
        ));
      case 'error':
        final code = data['code'] as String? ?? 'unknown';
        final message = data['message'] as String? ?? 'Unknown 3D engine error.';
        final init = _initCompleter;
        _initCompleter = null;
        if (init != null && !init.isCompleted) {
          init.completeError(LabBridgeException(code, message));
        }
        _events.add(LabErrorEvent(code, message));
      default:
        break; // engineLoaded and future event types: ignore here.
    }
  }

  bool get _apiAvailable => globalContext.hasProperty('PenroseChemLab'.toJS).toDart;

  /// Injects the module script once per page load; completes when
  /// `window.PenroseChemLab` exists (or [old].
  Future<void> _ensureScript({Duration timeout = const Duration(seconds: 30)}) {
    if (_apiAvailable) return Future<void>.value();
    final existing = _apiReady;
    if (existing != null && existing.isCompleted) _apiReady = null;
    _apiReady ??= Completer<void>();
    if (!_scriptInjected) {
      _scriptInjected = true;
      final script = web.HTMLScriptElement()
        ..type = 'module'
        ..src = 'chemistry_lab/lab-scene.js';
      script.onLoad.listen((_) {
        // Module evaluated: API object should exist; engineLoaded may also
        // have fired. Complete whichever is pending.
        if (!_apiAvailable) {
          _scriptInjected = false; // allow retry on next open
          _failScriptLoad('The 3D engine script loaded but did not initialise.');
          return;
        }
        final ready = _apiReady;
        if (ready != null && !ready.isCompleted) ready.complete();
      });
      script.onError.listen((_) {
        _scriptInjected = false;
        _failScriptLoad(
          'Could not load the 3D laboratory files. Check your connection and reopen the laboratory.',
        );
      });
      web.document.head?.appendChild(script);
    }
    return _apiReady!.future.timeout(timeout, onTimeout: () {
      _scriptInjected = false;
      throw const LabBridgeException(
        'script-load-failed',
        'Timed out while loading the 3D laboratory. Check your connection and reopen the laboratory.',
      );
    });
  }

  void _failScriptLoad(String message) {
    final ready = _apiReady;
    _apiReady = null;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(LabBridgeException('script-load-failed', message));
    }
    _events.add(LabErrorEvent('script-load-failed', message));
  }

  void _send(Map<String, dynamic> command) {
    if (!_apiAvailable) return;
    final api = globalContext.getProperty<JSObject?>('PenroseChemLab'.toJS);
    api?.callMethod<JSAny?>('handle'.toJS, jsonEncode(command).toJS);
  }

  @override
  Future<void> init({required String hostId}) async {
    _installSink();
    _active = this;
    await _ensureScript();
    final completer = Completer<void>();
    _initCompleter = completer;
    _send({'cmd': 'init', 'hostId': hostId});
    return completer.future.timeout(const Duration(seconds: 20), onTimeout: () {
      if (!completer.isCompleted) {
        _initCompleter = null;
        throw const LabBridgeException(
          'init-timeout',
          'The 3D renderer did not start in time. Close and reopen the laboratory.',
        );
      }
    });
  }

  @override
  void loadExperiment(Map<String, dynamic> spec) => _send({'cmd': 'loadExperiment', 'spec': spec});

  @override
  void loadModel(String url, {required String objectId}) =>
      _send({'cmd': 'loadModel', 'url': url, 'objectId': objectId});

  @override
  void play() => _send(const {'cmd': 'play'});

  @override
  void pause() => _send(const {'cmd': 'pause'});

  @override
  void resume() => _send(const {'cmd': 'resume'});

  @override
  void reset() => _send(const {'cmd': 'reset'});

  @override
  void replay() => _send(const {'cmd': 'replay'});

  @override
  void setSpeed(double value) => _send({'cmd': 'setSpeed', 'value': value});

  @override
  void setLabelsVisible(bool visible) => _send({'cmd': 'setLabelsVisible', 'visible': visible});

  @override
  void updateParams(Map<String, dynamic> params) => _send({'cmd': 'updateParams', 'params': params});

  @override
  void selectObject(String? id) => _send({'cmd': 'selectObject', 'id': id});

  @override
  void dispose() {
    _send(const {'cmd': 'dispose'});
    final init = _initCompleter;
    _initCompleter = null;
    if (init != null && !init.isCompleted) {
      init.completeError(const LabBridgeException('disposed', 'The laboratory was closed.'));
    }
    if (identical(_active, this)) _active = null;
    if (!_events.isClosed) _events.close();
  }
}

/// Factory used by the conditional import in `lab_bridge_factory.dart`.
LabBridge createLabBridge() => WebLabBridge();
