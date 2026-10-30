import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../vtc_theme.dart';
import '../capture_engine_types.dart';

/// A card using the Virtual Recording specification tokens: secondary card
/// background, visible border and a title row.
class VirtualCard extends StatelessWidget {
  const VirtualCard({
    super.key,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    required this.child,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: VtcPalette.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VtcPalette.border),
        ),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 16, color: VtcPalette.cyan),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: VtcPalette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      );
}

/// Status pill. Color is always paired with an icon and a label so status is
/// never conveyed by color alone.
class VirtualPill extends StatelessWidget {
  const VirtualPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.gradient,
    this.foreground,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Gradient? gradient;
  final Color? foreground;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color textColor = foreground ?? color;
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: gradient == null ? color.withValues(alpha: 0.14) : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: gradient == null ? color.withValues(alpha: 0.55) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: compact ? 11 : 13, color: textColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum VirtualButtonTone { primary, danger, secondary, ghost }

/// A real button with a minimum 44px touch target, visible focus ring and a
/// disabled state that never looks active.
class VirtualActionButton extends StatelessWidget {
  const VirtualActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = VirtualButtonTone.secondary,
    this.busy = false,
    this.expand = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final VirtualButtonTone tone;
  final bool busy;
  final bool expand;
  final String? tooltip;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final bool enabled = _enabled;
    final Color foreground = switch (tone) {
      VirtualButtonTone.primary => enabled ? Colors.white : VtcPalette.textMuted,
      VirtualButtonTone.danger => enabled ? Colors.white : VtcPalette.textMuted,
      VirtualButtonTone.secondary => enabled ? VtcPalette.textPrimary : VtcPalette.textMuted,
      VirtualButtonTone.ghost => enabled ? VtcPalette.textSecondary : VtcPalette.textMuted,
    };
    final Gradient? gradient = !enabled
        ? null
        : switch (tone) {
            VirtualButtonTone.primary => VtcPalette.actionGradient,
            VirtualButtonTone.danger => const LinearGradient(colors: <Color>[VtcPalette.recording, VtcPalette.error]),
            _ => null,
          };
    final Color? background = !enabled
        ? VtcPalette.disabled.withValues(alpha: 0.18)
        : switch (tone) {
            VirtualButtonTone.secondary => VtcPalette.elevated,
            VirtualButtonTone.ghost => Colors.transparent,
            _ => null,
          };
    final BorderSide border = switch (tone) {
      VirtualButtonTone.primary || VirtualButtonTone.danger => BorderSide.none,
      VirtualButtonTone.secondary =>
        BorderSide(color: enabled ? VtcPalette.border : VtcPalette.disabled.withValues(alpha: 0.3)),
      VirtualButtonTone.ghost => BorderSide(color: enabled ? VtcPalette.divider : Colors.transparent),
    };

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (busy)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
            )
          else if (icon != null)
            Icon(icon, size: 16, color: foreground),
          if (busy || icon != null) const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
          ),
        ],
      ),
    );

    final Widget button = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        gradient: gradient,
        borderRadius: BorderRadius.circular(10),
        border: Border.fromBorderSide(border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(10),
          focusColor: VtcPalette.focus.withValues(alpha: 0.18),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(widthFactor: expand ? null : 1, child: content),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Real level meter. Bars that have not been lit stay muted blue-gray, exactly
/// as the brief requires, and the lit bars run from the start colour to the end
/// colour (green→yellow for the mic, cyan→green for system audio).
class VirtualAudioMeter extends StatelessWidget {
  const VirtualAudioMeter({
    super.key,
    required this.level,
    required this.colors,
    this.active = true,
    this.bars = 26,
    this.height = 12,
  });

  final ValueListenable<double> level;
  final List<Color> colors;
  final bool active;
  final int bars;
  final double height;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: level,
        builder: (BuildContext context, double value, Widget? child) {
          final double clamped = value.clamp(0.0, 1.0);
          final int lit = active ? (clamped * bars).ceil().clamp(0, bars) : 0;
          return SizedBox(
            height: height,
            child: Row(
              children: List<Widget>.generate(bars, (int index) {
                final double t = bars <= 1 ? 0 : index / (bars - 1);
                final Color litColor = Color.lerp(colors.first, colors.last, t) ?? colors.first;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: index < lit ? litColor : VtcPalette.disabled.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      );
}

class VirtualInfoRow extends StatelessWidget {
  const VirtualInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = VtcPalette.textPrimary,
    this.icon,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: VtcPalette.textMuted),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: VtcPalette.textMuted, fontSize: 11.5, height: 1.35),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(color: valueColor, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

/// Notice/error strip. Destructive and failure text is paired with an icon and
/// a readable sentence; it never relies on a red tint alone.
class VirtualNotice extends StatelessWidget {
  const VirtualNotice({
    super.key,
    required this.message,
    this.isError = false,
    this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final Color color = isError ? VtcPalette.error : VtcPalette.info;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(isError ? Icons.error_outline : Icons.info_outline, size: 16, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: isError ? VtcPalette.textPrimary : VtcPalette.textSecondary, fontSize: 11.5, height: 1.4),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 15),
              color: VtcPalette.textMuted,
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

String sourceStateLabel(SourceState state) {
  switch (state) {
    case SourceState.notSelected:
      return 'Not selected';
    case SourceState.permissionRequired:
      return 'Permission required';
    case SourceState.connecting:
      return 'Connecting…';
    case SourceState.active:
      return 'Connected';
    case SourceState.audioDetected:
      return 'Audio detected';
    case SourceState.noSignal:
      return 'No signal';
    case SourceState.permissionDenied:
      return 'Permission denied';
    case SourceState.deviceDisconnected:
      return 'Device disconnected';
    case SourceState.unsupported:
      return 'Unsupported';
  }
}

Color sourceStateColor(SourceState state) {
  switch (state) {
    case SourceState.notSelected:
      return VtcPalette.disabled;
    case SourceState.permissionRequired:
      return VtcPalette.warning;
    case SourceState.connecting:
      return VtcPalette.info;
    case SourceState.active:
    case SourceState.audioDetected:
      return VtcPalette.successBright;
    case SourceState.noSignal:
      return VtcPalette.warning;
    case SourceState.permissionDenied:
    case SourceState.deviceDisconnected:
    case SourceState.unsupported:
      return VtcPalette.error;
  }
}

IconData sourceStateIcon(SourceState state) {
  switch (state) {
    case SourceState.notSelected:
      return Icons.radio_button_unchecked;
    case SourceState.permissionRequired:
      return Icons.lock_outline;
    case SourceState.connecting:
      return Icons.sync;
    case SourceState.active:
      return Icons.check_circle_outline;
    case SourceState.audioDetected:
      return Icons.graphic_eq;
    case SourceState.noSignal:
      return Icons.volume_off_outlined;
    case SourceState.permissionDenied:
      return Icons.block;
    case SourceState.deviceDisconnected:
      return Icons.link_off;
    case SourceState.unsupported:
      return Icons.error_outline;
  }
}

String formatDuration(Duration duration) {
  final int totalSeconds = duration.inSeconds;
  final String minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final String seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final int hours = totalSeconds ~/ 3600;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '${value.toStringAsFixed(0)} B';
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}
