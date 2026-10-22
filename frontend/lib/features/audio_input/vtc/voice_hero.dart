import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'vtc_theme.dart';

/// What the hero microphone is currently doing. Drives the ring/wave animation
/// so the visual always matches real application state.
enum VtcPulseState { idle, recording, synthesizing, playing }

/// Hero band: "Train Your Voice with Penrose", the tagline, and the large
/// microphone medallion with concentric audio rings on the upper right.
class VoiceHero extends StatelessWidget {
  const VoiceHero({super.key, required this.animation, this.pulse = VtcPulseState.idle, this.amplitude = 0});

  /// Looping 0..1 driver owned by the page.
  final Animation<double> animation;

  final VtcPulseState pulse;

  /// Optional 0..1 live level, e.g. from a playing audio element. When > 0 the
  /// rings react to real playback rather than a canned animation.
  final double amplitude;

  @override
  Widget build(BuildContext context) {
    // The medallion bleeds above the copy, so the stack is clipped to nothing
    // and the text column is the sizing child — that keeps the hero legal
    // inside the page's scroll view.
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 560;
    return Padding(
      padding: EdgeInsets.only(top: compact ? 16 : 30, bottom: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Train Your Voice', textAlign: TextAlign.center, style: VtcType.hero(context)),
              Text('with Penrose', textAlign: TextAlign.center, style: VtcType.hero(context)),
              const SizedBox(height: 18),
              _TaglineDots(compact: compact),
            ],
          ),
          Positioned(
            right: 0,
            top: compact ? -8 : -26,
            child: _MicMedallion(animation: animation, pulse: pulse, amplitude: amplitude, size: compact ? 108 : 190),
          ),
        ],
      ),
    );
  }
}

/// "Speak • Synthesize • Be Heard" with gold separator dots.
class _TaglineDots extends StatelessWidget {
  const _TaglineDots({required this.compact});

  /// Shrinks the word spacing and scale on a phone so the row fits.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const words = ['Speak', 'Synthesize', 'Be Heard'];
    return Semantics(
      label: 'Speak, Synthesize, Be Heard',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < words.length; i++) ...[
                if (i > 0) ...[const _Dot(), SizedBox(width: compact ? 8 : 14)],
                Text(
                  words[i],
                  style: compact ? VtcType.subtitle(context).copyWith(fontSize: 13) : VtcType.subtitle(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: VtcPalette.gold,
          boxShadow: [BoxShadow(color: VtcPalette.gold.withValues(alpha: 0.6), blurRadius: 8)],
        ),
      );
}

/// Circular medallion: gold microphone inside a dark disc, wrapped in
/// concentric glowing audio rings.
class _MicMedallion extends StatelessWidget {
  const _MicMedallion({required this.animation, required this.pulse, required this.amplitude, this.size = 190});

  final Animation<double> animation;
  final VtcPulseState pulse;
  final double amplitude;

  /// Outer ring diameter; the gold medallion scales with it.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Voice symbol',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) => CustomPaint(
              painter: _RingsPainter(t: animation.value, pulse: pulse, amplitude: amplitude),
              child: Center(child: _medallion(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _medallion(BuildContext context) {
    final d = size * (92 / 190);
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xE6231A55), Color(0xF20A1030)]),
        border: Border.all(color: VtcPalette.gold.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [BoxShadow(color: VtcPalette.gold.withValues(alpha: 0.28), blurRadius: 26, spreadRadius: -4)],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (rect) => VtcPalette.goldGradient.createShader(rect),
          child: const Icon(Icons.mic_rounded, size: 42, color: Colors.white),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.t, required this.pulse, required this.amplitude});

  final double t;
  final VtcPulseState pulse;
  final double amplitude;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Live level: real playback amplitude when available, else idle breathing.
    final idleBreath = 1 + 0.012 * math.sin(t * 2 * math.pi);
    final level =
        amplitude > 0 ? amplitude.clamp(0.0, 1.0) : (pulse == VtcPulseState.idle ? (idleBreath - 1) * 8 : 0.0);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final phase = (t + i / 5) % 1.0;
      // Recording/playing push the rings outward faster; otherwise a slow swell.
      final speed = switch (pulse) {
        VtcPulseState.recording => 2.4,
        VtcPulseState.playing => 1.8 + level * 3.0,
        VtcPulseState.synthesizing => 1.4,
        VtcPulseState.idle => 1.0,
      };
      final p = (phase * speed) % 1.0;
      final r = maxRadius * (0.34 + 0.66 * p);
      final fade = (1 - p) * (pulse == VtcPulseState.idle ? 0.34 : 0.62);
      if (fade <= 0.01) continue;
      ringPaint
        ..color = VtcPalette.gold.withValues(alpha: fade)
        ..strokeWidth = 1.1 + (1 - p) * 1.1;
      canvas.drawCircle(center, r, ringPaint);
    }

    // Horizontal waveform through the centre, reacting to state.
    final bars = 26;
    final barPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var i = 0; i < bars; i++) {
      final p = (i + 0.5) / bars;
      final env = 1 - (2 * p - 1).abs();
      final wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 2 + i * 0.5);
      final amp = switch (pulse) {
        VtcPulseState.idle => 0.16 * env * (0.6 + 0.4 * wave),
        VtcPulseState.synthesizing => 0.62 * env * (0.35 + 0.65 * wave),
        VtcPulseState.recording => 0.70 * env * (0.30 + 0.70 * wave),
        VtcPulseState.playing => 0.30 * env + 0.60 * level * env * wave,
      };
      final h = math.max(2.0, size.width * amp);
      final x = center.dx - size.width * 0.44 + p * size.width * 0.88;
      barPaint.color = VtcPalette.goldLight.withValues(alpha: 0.30 + 0.5 * env);
      canvas.drawLine(Offset(x, center.dy - h / 2), Offset(x, center.dy + h / 2), barPaint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t || old.pulse != pulse || old.amplitude != amplitude;
}
