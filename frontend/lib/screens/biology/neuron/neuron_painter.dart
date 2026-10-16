import 'package:flutter/material.dart';

import 'neuron_scene.dart';

/// Paints the two-neuron communication scene for a [NeuronScene] frame.
///
/// Layout (logical canvas ~1200x744):
///   presynaptic neuron left (dendrites / soma / axon / boutons),
///   synapse in the middle (cleft, vesicles, neurotransmitter molecules,
///   postsynaptic membrane with receptors),
///   postsynaptic neuron right (membrane / soma / nucleus / dendrites).
///
/// Scientific accuracy rules kept deliberately explicit:
///   * electrical signalling (the action-potential pulse) travels WITHIN the
///     axon (saltatory conduction at the Nodes of Ranvier);
///   * neurotransmitter release happens ONLY at the presynaptic terminal and
///     crosses the synaptic cleft to receptors on the postsynaptic membrane.
///   Neurotransmitters never travel through the axon.
class NeuronPainter extends CustomPainter {
  NeuronPainter({required this.scene});

  final NeuronScene scene;

  /// Logical drawing width used for coordinate layout.
  static const double logWidth = 1200;

  /// Logical drawing height used for coordinate layout.
  static const double logHeight = 744;

  late final NeuronPalette _c = NeuronPalette(dark: scene.dark);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / logWidth;
    final sy = size.height / logHeight;
    canvas.scale(sx, sy);
    _draw(canvas);
  }

  void _draw(Canvas canvas) {
    final st = scene.stage;
    final pr = scene.progress;

    _drawDendrites(canvas, postsynaptic: false);
    _drawSoma(canvas, postsynaptic: false);
    _drawAxon(canvas);
    _drawBoutons(canvas, st, pr);
    _drawCleft(canvas, st, pr);
    _drawPostsynaptic(canvas, st, pr);
    _drawSoma(canvas, postsynaptic: true);
    _drawDendrites(canvas, postsynaptic: true);
    _drawPostsynapticDendriteTips(canvas);

    if (scene.animate) {
      _drawSignalPulse(canvas, st, pr);
      _drawRestingIons(canvas, st, pr);
      if (st >= 8) _drawNaInflux(canvas, st, pr);
      _drawLegend(canvas);
    }
    if (scene.labelsOn) _drawLabels(canvas);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

  bool _in(int st, int a, int b) => st >= a && st <= b;

  // ── Presynaptic neuron ─────────────────────────────────────────────

  void _drawDendrites(Canvas canvas, {required bool postsynaptic}) {
    final color = postsynaptic ? _c.postFill.withValues(alpha: 0.9) : _c.presynapticFill;
    final stroke = postsynaptic ? _c.postStroke : _c.presynapticStroke;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final tip = Paint()..color = stroke;

    var paths = <List<Offset>>[
      [const Offset(120, 470), const Offset(70, 500), const Offset(36, 540)],
      [const Offset(120, 430), const Offset(52, 435), const Offset(22, 430)],
      [const Offset(120, 380), const Offset(48, 375), const Offset(18, 372)],
      [const Offset(125, 330), const Offset(55, 315), const Offset(24, 298)],
      [const Offset(140, 290), const Offset(90, 240), const Offset(60, 200)],
    ];
    if (postsynaptic) {
      paths = [
        [const Offset(1078, 330), const Offset(1128, 292), const Offset(1170, 250)],
        [const Offset(1078, 372), const Offset(1136, 372), const Offset(1180, 382)],
        [const Offset(1078, 430), const Offset(1132, 468), const Offset(1174, 516)],
      ];
    }
    for (final pts in paths) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      if (pts.length == 3) {
        final mid = Offset(
          (pts[0].dx + pts[1].dx) / 2,
          (pts[0].dy + pts[1].dy) / 2,
        );
        path.quadraticBezierTo(mid.dx, mid.dy, pts[1].dx, pts[1].dy);
        path.lineTo(pts[2].dx, pts[2].dy);
      } else {
        path.lineTo(pts[1].dx, pts[1].dy);
      }
      canvas.drawPath(path, line);
      canvas.drawCircle(pts.last, 6.5, tip);
    }
  }

  void _drawPostsynapticDendriteTips(Canvas canvas) {
    // The functional "continuation" path is drawn separately only when the
    // signal reaches stage 8+, so the anatomical tips stay static.
  }

  void _drawSoma(Canvas canvas, {required bool postsynaptic}) {
    final center = postsynaptic ? const Offset(1020, 400) : const Offset(255, 400);
    final fill = postsynaptic ? _c.postFill : _c.presynapticFill;
    final stroke = postsynaptic ? _c.postStroke : _c.presynapticStroke;
    final rect = Rect.fromCenter(center: center, width: 168, height: 196);
    canvas.drawOval(rect, Paint()..color = fill);
    canvas.drawOval(
      rect,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final nucleus = postsynaptic ? const Offset(1024, 398) : const Offset(258, 396);
    canvas.drawCircle(nucleus, 32, Paint()..color = _c.nucleusFill);
    canvas.drawCircle(
      nucleus,
      32,
      Paint()
        ..color = _c.nucleusStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(nucleus, 12, Paint()..color = _c.nucleusNucleolus);
  }

  void _drawAxon(Canvas canvas) {
    final axon = Paint()
      ..color = _c.axon
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(318, 400), const Offset(868, 400), axon);

    const segWidth = 78.0;
    const gap = 16.0;
    var x = 336.0;
    var i = 0;
    while (x < 812.0 - segWidth - gap) {
      final sweep = segWidth < (812.0 - x) ? segWidth : (812.0 - x);
      final rect = Rect.fromLTWH(x, 366, sweep, 68);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        Paint()..color = _c.myelinFill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        Paint()
          ..color = _c.myelinStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (i == 1) {
        final nodeX = x + segWidth + gap / 2;
        canvas.drawLine(
          Offset(nodeX, 358),
          Offset(nodeX, 442),
          Paint()
            ..color = _c.leader
            ..strokeWidth = 1.5,
        );
      }
      x += segWidth + gap;
      i++;
    }
  }

  void _drawBoutons(Canvas canvas, int st, double pr) {
    const boutons = [Offset(884, 372), Offset(884, 428)];
    for (final b in boutons) {
      final rect = Rect.fromCenter(center: b, width: 46, height: 38);
      canvas.drawOval(rect, Paint()..color = _c.presynapticFill);
      canvas.drawOval(
        rect,
        Paint()
          ..color = _c.presynapticStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    final releasing = _in(st, 4, 5);
    final depleted = st >= 6;
    for (final b in boutons) {
      var count = 5;
      var displace = 0.0;
      var docked = false;
      if (releasing) {
        final t = ((st - 4) + pr.clamp(0.0, 1.0)).clamp(0.0, 1.0);
        displace = 16.0 * t;
        count = (5 - (t * 5).ceil()).clamp(0, 5);
        docked = t > 0.45;
      } else if (depleted) {
        count = 0;
      } else if (st < 3) {
        count = 3;
      }
      if (docked) {
        canvas.drawCircle(
          Offset(b.dx + 24, b.dy),
          5,
          Paint()..color = _c.vesicle,
        );
      }
      for (var i = 0; i < count; i++) {
        final dx = _disp(b.dx, i, 0) * 7 + displace * 2.4;
        final dy = _disp(b.dy, i, 2) * 4 - displace * 2.6;
        final base = Offset(b.dx + dx, b.dy + dy);
        canvas.drawCircle(base, 4, Paint()..color = _c.vesicle);
        canvas.drawCircle(
          base,
          4,
          Paint()
            ..color = _c.vesicleStroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  double _disp(double seed, int i, int salt) {
    final v = seed + i * 1.6180339 + salt * 0.5772156;
    return (v - v.floorToDouble()) * 2 - 1;
  }

  // ── Synapse ────────────────────────────────────────────────────────

  void _drawCleft(Canvas canvas, int st, double pr) {
    const rect = Rect.fromLTRB(906, 300, 940, 500);
    canvas.drawRect(rect, Paint()..color = _c.cleftFill);
    canvas.drawRect(
      rect,
      Paint()
        ..color = _c.cleftFrame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    if (!scene.animate || !_in(st, 5, 7)) return;
    final t = ((st - 5) + pr.clamp(0.0, 1.0)).clamp(0.0, 1.0);
    final fx = _lerp(918, 934, t);
    for (var i = 0; i < 3; i++) {
      final lane = 344.0 + i * 48;
      final p = Offset(fx + _disp(i.toDouble(), 7, 1) * 5, lane);
      canvas.drawCircle(p, 3.6, Paint()..color = _c.neurotransmitter);
    }
  }

  // ── Postsynaptic neuron ────────────────────────────────────────────

  void _drawPostsynaptic(Canvas canvas, int st, double pr) {
    final membrane = Paint()
      ..color = _c.postStroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(942, 268),
      const Offset(942, 532),
      membrane,
    );

    final receptors = [340.0, 384.0, 418.0, 452.0];
    for (final y in receptors) {
      final bound = _in(st, 7, 8);
      final glow = bound && ((st - 7) + pr.clamp(0.0, 1.0)).clamp(0.0, 1.0) > 0.4;
      final color = glow ? _c.receptorGlow : _c.receptor;
      canvas.drawLine(
        Offset(942, y),
        Offset(930, y),
        Paint()
          ..color = color
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(929, y), 5, Paint()..color = color);
    }

    if (scene.animate && st >= 8) {
      final intensity = 0.14 + 0.18 * pr.clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(1010, 420), width: 215, height: 250),
        Paint()..color = _c.postGlow.withValues(alpha: intensity),
      );
    }
  }

  void _drawSignalPulse(Canvas canvas, int st, double pr) {
    if (st == 0) return;
    final Offset? pos;
    if (st == 1) {
      pos = Offset(_lerp(330, 352, pr), 400);
    } else if (st == 2) {
      pos = Offset(_lerp(352, 852, pr), 400);
    } else if (st == 3) {
      pos = const Offset(860, 400);
    } else if (st == 8 || st == 9) {
      final x = _lerp(1020, 1170, pr);
      final y = _lerp(430, 505, pr);
      _pulse(canvas, Offset(x, y), 18);
      return;
    } else {
      pos = null;
    }
    if (pos == null) return;
    _pulse(canvas, pos, 26);
  }

  void _pulse(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius + 10,
      Paint()..color = _c.signal.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = _c.signal.withValues(alpha: 0.35),
    );
    canvas.drawCircle(center, 12, Paint()..color = _c.signal);
    canvas.drawCircle(center, 4.5, Paint()..color = _c.signalCore);
  }

  void _drawRestingIons(Canvas canvas, int st, double pr) {
    var pulseX = -1.0;
    if (st == 1) pulseX = _lerp(330, 352, pr);
    if (st == 2) pulseX = _lerp(352, 852, pr);
    if (st >= 3) pulseX = 860;

    for (final x in [360.0, 470.0, 600.0, 720.0]) {
      final near = pulseX >= 0 && (x - pulseX).abs() < 30;
      final reversed = st != 0 && near;
      _ion(canvas, Offset(x, 330), outside: true, reversed: reversed);
      _ion(canvas, Offset(x, 470), outside: false, reversed: !reversed);
    }
  }

  void _ion(Canvas canvas, Offset at, {required bool outside, required bool reversed}) {
    final plus = outside ? !reversed : reversed;
    canvas.drawCircle(at, 9, Paint()..color = _c.ionHalo);
    canvas.drawCircle(at, 9, Paint()..color = _c.ion);
    final tp = TextPainter(
      text: TextSpan(
        text: plus ? '+' : '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _c.ionText,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawNaInflux(Canvas canvas, int st, double pr) {
    for (var i = 0; i < 3; i++) {
      final t = ((st - 8) + pr.clamp(0.0, 1.0) + i * 0.12) % 1.0;
      final x = _lerp(952, 994, t);
      final y = _lerp(392, 420, t);
      canvas.drawCircle(Offset(x, y), 3.2, Paint()..color = _c.naIon);
    }
  }

  void _drawLegend(Canvas canvas) {
    const styleB = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFFFFB020),
    );
    const styleM = TextStyle(fontSize: 12, color: Color(0xFF9A98AC));
    const styleT = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF2DD4BF),
    );
    final tp = TextPainter(
      text: const TextSpan(children: [
        TextSpan(text: 'Electrical signalling ', style: styleB),
        TextSpan(text: 'within a neuron   ·   ', style: styleM),
        TextSpan(text: 'Chemical signalling ', style: styleT),
        TextSpan(text: 'across the synapse', style: styleM),
      ]),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(40, 26));
  }

  // ── Labels ─────────────────────────────────────────────────────────

  void _drawLabels(Canvas canvas) {
    final labels = <List<double>>[
      [92, 238, 20, 150, 0], // dendrites
      [255, 356, 320, 270, 1], // nucleus
      [430, 350, 470, 230, 2], // myelin
      [664, 350, 700, 230, 3], // node
      [560, 420, 400, 640, 4], // axon
      [180, 468, 30, 610, 5], // soma
      [858, 370, 700, 90, 6], // terminal
      [904, 344, 830, 120, 7], // vesicles
      [924, 210, 840, 40, 8], // cleft
      [944, 452, 1020, 648, 9], // postsynaptic membrane
      [928, 520, 800, 690, 10], // neurotransmitter
      [944, 384, 1090, 470, 11], // receptors
    ];
    final names = <String>[
      'Dendrites',
      'Nucleus',
      'Myelin sheath',
      'Node of Ranvier',
      'Axon',
      'Cell body (soma)',
      'Axon terminal',
      'Synaptic vesicles',
      'Synaptic cleft',
      'Postsynaptic membrane',
      'Neurotransmitters',
      'Receptors',
    ];
    for (var i = 0; i < labels.length; i++) {
      final l = labels[i];
      _leaderLabel(
        canvas,
        anchor: Offset(l[0], l[1]),
        label: Offset(l[2], l[3]),
        text: names[i],
      );
    }
  }

  void _leaderLabel(Canvas canvas, {required Offset anchor, required Offset label, required String text}) {
    final textW = text.length * 11.5;
    final startX = label.dx + textW + 8;
    canvas.drawLine(
      Offset(startX, label.dy + 11),
      Offset(anchor.dx > startX ? anchor.dx - 6 : anchor.dx + 6, anchor.dy),
      Paint()
        ..color = _c.leader
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(anchor, 3.2, Paint()..color = _c.leaderDot);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _c.labelInk,
          backgroundColor: _c.halo,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, label);
  }

  @override
  bool shouldRepaint(covariant NeuronPainter oldDelegate) =>
      oldDelegate.scene.stage != scene.stage ||
      (oldDelegate.scene.progress - scene.progress).abs() > 1e-4 ||
      oldDelegate.scene.labelsOn != scene.labelsOn ||
      oldDelegate.scene.dark != scene.dark ||
      oldDelegate.scene.animate != scene.animate;
}
