import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_colors.dart';
import '../bridge/lab_bridge_factory.dart';
import '../experiments/experiment_catalogue.dart';
import '../experiments/experiment_definition.dart';
import '../scenes/titration_scene.dart';
import '../simulation/titration_controller.dart';
import '../state/chemistry_lab_provider.dart';
import '../viewport/lab_viewport.dart';
import '../widgets/lab_controls.dart';
import '../widgets/lab_error_fallback.dart';
import '../widgets/lab_loading_overlay.dart';
import '../widgets/titration_workflow_panel.dart';
import 'experiment_catalogue_screen.dart';

/// Main entry screen of the Chemistry Laboratory module (`/chem-lab`).
///
/// Owns the single 3D viewport and switches between two modes:
///  - **Idle**: apparatus scene + controls + entry to the catalogue.
///  - **Experiment**: the same viewport beside a step-by-step workflow
///    panel (titration). One viewport, one provider — pushing the
///    catalogue returns an experiment id instead of stacking a second
///    viewport, so scene lifetime stays unambiguous.
class ChemistryLabScreen extends StatefulWidget {
  const ChemistryLabScreen({super.key});

  @override
  State<ChemistryLabScreen> createState() => _ChemistryLabScreenState();
}

class _ChemistryLabScreenState extends State<ChemistryLabScreen> {
  late final ChemistryLabProvider _provider;
  TitrationController? _titration;
  ExperimentDefinition? _experiment;

  @override
  void initState() {
    super.initState();
    _provider = ChemistryLabProvider(bridge: createLabBridge())..addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _provider
      ..removeListener(_onProviderChanged)
      ..dispose();
    _titration?.dispose();
    super.dispose();
  }

  Future<void> _openCatalogue() async {
    final id = await ExperimentCatalogueScreen.open(context);
    if (id == null || !mounted) return;
    final experiment = ExperimentCatalogue.byId(id);
    if (experiment == null) return;
    setState(() {
      _experiment = experiment;
      _titration?.dispose();
      _titration = TitrationController(provider: _provider);
    });
    // Build the scene now that the engine (hopefully) is live.
    if (_provider.engineLive) {
      _provider.loadExperiment(titrationSceneSpec());
    }
  }

  void _exitExperiment() {
    setState(() {
      _experiment = null;
      _titration?.dispose();
      _titration = null;
      _provider.clearSelection();
    });
    if (_provider.engineLive) _provider.loadExperiment(idleSceneSpec());
  }

  void _retry() {
    setState(() {}); // Fresh provider: re-probes WebGL, re-creates host.
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final phase = _provider.phase;
    final engineBroken = phase == LabPhase.error;

    // Wide layout: viewport + side panel. Narrow: stacked.
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final viewport = Stack(
      fit: StackFit.expand,
      children: [
        if (_provider.isSupported && !engineBroken)
          LabViewport(
            enabled: true,
            onHostReady: (hostId) => _provider.init(hostId).then((_) {
              // Scene for the current mode once the engine is live.
              if (!mounted) return;
              if (_provider.engineLive) {
                _provider.loadExperiment(
                  _experiment != null ? titrationSceneSpec() : idleSceneSpec(),
                );
              }
            }),
            fallback: LabErrorFallback(provider: _provider, onRetry: _retry),
          )
        else
          LabErrorFallback(provider: _provider, onRetry: _retry),
        if (phase == LabPhase.initialising) LabLoadingOverlay(provider: _provider),
      ],
    );

    final panel = _experiment != null && _titration != null
        ? TitrationWorkflowPanel(
            experiment: _experiment!,
            controller: _titration!,
            onExitExperiment: _exitExperiment,
          )
        : _IdlePanel(
            provider: _provider,
            onOpenCatalogue: _openCatalogue,
          );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Leave laboratory',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(_experiment?.title ?? 'Chemistry Laboratory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Experiment catalogue',
            onPressed: _openCatalogue,
          ),
        ],
      ),
      body: SafeArea(
        child: isWide
            ? Row(
                children: [
                  Expanded(flex: 3, child: viewport),
                  SizedBox(width: 380, child: panel),
                ],
              )
            : Column(
                children: [
                  Expanded(flex: 5, child: viewport),
                  Expanded(flex: 4, child: panel),
                ],
              ),
      ),
      bottomNavigationBar: LabControls(
        provider: _provider,
        onCatalogue: _openCatalogue,
      ),
    );
  }
}

/// Idle-mode side panel: how the lab works, plus the catalogue call to action.
class _IdlePanel extends StatelessWidget {
  final ChemistryLabProvider provider;
  final VoidCallback onOpenCatalogue;

  const _IdlePanel({required this.provider, required this.onOpenCatalogue});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Welcome to the 3D laboratory',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Drag to rotate · scroll or pinch to zoom · arrow keys to orbit · '
          'click apparatus to inspect it.',
          style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onOpenCatalogue,
          icon: const Icon(Icons.science_outlined),
          label: const Text('Browse experiments'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.surfaceHighest),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selected apparatus', style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(height: 6),
              if (provider.selection.isEmpty)
                Text(
                  'Nothing selected — click an item in the 3D view.',
                  style: TextStyle(fontSize: 13, color: colors.textMuted),
                )
              else ...[
                Text(
                  provider.selection.name ?? provider.selection.id ?? '',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                if (provider.selection.kind != null)
                  Text(
                    'kind: ${provider.selection.kind}',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.warningMuted.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
          ),
          child: Text(
            'This virtual laboratory supports learning and rehearsal. It does not '
            'replace supervised practical work — always follow your teacher’s '
            'instructions and your school’s safety rules in the real lab.',
            style: TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}

/// Placeholder scene shown when no experiment is active: a bench with a
/// beaker, flask and test-tube rack so selection/labels have content.
Map<String, dynamic> idleSceneSpec() => <String, dynamic>{
      'camera': <String, dynamic>{
        'position': <double>[7, 5.5, 9],
        'target': <double>[0, 1.4, 0],
        'background': '#0b0e17',
      },
      'objects': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'bench',
          'name': 'Lab bench',
          'type': 'box',
          'kind': 'furniture',
          'params': <String, dynamic>{'width': 10, 'height': 0.3, 'depth': 6},
          'position': <double>[0, -0.15, 0],
          'color': '#2a3142',
          'roughness': 0.9,
          'selectable': false,
        },
        <String, dynamic>{
          'id': 'beaker',
          'name': 'Beaker (250 cm³)',
          'type': 'cylinder',
          'kind': 'apparatus',
          'params': <String, dynamic>{'radius': 0.8, 'height': 1.3},
          'position': <double>[-1.6, 0.65, 0],
          'color': '#bcd6ef',
          'opacity': 0.4,
          'roughness': 0.1,
          'doubleSided': true,
          'label': 'Beaker',
          'labelOffset': <double>[0, 1.0, 0],
        },
        <String, dynamic>{
          'id': 'flask',
          'name': 'Conical flask',
          'type': 'cone',
          'kind': 'apparatus',
          'params': <String, dynamic>{'radius': 0.9, 'height': 1.6},
          'position': <double>[1.4, 0.8, 0.4],
          'color': '#bcd6ef',
          'opacity': 0.4,
          'roughness': 0.1,
          'doubleSided': true,
          'label': 'Conical flask',
          'labelOffset': <double>[0, 1.2, 0],
        },
        <String, dynamic>{
          'id': 'test_tube',
          'name': 'Test tube',
          'type': 'cylinder',
          'kind': 'apparatus',
          'params': <String, dynamic>{'radius': 0.18, 'height': 1.6},
          'position': <double>[2.8, 0.8, -1.0],
          'rotation': <double>[0, 0, 0.25],
          'color': '#bcd6ef',
          'opacity': 0.45,
          'roughness': 0.1,
          'doubleSided': true,
          'label': 'Test tube',
          'labelOffset': <double>[0, 1.1, 0],
        },
      ],
    };
