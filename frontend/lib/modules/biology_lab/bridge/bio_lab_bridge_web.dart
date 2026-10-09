import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'bio_lab_bridge.dart';

/// Web implementation of [BioLabBridge]: lazily injects
/// `biology_lab/bio-scene.js` (which static-imports three.js), installs the
/// JS→Dart event sink, and forwards commands as JSON strings.
///
/// Mirrors `chemistry_lab/bridge/lab_bridge_web.dart`.
class WebBioLabBridge implements BioLabBridge {
  /// Events emitted by the JS engine, already parsed.
  final StreamController<BioLabEvent> _events = StreamController<BioLabEvent>.broadcast();

  /// Completes when `window.PenroseBioLab` becomes available.
  Completer<void>? _apiReady;

  /// Completes when the current [init] command resolves (ready or error).
  Completer<void>? _initCompleter;

  /// The script tag has been injected (once per page load).
  static bool _scriptInjected = false;
  static bool _sinkInstalled = false;

  /// Reusable webhook: JS calls `window.__penroseBioLabEvent(type, json)`.
  static JSFunction? _eventSink;
  static JSFunction? _loadedCallback;
  static WebBioLabBridge? _active;

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
  Stream<BioLabEvent> get events => _events.stream;

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
    globalContext.setProperty('__penroseBioLabEvent'.toJS, _eventSink);
    globalContext.setProperty('__penroseBioLabEngineLoaded'.toJS, _loadedCallback);
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
        _events.add(const BioReadyEvent());
      case 'progress':
        _events.add(BioProgressEvent(
          (data['value'] as num?)?.toDouble() ?? 0,
          message: data['message'] as String?,
        ));
      case 'stateChanged':
        _events.add(BioStateEvent(data['state'] as String? ?? 'idle'));
      case 'selection':
        final id = data['id'] as String?;
        final name = data['name'] as String?;
        _events.add(BioSelectionEvent(id: id, name: name));
      case 'time':
        _events.add(BioTimeEvent((data['t'] as num?)?.toDouble() ?? 0));
      case 'molecule':
        _events.add(BioMoleculeEvent(
          data['type'] as String? ?? 'error',
          message: data['message'] as String?,
        ));
      case 'error':
        final code = data['code'] as String? ?? 'engine-error';
        _events.add(BioErrorEvent(code, data['message'] as String? ?? code));
        final init = _initCompleter;
        _initCompleter = null;
        if (init != null && !init.isCompleted) {
          init.completeError(BioBridgeException(code, data['message'] as String? ?? code));
        }
      default:
        break;
    }
  }

  Future<void> _ensureScript() async {
    if (_scriptInjected) return;
    if (!globalContext.hasProperty('PenroseBioLab'.toJS).toDart) {
      _installSink();
      _active = this;
      _apiReady = Completer<void>();
      final script = web.document.createElement('script') as web.HTMLScriptElement;
      script.type = 'module';
      script.textContent = '''
import './biology_lab/bio-scene.js';
const api = window.PenroseBioLab;
if (api && typeof window.__penroseBioLabEngineLoaded === 'function') {
  window.__penroseBioLabEngineLoaded();
}
''';
      script.onerror = ((JSAny event) {
        final ready = _apiReady;
        if (ready != null && !ready.isCompleted) {
          ready.completeError(const BioBridgeException(
            'script-load-failed',
            'Could not load the Biology 3D engine (bio-scene.js). '
                'Check the deployment includes frontend/web/biology_lab.',
          ));
        }
      }).toJS;
      web.document.head!.appendChild(script);
      _scriptInjected = true;
      await _apiReady!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw const BioBridgeException(
          'script-load-timeout',
          'The Biology 3D engine did not load within 20 seconds. '
              'Check your connection and reload.',
        ),
      );
    }
  }

  void _send(Map<String, dynamic> command) {
    final api = globalContext.getProperty<JSObject?>('PenroseBioLab'.toJS);
    if (api == null) {
      _events.add(const BioErrorEvent(
        'not-initialised',
        'The 3D engine is not loaded yet. Try reopening the laboratory.',
      ));
      return;
    }
    api.callMethod('handle'.toJS, jsonEncode(command).toJS);
  }

  @override
  Future<void> init({required String hostId}) async {
    await _ensureScript();
    _initCompleter = Completer<void>();
    _send({'cmd': 'init', 'hostId': hostId});
    await _initCompleter!.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw const BioBridgeException(
        'init-timeout',
        'The 3D renderer did not start. Does this device support WebGL?',
      ),
    );
  }

  @override
  void loadScene(Map<String, dynamic> spec) => _send({'cmd': 'loadScene', 'spec': spec});

  @override
  void selectObject(String? id) => _send({'cmd': 'selectObject', 'id': id});

  @override
  void setLabelsVisible(bool visible) => _send({'cmd': 'setLabelsVisible', 'visible': visible});

  @override
  void setVisibility(Map<String, bool> groups) => _send({'cmd': 'setVisibility', 'groups': groups});

  @override
  void setTransparency(double value) => _send({'cmd': 'setTransparency', 'value': value});

  @override
  void focusObject(String id) => _send({'cmd': 'focusObject', 'id': id});

  @override
  void resetCamera() => _send({'cmd': 'resetCamera'});

  @override
  void loadAnimation(String id) => _send({'cmd': 'loadAnimation', 'id': id});

  @override
  void play() => _send({'cmd': 'play'});

  @override
  void pause() => _send({'cmd': 'pause'});

  @override
  void resume() => _send({'cmd': 'resume'});

  @override
  void restart() => _send({'cmd': 'restart'});

  @override
  void setSpeed(double value) => _send({'cmd': 'setSpeed', 'value': value});

  @override
  void setTimeline(double t) => _send({'cmd': 'setTimeline', 't': t.clamp(0.0, 1.0)});

  @override
  void setStep(int index, int total) => _send({'cmd': 'setStep', 'index': index, 'total': total});

  @override
  void showTransition({required String text, required String scaleLabel}) =>
      _send({'cmd': 'showTransition', 'text': text, 'scaleLabel': scaleLabel});

  @override
  void showMolecule({required String pdbUrl, required String label}) =>
      _send({'cmd': 'showMolecule', 'pdb': pdbUrl, 'label': label});

  @override
  void hideMolecule() => _send({'cmd': 'hideMolecule'});

  @override
  void dispose() {
    _send({'cmd': 'dispose'});
  }
}

/// Factory used by `bio_lab_bridge_factory.dart` via conditional import.
BioLabBridge createBioLabBridge() => WebBioLabBridge();
