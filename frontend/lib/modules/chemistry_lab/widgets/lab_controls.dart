import 'package:flutter/material.dart';

import '../../../core/theme/theme_colors.dart';
import '../state/chemistry_lab_provider.dart';

/// Control surface for the 3D viewport: playback (play/pause/resume,
/// reset, replay), animation speed, label visibility, and selection info.
///
/// Disabled states follow [ChemistryLabProvider.engineLive] so controls
/// never send commands to a dead engine.
class LabControls extends StatelessWidget {
  final ChemistryLabProvider provider;
  final VoidCallback? onCatalogue;

  const LabControls({super.key, required this.provider, this.onCatalogue});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final live = provider.engineLive;
    final running = provider.phase == LabPhase.running;
    final paused = provider.phase == LabPhase.paused;

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!provider.selection.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Selected: ${provider.selection.name ?? provider.selection.id}'
                          '${provider.selection.kind != null ? ' (${provider.selection.kind})' : ''}',
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Clear selection',
                        onPressed: provider.clearSelection,
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: !live
                        ? null
                        : running
                            ? provider.pause
                            : paused
                                ? provider.resume
                                : provider.play,
                    icon: Icon(running ? Icons.pause : Icons.play_arrow, size: 18),
                    label: Text(running
                        ? 'Pause'
                        : paused
                            ? 'Resume'
                            : 'Run'),
                  ),
                  OutlinedButton.icon(
                    onPressed: live ? provider.reset : null,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset'),
                  ),
                  OutlinedButton.icon(
                    onPressed: live ? provider.replay : null,
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Replay'),
                  ),
                  _SpeedControl(provider: provider),
                  FilterChip(
                    label: const Text('Labels'),
                    selected: provider.labelsVisible,
                    onSelected: live ? provider.setLabelsVisible : null,
                    avatar: Icon(
                      provider.labelsVisible ? Icons.label : Icons.label_off,
                      size: 16,
                    ),
                  ),
                  if (onCatalogue != null)
                    ActionChip(
                      avatar: const Icon(Icons.science_outlined, size: 16),
                      label: const Text('Experiments'),
                      onPressed: onCatalogue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Playback speed selector (0.25×–8×).
class _SpeedControl extends StatelessWidget {
  final ChemistryLabProvider provider;

  const _SpeedControl({required this.provider});

  static const _presets = [0.25, 0.5, 1.0, 2.0, 4.0];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopupMenuButton<double>(
      tooltip: 'Animation speed',
      onSelected: provider.engineLive ? provider.setSpeed : null,
      child: Chip(
        avatar: const Icon(Icons.speed, size: 16),
        label: Text('${_format(provider.speed)}×'),
        labelStyle: TextStyle(fontSize: 12, color: colors.textPrimary),
      ),
      itemBuilder: (_) => [
        for (final s in _presets)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                if ((provider.speed - s).abs() < 0.01) const Icon(Icons.check, size: 16) else const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text('${_format(s)}×'),
              ],
            ),
          ),
      ],
    );
  }

  static String _format(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
}
