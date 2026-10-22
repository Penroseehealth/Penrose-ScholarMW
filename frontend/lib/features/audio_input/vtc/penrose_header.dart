import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'vtc_theme.dart';

/// Fixed premium header: brand lockup, the "Your Voice. A New World." tagline
/// behind a thin divider, and the account cluster on the right.
class PenroseHeader extends StatelessWidget implements PreferredSizeWidget {
  const PenroseHeader({
    super.key,
    required this.height,
    this.onMenuTap,
    this.userName = 'Alex R.',
    this.notifications = 0,
    this.compact = false,
  });

  final double height;

  /// Opens the app-wide drawer so the rest of the app stays reachable.
  final VoidCallback? onMenuTap;
  final String userName;
  final int notifications;

  /// Narrow-viewport presentation: tagline and subtitle collapse.
  final bool compact;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(gradient: VtcPalette.headerScrim),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (onMenuTap != null) ...[
                _IconButton(icon: Icons.menu, tooltip: 'Open app menu', onPressed: onMenuTap!),
                const SizedBox(width: 6),
              ],
              const Flexible(child: _BrandMark()),
              if (!compact) ...[
                const SizedBox(width: 22),
                Container(width: 1, height: 40, color: VtcPalette.ivory.withValues(alpha: 0.22)),
                const SizedBox(width: 22),
                const Expanded(child: _Tagline()),
              ] else
                const Spacer(),
              _AccountCluster(userName: userName, compact: compact),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: 'Penrose Voice Training Center',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Champagne microphone emblem.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: VtcPalette.goldGradient,
              boxShadow: [BoxShadow(color: VtcPalette.gold.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: -2)],
            ),
            child: const Icon(Icons.mic_rounded, size: 21, color: VtcPalette.navyDeep),
          ),
          const SizedBox(width: 12),
          // Scales the wordmark down rather than overflowing a narrow header.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PENROSE', style: VtcType.brand(context)),
                  const SizedBox(height: 3),
                  Text('VOICE TRAINING CENTER', style: VtcType.brandSub(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _MiniWaveform(),
        const SizedBox(width: 12),
        Text(
          'Your Voice. A New World.',
          style: VtcType.bodyIvory(context).copyWith(fontStyle: FontStyle.italic, letterSpacing: 0.3),
        ),
      ],
    );
  }
}

/// Static decorative waveform used as the tagline's audio icon.
class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Audio waveform icon',
      child: SizedBox(width: 30, height: 22, child: CustomPaint(painter: _WaveformPainter(phase: null))),
    );
  }
}

/// Paints a symmetric waveform. Pass an [Animation] to animate it.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({this.phase}) : super(repaint: phase);

  final Animation<double>? phase;

  /// Bar heights as `List<double>` — this SDK's analyzer rejects the `double[]`
  /// array-type syntax, and these are multiples of the widget height anyway.
  static const List<double> _bars = <double>[0.25, 0.52, 0.84, 0.42, 0.66, 1.0, 0.57, 0.33, 0.75, 0.47, 0.28];

  @override
  void paint(Canvas canvas, Size size) {
    final t = phase?.value ?? 0.0;
    final paint = Paint()
      ..color = VtcPalette.goldLight
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    final cy = size.height / 2;
    for (var i = 0; i < _bars.length; i++) {
      // A travelling swell so the icon feels alive when driven.
      final swell = phase == null ? 1.0 : 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + i * 0.55));
      final h = size.height * _bars[i] * swell;
      final x = (i + 0.5) * (size.width / _bars.length);
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.phase != phase;
}

class _AccountCluster extends StatelessWidget {
  const _AccountCluster({required this.userName, required this.compact});

  final String userName;

  /// On a phone the name/role text is dropped: the avatar still identifies the
  /// account, and keeping the text would overflow the header row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _IconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onPressed: () {}),
            // Small notification indicator.
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: VtcPalette.gold,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: VtcPalette.gold.withValues(alpha: 0.7), blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [VtcPalette.violetSoft, VtcPalette.royalBlue],
            ),
            border: Border.all(color: VtcPalette.gold.withValues(alpha: 0.6), width: 1.2),
          ),
          alignment: Alignment.center,
          child: Text(
            userName.isEmpty ? 'A' : userName.characters.first,
            style: VtcType.bodyIvory(context).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
        if (compact) ...[
          Semantics(label: 'Signed in as $userName', child: const SizedBox()),
        ] else ...[
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userName, style: VtcType.bodyIvory(context).copyWith(fontSize: 14.5, fontWeight: FontWeight.w500)),
              Text('Researcher', style: VtcType.body(context).copyWith(fontSize: 12)),
            ],
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: VtcPalette.ivoryDim, size: 20),
        ],
      ],
    );
  }
}

/// Square, thin-line icon button in the header's ivory/gold style.
class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: VtcPalette.ivory.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, size: 20, color: VtcPalette.ivory),
            ),
          ),
        ),
      ),
    );
  }
}
