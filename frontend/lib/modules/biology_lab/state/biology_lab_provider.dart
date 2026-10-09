import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bridge/bio_lab_bridge.dart';
import '../hierarchy/bio_lab_registry.dart';
import '../practicals/bacterial_practical.dart';
import '../scenes/bio_scene_specs.dart';

/// Lifecycle status of the laboratory viewport.
enum BioLabStatus {
  idle,
  loading,
  ready,
  error,
  unsupported,
}

/// Central state of the Biology 3D Laboratory.
///
/// Owns the [BioLabBridge] (the only place in the app that holds one),
/// drives scene loading from the asset registry, and runs the practical
/// state machine. Screens and widgets listen via [ChangeNotifier].
class BiologyLabProvider extends ChangeNotifier {
  BiologyLabProvider({required BioLabBridge bridge}) : _bridge = bridge {
    _sub = bridge.events.listen(_onEvent);
  }

  final BioLabBridge _bridge;
  StreamSubscription<BioLabEvent>? _sub;

  BioLabStatus status = BioLabStatus.idle;
  String? errorMessage;
  String? errorCode;

  /// The asset currently displayed in the viewport.
  BioLabAsset? currentAsset;

  /// Selected component (id inside the current scene) + its metadata.
  String? selectedComponentId;
  BioComponent? selectedComponent;

  String playbackState = 'idle';
  double timeline = 0;
  double speed = 1;
  bool labelsVisible = true;
  bool ghostMode = false;

  /// Per-group visibility toggles for the current scene.
  Map<String, bool> groupVisibility = {};

  /// True while the molecular (Mol*) viewer is shown.
  bool molecularMode = false;

  /// Currently active practical, if any.
  BacterialPracticalState? practical;

  /// Whether `init()` has been called successfully at least once.
  bool _initialised = false;

  /// The host id received from the viewport widget.
  String? _hostId;

  // ── Initialisation ──

  /// The viewport widget reports its host element.
  void onHostReady(String hostId) {
    _hostId = hostId;
  }

  /// Initialises the 3D engine. Safe to call repeatedly; only the first
  /// call does the work.
  Future<void> ensureInitialised() async {
    if (_initialised || status == BioLabStatus.unsupported) return;
    if (_hostId == null) {
      status = BioLabStatus.error;
      errorCode = 'host-missing';
      errorMessage = 'The 3D viewport could not attach to the page.';
      notifyListeners();
      return;
    }
    if (!_bridge.isSupported) {
      status = BioLabStatus.unsupported;
      notifyListeners();
      return;
    }
    status = BioLabStatus.loading;
    notifyListeners();
    try {
      await _bridge.init(hostId: _hostId!);
      _initialised = true;
      status = BioLabStatus.ready;
      notifyListeners();
      // Restore the previously-open asset (e.g. after hot reload).
      final asset = currentAsset;
      if (asset != null) await openAsset(asset.id, skipNotify: true);
    } on BioBridgeException catch (e) {
      status = BioLabStatus.error;
      errorCode = e.code;
      errorMessage = e.message;
      notifyListeners();
    }
  }

  // ── Scene / asset loading ──

  /// Opens an asset: loads its procedural scene, its Mol* molecule, or
  /// shows a graceful "no model yet" state for metadata-only assets.
  Future<void> openAsset(String assetId, {bool skipNotify = false}) async {
    final asset = BioLabRegistry.byId(assetId);
    if (asset == null) {
      status = BioLabStatus.error;
      errorCode = 'unknown-asset';
      errorMessage = 'No registered asset "$assetId".';
      if (!skipNotify) notifyListeners();
      return;
    }
    currentAsset = asset;
    selectedComponentId = null;
    selectedComponent = null;
    practical = null;
    timeline = 0;
    speed = 1;
    ghostMode = false;
    molecularMode = false;

    if (!_initialised) {
      status = BioLabStatus.ready; // metadata-only display still works
      if (!skipNotify) notifyListeners();
      return;
    }

    status = BioLabStatus.loading;
    if (!skipNotify) notifyListeners();

    try {
      if (asset.moleculePdb != null) {
        _bridge.hideMolecule();
        _bridge.showMolecule(pdbUrl: asset.moleculePdb!, label: asset.title);
      } else if (asset.sceneId != null && BioSceneSpecs.hasScene(asset.sceneId!)) {
        _bridge.hideMolecule();
        final spec = BioSceneSpecs.forScene(asset.sceneId!)!;
        _bridge.loadScene(spec);
        groupVisibility = {
          for (final g in (spec['groups'] as List<dynamic>? ?? [])) g as String: true,
        };
      } else {
        // Metadata-only asset: nothing 3D to load.
        _bridge.hideMolecule();
      }
      status = BioLabStatus.ready;
    } catch (e) {
      status = BioLabStatus.error;
      errorCode = 'scene-load-failed';
      errorMessage = 'Could not open "${asset.title}": $e';
    }
    if (!skipNotify) notifyListeners();
  }

  /// Multiscale navigation: move to a child asset one level deeper, with
  /// an explicit conceptual-transition overlay.
  Future<void> descendTo(String childAssetId) async {
    final child = BioLabRegistry.byId(childAssetId);
    final from = currentAsset;
    if (child == null || from == null) return;
    _bridge.showTransition(
      text: '${from.title} → ${child.title}',
      scaleLabel: '${from.level.magnification} → ${child.level.magnification}',
    );
    await openAsset(childAssetId);
  }

  Future<void> ascendToParent() async {
    final parent = currentAsset?.parent;
    if (parent == null) return;
    final parentAsset = BioLabRegistry.byId(parent)!;
    _bridge.showTransition(
      text: '${currentAsset!.title} → ${parentAsset.title}',
      scaleLabel: '${currentAsset!.level.magnification} → ${parentAsset.level.magnification}',
    );
    await openAsset(parent);
  }

  // ── Selection ──

  void selectComponent(String? id) {
    selectedComponentId = id;
    _bridge.selectObject(id);
    if (id == null) {
      selectedComponent = null;
    } else {
      selectedComponent = currentAsset?.components.where((c) => c.id == id).firstWhere(
            (c) => true,
            orElse: () => BioComponent(
              id: id,
              name: id,
              description: 'Selected structure in the current scene.',
            ),
          );
    }
    notifyListeners();
  }

  void focusComponent(String id) => _bridge.focusObject(id);

  // ── Playback ──

  void playAnimation(String? animationId) {
    if (animationId != null) _bridge.loadAnimation(animationId);
    _bridge.play();
  }

  void pauseAnimation() => _bridge.pause();

  void resumeAnimation() => _bridge.resume();

  void restartAnimation() {
    _bridge.restart();
    timeline = 0;
    notifyListeners();
  }

  void scrubTo(double t) {
    timeline = t.clamp(0.0, 1.0);
    _bridge.setTimeline(timeline);
    notifyListeners();
  }

  void stepTo(int index, int total) {
    _bridge.setStep(index, total);
    timeline = total > 1 ? (index / (total - 1)).clamp(0.0, 1.0) : 0;
    notifyListeners();
  }

  void setSpeed(double value) {
    speed = value.clamp(0.25, 8.0);
    _bridge.setSpeed(speed);
    notifyListeners();
  }

  // ── View toggles ──

  void toggleLabels() {
    labelsVisible = !labelsVisible;
    _bridge.setLabelsVisible(labelsVisible);
    notifyListeners();
  }

  void toggleGroup(String group) {
    final next = !groupVisibility[group]!;
    groupVisibility[group] = next;
    _bridge.setVisibility({group: next});
    notifyListeners();
  }

  void toggleGhost() {
    ghostMode = !ghostMode;
    _bridge.setTransparency(ghostMode ? 0.65 : 0);
    notifyListeners();
  }

  void resetCamera() => _bridge.resetCamera();

  void exitMolecularMode() {
    _bridge.hideMolecule();
    molecularMode = false;
    notifyListeners();
  }

  // ── Practical ──

  void startPractical(BacterialPracticalState state) {
    practical = state;
    notifyListeners();
  }

  /// Answers the current practical question and returns feedback.
  PracticalFeedback answerPractical(int choiceIndex) {
    final p = practical;
    if (p == null) {
      return const PracticalFeedback(correct: false, explanation: 'No practical is active.');
    }
    final feedback = p.answer(choiceIndex);
    notifyListeners();
    return feedback;
  }

  void advancePractical() {
    practical?.advance();
    notifyListeners();
  }

  void endPractical() {
    practical = null;
    notifyListeners();
  }

  // ── Bridge events ──

  void _onEvent(BioLabEvent event) {
    switch (event) {
      case BioReadyEvent():
        // handled inside ensureInitialised via the init completer
        break;
      case BioProgressEvent():
        break;
      case BioStateEvent(state: final s):
        playbackState = s;
        molecularMode = s == 'molecular';
      case BioSelectionEvent(id: final id, name: final name):
        selectedComponentId = id;
        if (id == null) {
          selectedComponent = null;
        } else {
          selectedComponent = BioComponent(
            id: id,
            name: name ?? id,
            description: currentAsset?.components.where((c) => c.id == id).map((c) => c.description).firstOrNull ??
                'Selected structure in the current scene.',
          );
        }
      case BioTimeEvent(t: final t):
        timeline = t;
      case BioMoleculeEvent():
        break;
      case BioErrorEvent(code: final code, message: final message):
        errorCode = code;
        errorMessage = message;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bridge.dispose();
    super.dispose();
  }
}
