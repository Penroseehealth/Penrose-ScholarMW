import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/modules/chemistry_lab/bridge/lab_bridge.dart';
import 'package:penrose_scholar/modules/chemistry_lab/state/chemistry_lab_provider.dart';

/// Recording fake: captures every command so tests can assert the
/// Flutter ↔ engine contract without a browser.
class FakeLabBridge implements LabBridge {
  final List<String> commands = [];
  final StreamController<LabEvent> _events = StreamController<LabEvent>.broadcast();
  bool supported;
  bool disposed = false;
  String? lastHostId;

  FakeLabBridge({this.supported = true});

  @override
  bool get isSupported => supported;

  @override
  Stream<LabEvent> get events => _events.stream;

  void emit(LabEvent event) => _events.add(event);

  @override
  Future<void> init({required String hostId}) async {
    commands.add('init:$hostId');
    lastHostId = hostId;
  }

  @override
  void loadExperiment(Map<String, dynamic> spec) => commands.add('loadExperiment');

  @override
  void loadModel(String url, {required String objectId}) => commands.add('loadModel:$objectId');

  @override
  void play() => commands.add('play');

  @override
  void pause() => commands.add('pause');

  @override
  void resume() => commands.add('resume');

  @override
  void reset() => commands.add('reset');

  @override
  void replay() => commands.add('replay');

  @override
  void setSpeed(double value) => commands.add('setSpeed:$value');

  @override
  void setLabelsVisible(bool visible) => commands.add('setLabels:$visible');

  @override
  void updateParams(Map<String, dynamic> params) => commands.add('updateParams');

  @override
  void selectObject(String? id) => commands.add('select:$id');

  @override
  void dispose() {
    disposed = true;
    commands.add('dispose');
    if (!_events.isClosed) _events.close();
  }
}

void main() {
  group('ChemistryLabProvider state machine', () {
    test('unsupported platform starts in error with actionable message', () {
      final p = ChemistryLabProvider(bridge: FakeLabBridge(supported: false));
      expect(p.phase, LabPhase.error);
      expect(p.errorCode, 'unsupported-platform');
      expect(p.errorMessage, contains('WebGL'));
      p.dispose();
    });

    test('init transitions idle → initialising → ready', () async {
      final bridge = FakeLabBridge();
      final p = ChemistryLabProvider(bridge: bridge);
      expect(p.phase, LabPhase.idle);

      final future = p.init('host-1');
      expect(p.phase, LabPhase.initialising);
      await future;
      expect(p.phase, LabPhase.ready);
      expect(bridge.commands, contains('init:host-1'));
      p.dispose();
      expect(bridge.disposed, isTrue);
    });

    test('play / pause / resume / reset / replay drive the bridge', () async {
      final bridge = FakeLabBridge();
      final p = ChemistryLabProvider(bridge: bridge);
      await p.init('h');
      p.loadExperiment({'objects': []});
      expect(p.phase, LabPhase.ready);

      p.play();
      expect(p.phase, LabPhase.running);
      expect(bridge.commands, contains('play'));

      p.pause();
      expect(p.phase, LabPhase.paused);
      expect(bridge.commands, contains('pause'));

      p.resume();
      expect(p.phase, LabPhase.running);
      expect(bridge.commands, contains('resume'));

      p.reset();
      expect(p.phase, LabPhase.ready);
      expect(bridge.commands, contains('reset'));

      p.replay();
      expect(p.phase, LabPhase.running);
      expect(bridge.commands, contains('replay'));
      p.dispose();
    });

    test('commands are ignored before init (no dead-engine traffic)', () async {
      final bridge = FakeLabBridge();
      final p = ChemistryLabProvider(bridge: bridge);
      p.play();
      p.loadExperiment({'objects': []});
      expect(bridge.commands, isEmpty);
      p.dispose();
    });

    test('speed is clamped to [0.25, 8]', () async {
      final bridge = FakeLabBridge();
      final p = ChemistryLabProvider(bridge: bridge);
      await p.init('h');
      p.setSpeed(100);
      expect(p.speed, 8.0);
      p.setSpeed(0.01);
      expect(p.speed, 0.25);
      p.dispose();
    });

    test('engine selection event reaches the provider', () async {
      final bridge = FakeLabBridge();
      final p = ChemistryLabProvider(bridge: bridge);
      await p.init('h');
      bridge.emit(const LabSelectionEvent(id: 'burette', name: 'Burette', kind: 'apparatus'));
      await Future<void>.delayed(Duration.zero);
      expect(p.selection.id, 'burette');
      expect(p.selection.name, 'Burette');
      p.dispose();
    });

    test('fatal engine error flips to fallback state', () async {
      final bridge = FakeLabBridge();
      final p = ChemistryLabProvider(bridge: bridge);
      await p.init('h');
      bridge.emit(const LabErrorEvent('no-webgl', 'WebGL unavailable.'));
      await Future<void>.delayed(Duration.zero);
      expect(p.phase, LabPhase.error);
      expect(p.errorMessage, contains('WebGL'));
      p.dispose();
    });

    test('non-fatal error keeps the session alive', () async {
      final bridge = FakeLabBridge();
      final p = ChemistryLabProvider(bridge: bridge);
      await p.init('h');
      bridge.emit(const LabErrorEvent('model-loader-unavailable', 'GLB loader not enabled.'));
      await Future<void>.delayed(Duration.zero);
      expect(p.phase, LabPhase.ready);
      expect(p.errorCode, 'model-loader-unavailable');
      p.dispose();
    });

    test('engine stateChanged events are authoritative', () async {
      final bridge = FakeLabBridge();
      final p = ChemistryLabProvider(bridge: bridge);
      await p.init('h');
      bridge.emit(const LabStateEvent('running'));
      await Future<void>.delayed(Duration.zero);
      expect(p.phase, LabPhase.running);
      bridge.emit(const LabStateEvent('paused'));
      await Future<void>.delayed(Duration.zero);
      expect(p.phase, LabPhase.paused);
      p.dispose();
    });
  });
}
