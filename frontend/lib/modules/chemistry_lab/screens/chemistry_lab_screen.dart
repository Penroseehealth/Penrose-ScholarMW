import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_colors.dart';
import '../bridge/chemistry_lab_scene_bridge.dart';
import '../bridge/chemistry_lab_scene_bridge_factory.dart';
import '../viewport/chemistry_lab_viewport.dart';

/// Orbitable 3D approximation of the Chemistry Laboratory with its source
/// photograph available as a visual reference.
class ChemistryLabScreen extends StatefulWidget {
  const ChemistryLabScreen({super.key});

  @override
  State<ChemistryLabScreen> createState() => _ChemistryLabScreenState();
}

class _ChemistryLabScreenState extends State<ChemistryLabScreen> {
  static const _referenceImage = 'assets/chemistry_lab/reference/chemi_lab.jpeg';

  late final ChemistryLabSceneBridge _bridge;
  bool _showReference = false;
  bool _sceneReady = false;
  bool _initializing = false;
  String? _sceneError;

  @override
  void initState() {
    super.initState();
    _bridge = createChemistryLabSceneBridge();
  }

  @override
  void dispose() {
    _bridge.dispose();
    super.dispose();
  }

  Future<void> _onHostReady(String hostId) async {
    if (_initializing || !mounted) return;
    _initializing = true;
    _sceneReady = false;
    try {
      await _bridge.init(hostId: hostId);
      if (mounted) setState(() => _sceneReady = true);
    } catch (error) {
      if (mounted) setState(() => _sceneError = error.toString());
    } finally {
      _initializing = false;
    }
  }

  void _toggleReference() {
    if (!_showReference) {
      _bridge.dispose();
      _sceneReady = false;
    }
    setState(() => _showReference = !_showReference);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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
        title: const Text('Chemistry Laboratory. Photo Match'),
        actions: [
          IconButton(
            tooltip: _showReference ? 'Return to orbitable 3D laboratory' : 'View sharp reference photo',
            icon: Icon(_showReference ? Icons.view_in_ar_rounded : Icons.photo_outlined),
            onPressed: _toggleReference,
          ),
          IconButton(
            tooltip: 'Reset 3D view',
            icon: const Icon(Icons.center_focus_strong_rounded),
            onPressed: !_showReference && _sceneReady ? _bridge.resetCamera : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _showReference
                  ? _buildReference(colors)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ChemistryLabViewport(
                          enabled: _bridge.isSupported,
                          onHostReady: _onHostReady,
                          fallback: _buildReference(colors),
                        ),
                        if (_sceneError != null)
                          ColoredBox(
                            color: colors.background.withValues(alpha: 0.94),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline, color: colors.textSecondary, size: 36),
                                    const SizedBox(height: 12),
                                    Text(
                                      'The 3D laboratory could not be started.',
                                      style: TextStyle(color: colors.textPrimary),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _sceneError!,
                                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    TextButton.icon(
                                      onPressed: () => setState(() {
                                        _sceneError = null;
                                        _showReference = true;
                                      }),
                                      icon: const Icon(Icons.photo_outlined),
                                      label: const Text('Open sharp reference photo'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (!_sceneReady && _sceneError == null && _bridge.isSupported)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
            ),
            if (!_showReference && _bridge.isSupported)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  'Approximate 3D reconstruction · Drag to orbit · Scroll to zoom · Right-drag to pan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReference(ThemeColors colors) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1280 / 853,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.asset(
            _referenceImage,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text(
                'The chemistry laboratory reference photo could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
