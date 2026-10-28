import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'vtc_theme.dart';

/// Destination in the VTC's own navigation rail.
class VtcNavItem {
  const VtcNavItem({required this.id, required this.label, required this.icon, this.enabled = true});

  final String id;
  final String label;
  final IconData icon;

  /// False renders the row dimmed and non-interactive. Used for destinations
  /// that have no backend yet (e.g. Progress) so the UI never implies they work.
  final bool enabled;
}

/// Nav entries. Only destinations backed by working behaviour are enabled.
const List<VtcNavItem> kVtcNavItems = <VtcNavItem>[
  VtcNavItem(id: 'home', label: 'Home', icon: Icons.home_outlined),
  VtcNavItem(id: 'voice_training', label: 'Voice Training', icon: Icons.graphic_eq_rounded),
  VtcNavItem(id: 'recorder', label: 'Record', icon: Icons.podcasts_rounded),
  VtcNavItem(id: 'my_voices', label: 'My Voices', icon: Icons.record_voice_over_outlined),
  // Progress and Settings have no backend surface yet, so they stay disabled
  // rather than pretending to work.
  VtcNavItem(id: 'progress', label: 'Progress', icon: Icons.insights_outlined, enabled: false),
  VtcNavItem(id: 'settings', label: 'Settings', icon: Icons.settings_outlined, enabled: false),
];

/// Dark translucent sidebar. "Voice Training" carries the gold pill.
class VoiceSidebar extends StatelessWidget {
  const VoiceSidebar({super.key, required this.selectedId, required this.onSelect, this.width = 244});

  final String selectedId;
  final ValueChanged<VtcNavItem> onSelect;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(gradient: VtcPalette.sidebarGradient),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            for (final item in kVtcNavItems)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                child: _NavRow(item: item, selected: item.id == selectedId, onTap: () => onSelect(item)),
              ),
            const Spacer(),
            const SidebarFlourish(),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.item, required this.selected, required this.onTap});

  final VtcNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = item.enabled;
    final fg = !enabled
        ? VtcPalette.ivory.withValues(alpha: 0.34)
        : selected
            ? VtcPalette.ivory
            : VtcPalette.ivory.withValues(alpha: 0.82);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: enabled ? item.label : '${item.label} (not available yet)',
      child: Tooltip(
        message: enabled ? item.label : '${item.label} — not available yet',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: selected ? VtcPalette.goldGradient : null,
                boxShadow: selected
                    ? [BoxShadow(color: VtcPalette.gold.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: -4)]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(item.icon, size: 20, color: fg),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(item.label, style: VtcType.navItem(context).copyWith(color: fg)),
                  ),
                  if (!enabled) const Icon(Icons.lock_outline_rounded, size: 13, color: VtcPalette.ivoryDim),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Better Voice / Brighter You" with a gold rule and waveform ornament.
class SidebarFlourish extends StatelessWidget {
  const SidebarFlourish({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GoldWaveOrnament(height: 26),
          const SizedBox(height: 16),
          Text('Better Voice', style: VtcType.flourish(context)),
          Text('Brighter You', style: VtcType.flourish(context).copyWith(color: VtcPalette.goldLight)),
          const SizedBox(height: 12),
          const GoldRule(width: 60),
        ],
      ),
    );
  }
}

/// Small static gold waveform ornament for the lower sidebar.
class GoldWaveOrnament extends StatelessWidget {
  const GoldWaveOrnament({super.key, this.height = 26, this.animation});

  final double height;
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _OrnamentPainter(phase: animation)),
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  _OrnamentPainter({this.phase}) : super(repaint: phase);

  final Animation<double>? phase;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final paint = Paint()
      ..color = VtcPalette.gold.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    const bars = 17;
    final t = phase?.value ?? 0.0;
    for (var i = 0; i < bars; i++) {
      final p = i / (bars - 1);
      // Damped swell that tapers at both ends.
      final envelope = 1 - (2 * p - 1).abs();
      final base = 0.25 + 0.75 * envelope;
      final anim = phase == null ? 1.0 : 0.7 + 0.3 * (0.5 + 0.5 * math.sin(t * 2 * math.pi + i * 0.4));
      final h = size.height * base * anim;
      final x = (i + 0.5) * (size.width / bars);
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_OrnamentPainter old) => old.phase != phase;
}
