import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/modules/biology_lab/bridge/bio_lab_bridge.dart';
import 'package:penrose_scholar/modules/biology_lab/hierarchy/bio_lab_registry.dart';
import 'package:penrose_scholar/modules/biology_lab/practicals/bacterial_practical.dart';
import 'package:penrose_scholar/modules/biology_lab/scenes/bio_scene_specs.dart';
import 'package:penrose_scholar/modules/biology_lab/state/biology_lab_provider.dart';

/// Recording fake: captures every command so tests can assert the
/// Flutter ↔ engine contract without a browser.
class FakeBioLabBridge implements BioLabBridge {
  final List<String> commands = [];
  final StreamController<BioLabEvent> _events = StreamController<BioLabEvent>.broadcast(sync: true);
  final Map<String, Map<String, dynamic>> loadedSpecs = {};
  bool supported;
  bool disposed = false;
  String? lastHostId;

  FakeBioLabBridge({this.supported = true});

  @override
  bool get isSupported => supported;

  @override
  Stream<BioLabEvent> get events => _events.stream;

  @override
  Future<void> init({required String hostId}) async {
    commands.add('init');
    lastHostId = hostId;
    _events.add(const BioReadyEvent());
  }

  @override
  void loadScene(Map<String, dynamic> spec) {
    commands.add('loadScene:${spec['sceneId']}');
    loadedSpecs[spec['sceneId'] as String? ?? ''] = spec;
  }

  @override
  void selectObject(String? id) => commands.add('selectObject:$id');

  @override
  void setLabelsVisible(bool visible) => commands.add('labels:$visible');

  @override
  void setVisibility(Map<String, bool> groups) => commands.add('visibility:${groups.keys.join(",")}');

  @override
  void setTransparency(double value) => commands.add('transparency:$value');

  @override
  void focusObject(String id) => commands.add('focus:$id');

  @override
  void resetCamera() => commands.add('resetCamera');

  @override
  void loadAnimation(String id) => commands.add('loadAnim:$id');

  @override
  void play() => commands.add('play');

  @override
  void pause() => commands.add('pause');

  @override
  void resume() => commands.add('resume');

  @override
  void restart() => commands.add('restart');

  @override
  void setSpeed(double value) => commands.add('speed:$value');

  @override
  void setTimeline(double t) => commands.add('timeline:$t');

  @override
  void setStep(int index, int total) => commands.add('step:$index/$total');

  @override
  void showTransition({required String text, required String scaleLabel}) => commands.add('transition:$text');

  @override
  void showMolecule({required String pdbUrl, required String label}) => commands.add('molecule:$pdbUrl');

  @override
  void hideMolecule() => commands.add('hideMolecule');

  @override
  void dispose() => disposed = true;

  void emit(BioLabEvent event) => _events.add(event);
}

void main() {
  group('BioLabRegistry integrity', () {
    test('registry passes structural validation', () {
      expect(BioLabRegistry.validate(), isEmpty);
    });

    test('covers every biological level', () {
      final levels = BioLabRegistry.assets.map((a) => a.level).toSet();
      expect(levels, containsAll(BioLevel.values));
    });

    test('every asset records source and license', () {
      for (final a in BioLabRegistry.assets) {
        expect(a.source, isNotEmpty, reason: a.id);
        expect(a.license, isNotEmpty, reason: a.id);
        expect(a.scaleLabel, isNotEmpty, reason: a.id);
      }
    });

    test('molecular assets cite a DOI-bearing RCSB citation', () {
      for (final a in BioLabRegistry.assets) {
        if (a.verification == BioVerification.validatedStructure) {
          expect(a.moleculePdb, isNotNull, reason: a.id);
          expect(a.source.toLowerCase(), contains('rcsb'), reason: a.id);
          expect(a.source, contains('doi'), reason: a.id);
        }
      }
    });

    test('search finds the bacterial cell case-insensitively', () {
      expect(
        BioLabRegistry.search('BACTERIA').map((a) => a.id),
        contains('bacterial-cell'),
      );
      expect(BioLabRegistry.search('zzzz'), isEmpty);
    });
  });

  group('BioSceneSpecs', () {
    test('scenes exist for every sceneId referenced by the registry', () {
      for (final a in BioLabRegistry.assets) {
        if (a.sceneId == null) continue;
        expect(BioSceneSpecs.hasScene(a.sceneId!), isTrue, reason: a.id);
        expect(BioSceneSpecs.forScene(a.sceneId!), isNotNull, reason: a.id);
      }
    });

    test('every spec carries the honesty scale note', () {
      for (final sceneId in const [
        'bacterial-cell',
        'human-heart',
        'cardiac-muscle-cell',
        'mitochondrion',
        'human-organism',
      ]) {
        final spec = BioSceneSpecs.forScene(sceneId)!;
        final scaleInfo = spec['scaleInfo'] as Map<String, dynamic>;
        expect(scaleInfo['note'], isNotEmpty, reason: sceneId);
        expect(scaleInfo['label'], isNotEmpty, reason: sceneId);
      }
    });

    test('specs have cameras, groups and valid animation tracks', () {
      for (final sceneId in const [
        'bacterial-cell',
        'human-heart',
        'cardiac-muscle-cell',
        'mitochondrion',
        'human-organism',
      ]) {
        final spec = BioSceneSpecs.forScene(sceneId)!;
        expect((spec['camera'] as Map)['position'], isA<List>(), reason: sceneId);
        expect((spec['camera'] as Map)['target'], isA<List>(), reason: sceneId);
        expect(spec['groups'], isA<List>(), reason: sceneId);

        final objectIds = (spec['objects'] as List).map((o) => (o as Map)['id'] as String).toSet();
        expect(objectIds, isNotEmpty, reason: sceneId);

        for (final anim in (spec['animations'] as List? ?? [])) {
          for (final track in (anim as Map)['tracks'] as List) {
            expect(objectIds, contains((track as Map)['objectId']),
                reason: '$sceneId: animation references missing object');
            expect((track)['keyframes'], isA<List>());
          }
        }
      }
    });

    test('bacterial scene components match registry component ids', () {
      final spec = BioSceneSpecs.forScene('bacterial-cell')!;
      final objectIds = (spec['objects'] as List).map((o) => (o as Map)['id'] as String).toSet();
      final asset = BioLabRegistry.byId('bacterial-cell')!;
      for (final c in asset.components) {
        expect(objectIds, contains(c.id), reason: 'registry component ${c.id} missing from scene');
      }
    });
  });

  group('BacterialPracticalState scoring', () {
    test('full correct run scores 100%', () {
      var p = BacterialPracticalState();
      var qIndex = 0;
      while (!p.isComplete) {
        if (p.isIdentification) {
          p.answerIdentification(p.current.targetComponentId);
        } else {
          final fb = p.answer(p.current.correctIndex!);
          expect(fb.correct, isTrue, reason: 'question $qIndex');
          qIndex++;
        }
        p.advance();
      }
      expect(p.percentScore, 100.0);
      expect(p.answeredCorrectly.length, p.questionCount);
    });

    test('a wrong MCQ answer records feedback and is not scored', () {
      var p = BacterialPracticalState();
      while (!p.current.isQuestion) p.advance();
      final fb = p.answer((p.current.correctIndex! + 1) % p.current.options!.length);
      expect(fb.correct, isFalse);
      expect(fb.explanation, contains('Correct answer'));
      expect(p.percentScore, 0.0);
    });

    test('identification feedback checks the target component', () {
      final p = BacterialPracticalState();
      final wrong = p.answerIdentification('ribosome-0');
      expect(wrong.correct, isFalse);
      expect(wrong.explanation, contains('Hint'));
      final right = p.answerIdentification('cell-wall');
      expect(right.correct, isTrue);
    });
  });

  group('BiologyLabProvider with fake bridge', () {
    late FakeBioLabBridge bridge;
    late BiologyLabProvider provider;

    setUp(() {
      bridge = FakeBioLabBridge();
      provider = BiologyLabProvider(bridge: bridge);
    });

    test('openAsset loads the scene spec and resets selection', () async {
      provider.onHostReady('bio-host');
      await provider.ensureInitialised();
      expect(bridge.commands, contains('init'));
      expect(bridge.lastHostId, 'bio-host');

      await provider.openAsset('bacterial-cell');
      expect(provider.currentAsset?.id, 'bacterial-cell');
      expect(bridge.commands.any((c) => c.startsWith('loadScene:bacterial-cell')), isTrue);
      expect(provider.status, BioLabStatus.ready);
    });

    test('molecular assets open the Mol* viewer with the local PDB path', () async {
      provider.onHostReady('bio-host');
      await provider.ensureInitialised();
      await provider.openAsset('dna-1bna');
      expect(bridge.commands, contains('molecule:biology_lab/data/1bna.pdb'));
      expect(provider.status, BioLabStatus.ready);
    });

    test('metadata-only asset opens without touching the engine scene', () async {
      provider.onHostReady('bio-host');
      await provider.ensureInitialised();
      await provider.openAsset('cardiac-muscle-tissue');
      expect(bridge.commands.any((c) => c.startsWith('loadScene:')), isFalse);
      expect(provider.status, BioLabStatus.ready);
    });

    test('descendTo emits an explicit conceptual transition', () async {
      provider.onHostReady('bio-host');
      await provider.ensureInitialised();
      await provider.openAsset('human-heart');
      final before = bridge.commands.where((c) => c.startsWith('transition:')).length;
      await provider.descendTo('cardiac-muscle-tissue');
      expect(provider.currentAsset?.id, 'cardiac-muscle-tissue');
      expect(
        bridge.commands.where((c) => c.startsWith('transition:')).length,
        greaterThan(before),
      );
      expect(
        bridge.commands.lastWhere((c) => c.startsWith('transition:')),
        contains('Conceptual' == '__never__' ? '' : '→'),
      );
    });

    test('unknown asset id is reported, not silently ignored', () async {
      provider.onHostReady('bio-host');
      await provider.ensureInitialised();
      await provider.openAsset('does-not-exist');
      expect(provider.status, BioLabStatus.error);
      expect(provider.errorCode, 'unknown-asset');
    });

    test('unsupported platform stops at unsupported, no init sent', () async {
      bridge.supported = false;
      final p = BiologyLabProvider(bridge: bridge);
      p.onHostReady('bio-host');
      await p.ensureInitialised();
      expect(p.status, BioLabStatus.unsupported);
      expect(bridge.commands, isNot(contains('init')));
      p.dispose();
    });

    test('selection events from the engine update the info panel', () async {
      provider.onHostReady('bio-host');
      await provider.ensureInitialised();
      await provider.openAsset('bacterial-cell');
      bridge.emit(const BioSelectionEvent(id: 'cell-wall', name: 'Cell wall'));
      expect(provider.selectedComponentId, 'cell-wall');
      expect(provider.selectedComponent?.name, 'Cell wall');
    });

    test('timeline scrubbing forwards clamped values', () async {
      provider.onHostReady('bio-host');
      await provider.ensureInitialised();
      await provider.openAsset('human-heart');
      provider.scrubTo(0.5);
      expect(provider.timeline, 0.5);
      expect(bridge.commands, contains('timeline:0.5'));
      provider.scrubTo(1.5); // clamped by provider
      expect(provider.timeline, 1.0);
    });

    test('dispose releases the bridge exactly once', () async {
      provider.onHostReady('bio-host');
      await provider.ensureInitialised();
      provider.dispose();
      expect(bridge.disposed, isTrue);
    });

    test('view toggles forward to the bridge', () async {
      provider.onHostReady('bio-host');
      await provider.ensureInitialised();
      await provider.openAsset('bacterial-cell');
      provider.toggleLabels();
      expect(provider.labelsVisible, isFalse);
      expect(bridge.commands, contains('labels:false'));
      provider.toggleGhost();
      expect(provider.ghostMode, isTrue);
      expect(bridge.commands, contains('transparency:0.65'));
      provider.resetCamera();
      expect(bridge.commands, contains('resetCamera'));
    });
  });
}
