import 'package:flutter/material.dart';

import 'math_tutor_player.dart';

/// Persistent bottom bar that controls tutor narration: transport controls,
/// step progress, playback speed and the written transcript of the step being
/// spoken.
class MathTutorAudioBar extends StatelessWidget {
  final MathTutorPlayer player;
  final String voiceLabel;

  const MathTutorAudioBar({
    super.key,
    required this.player,
    required this.voiceLabel,
  });

  /// Natural playback presets. Normal is the default.
  static const List<({String label, double value})> presets = <({String label, double value})>[
    (label: 'Slow', value: 0.75),
    (label: 'Normal', value: 1.0),
    (label: 'Fast', value: 1.5),
  ];

  static List<double> get speeds => presets.map((preset) => preset.value).toList(growable: false);

  static ({String label, double value}) presetFor(double speed) {
    var closest = presets[1];
    var best = (closest.value - speed).abs();
    for (final preset in presets) {
      final distance = (preset.value - speed).abs();
      if (distance < best) {
        best = distance;
        closest = preset;
      }
    }
    return closest;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final step = player.currentStep;

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    step == null ? 'Narration' : 'Step ${player.stepNumber} of ${player.stepCount}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  if (step != null && step.equation != null)
                    Flexible(
                      child: Text(
                        step.equation!,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  const Spacer(),
                  _SpeedMenu(player: player),
                  const SizedBox(width: 6),
                  _StatusChip(player: player, voiceLabel: voiceLabel),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: player.stepCount == 0 ? 0 : player.stepNumber / player.stepCount,
                  minHeight: 4,
                  backgroundColor: scheme.outlineVariant.withAlpha(60),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 64),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    step?.narration ?? 'Solve a problem to hear the tutor narrate each step.',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _TransportButton(
                    icon: Icons.replay_rounded,
                    tooltip: 'Restart from the beginning',
                    onPressed: player.hasSolution ? player.restart : null,
                  ),
                  _TransportButton(
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'Previous step',
                    onPressed: player.hasSolution && !player.isFirstStep ? player.previous : null,
                  ),
                  _TransportButton(
                    icon: player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    tooltip: player.isPlaying ? 'Pause' : 'Play',
                    primary: true,
                    busy: player.isBusy,
                    onPressed: player.hasSolution ? (player.isPlaying ? player.pause : player.play) : null,
                  ),
                  _TransportButton(
                    icon: Icons.stop_rounded,
                    tooltip: 'Stop',
                    onPressed: player.hasSolution ? player.stopNarration : null,
                  ),
                  _TransportButton(
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Next step',
                    onPressed: player.hasSolution && !player.isLastStep ? player.next : null,
                  ),
                  _TransportButton(
                    icon: Icons.repeat_rounded,
                    tooltip: 'Replay this step',
                    onPressed: player.hasSolution ? player.replay : null,
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

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.primary = false,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: primary ? scheme.primary : scheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: primary ? 46 : 40,
              height: primary ? 46 : 40,
              child: busy && primary
                  ? Padding(
                      padding: const EdgeInsets.all(13),
                      child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                    )
                  : Icon(
                      icon,
                      size: primary ? 28 : 20,
                      color: primary ? scheme.onPrimary : (onPressed == null ? scheme.outline : scheme.onSurface),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({required this.player});

  final MathTutorPlayer player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = MathTutorAudioBar.presetFor(player.speed);
    return PopupMenuButton<double>(
      tooltip: 'Narration speed',
      initialValue: current.value,
      onSelected: player.setSpeed,
      itemBuilder: (context) => <PopupMenuEntry<double>>[
        for (final preset in MathTutorAudioBar.presets)
          PopupMenuItem<double>(
            value: preset.value,
            child: Row(
              children: <Widget>[
                Text(preset.label),
                const Spacer(),
                Text(
                  '${preset.value}x',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.speed_rounded, size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(current.label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.player, required this.voiceLabel});

  final MathTutorPlayer player;
  final String voiceLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String text, IconData icon) = switch (player.state) {
      MathTutorPlaybackState.playing => ('Narrating', Icons.graphic_eq_rounded),
      MathTutorPlaybackState.loading => ('Preparing', Icons.hourglass_top_rounded),
      MathTutorPlaybackState.paused => ('Paused', Icons.pause_rounded),
      MathTutorPlaybackState.finished => ('Done', Icons.check_circle_rounded),
      MathTutorPlaybackState.idle => ('Ready', Icons.play_circle_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 4),
          Text(
            '$text \u00b7 $voiceLabel',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.primary),
          ),
        ],
      ),
    );
  }
}
