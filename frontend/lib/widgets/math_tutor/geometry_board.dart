import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'geometry_lesson.dart';
import 'geometry_scene.dart';
import 'math_solution.dart';

/// A hand-drawn geometry board with a teacher's hand.
///
/// The construction is demonstrated the way it happens on paper: the teacher
/// reaches for a ruler, rules each side so the pencil follows the frontier, sets
/// the right angle with a protractor, rubs out the temporary guide and finally
/// highlights the hypotenuse. Every object comes from the semantic scene graph
/// ([GeometryScene]) and the beat order from the [GeometryLesson], so the
/// picture is always a faithful, proportionally-scaled drawing of the verified
/// numbers and never snaps into place.
class GeometryBoard extends StatefulWidget {
  const GeometryBoard({
    super.key,
    required this.solution,
    required this.stepIndex,
  });

  final TutorSolution solution;
  final int stepIndex;

  @override
  State<GeometryBoard> createState() => _GeometryBoardState();
}

class _GeometryBoardState extends State<GeometryBoard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late GeometryLesson _lesson;

  @override
  void initState() {
    super.initState();
    _lesson = _buildLesson();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      upperBound: math.max(1.0, (_lesson.length - 1).toDouble()),
    );
    _animateTo(_target);
  }

  GeometryLesson _buildLesson() {
    final double a = widget.solution.sideA ?? 3;
    final double b = widget.solution.sideB ?? 4;
    final double c = widget.solution.sideC ?? math.sqrt(a * a + b * b);
    return GeometryLesson.rightTriangle(GeometryScene.rightTriangle(a: a, b: b, c: c));
  }

  /// Construction beat reached on the current step.
  double get _target => _lesson.beatIndexFor(widget.stepIndex, widget.solution.stepCount).toDouble();

  @override
  void didUpdateWidget(covariant GeometryBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool newProblem = oldWidget.solution != widget.solution;
    if (newProblem) {
      final GeometryLesson rebuilt = _buildLesson();
      final bool lengthChanged = rebuilt.length != _lesson.length;
      _lesson = rebuilt;
      if (lengthChanged) {
        _controller.dispose();
        _controller = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
          upperBound: math.max(1.0, (_lesson.length - 1).toDouble()),
        );
      }
    }
    if (newProblem || oldWidget.stepIndex != widget.stepIndex) {
      _animateTo(_target);
    }
  }

  void _animateTo(double target) {
    // A shrink means a fresh problem has been laid out; reset the sheet rather
    // than visibly rubbing the old construction out line by line.
    if (target <= _controller.value + 0.001) {
      _controller.value = target.clamp(0.0, _controller.upperBound);
      return;
    }
    // The pause is proportional to how much is left to draw, so a long side
    // takes longer than a short one.
    final int ms = ((target - _controller.value) * 950).clamp(500, 2600).round();
    _controller.animateTo(target, duration: Duration(milliseconds: ms), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = math.max(constraints.maxWidth, 280.0);
        final double height = math.min(math.max(width * 0.66, 250.0), 400.0);
        return SizedBox(
          width: width,
          height: height,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? _) => CustomPaint(
              painter: _GeometryBoardPainter(
                lesson: _lesson,
                position: _controller.value,
                board: scheme.surfaceContainerLowest,
                grid: scheme.outlineVariant.withAlpha(55),
                line: scheme.primary,
                accent: scheme.tertiary,
                label: scheme.onSurface,
                rulerBody: scheme.surfaceContainerHighest,
                rulerEdge: scheme.outline,
                guide: scheme.outline,
                tray: scheme.surfaceContainerHigh,
                panel: scheme.surface.withAlpha(238),
                panelEdge: scheme.outlineVariant,
                skin: const Color(0xFFE8B48C),
                sleeve: scheme.primary,
                wood: const Color(0xFF8D6E63),
                graphite: const Color(0xFF37474F),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GeometryBoardPainter extends CustomPainter {
  _GeometryBoardPainter({
    required this.lesson,
    required this.position,
    required this.board,
    required this.grid,
    required this.line,
    required this.accent,
    required this.label,
    required this.rulerBody,
    required this.rulerEdge,
    required this.guide,
    required this.tray,
    required this.panel,
    required this.panelEdge,
    required this.skin,
    required this.sleeve,
    required this.wood,
    required this.graphite,
  });

  final GeometryLesson lesson;
  final double position;
  final Color board;
  final Color grid;
  final Color line;
  final Color accent;
  final Color label;
  final Color rulerBody;
  final Color rulerEdge;
  final Color guide;
  final Color tray;
  final Color panel;
  final Color panelEdge;
  final Color skin;
  final Color sleeve;
  final Color wood;
  final Color graphite;

  static const double _padLeft = 54;
  static const double _padRight = 54;
  static const double _drawTop = 74;
  static const double _trayHeight = 74;

  @override
  void paint(Canvas canvas, Size size) {
    _paintBoard(canvas, size);
    final GeometryScene scene = lesson.scene;
    final _Layout layout = _layout(size, scene);
    final double p = position.clamp(0.0, (lesson.length - 1).toDouble());

    final GeometryObject? guideObj = scene.byId('guide-base');
    if (guideObj != null) {
      final double ga = _guideAlpha(p);
      if (ga > 0) {
        _drawGuide(canvas, layout.toPixel(guideObj.start), layout.toPixel(guideObj.end), ga);
      }
    }

    // Faint glow behind the hypotenuse as it is revealed last.
    final double highlight = (p - (lesson.length - 2)).clamp(0.0, 1.0);
    if (highlight > 0) {
      final GeometryObject hyp = scene.byId('side-c')!;
      _drawHighlight(canvas, layout.toPixel(hyp.start), layout.toPixel(hyp.end), highlight);
    }

    for (final String id in const <String>['side-a', 'side-b', 'side-c']) {
      final GeometryObject object = scene.byId(id)!;
      final double t = _reveal(id, p);
      if (t <= 0) continue;
      _drawSide(canvas, layout.toPixel(object.start), layout.toPixel(object.end), layout.centroidPx, t,
          object.value ?? 0, layout.scale);
    }

    final double angleT = _reveal('right-angle', p);
    if (angleT > 0) _drawRightAngle(canvas, layout.vertexPx, layout.tipXPx, layout.tipYPx, angleT, layout.scale);

    _drawLabels(canvas, scene, layout, p);

    final GeometryBeat beat = lesson.beatAt(p.round());
    _drawTray(canvas, size, layout, beat.instrument);
    _drawHand(canvas, _handPose(p, size, layout));
    _drawPanel(canvas, size, beat, p);
  }

  _Layout _layout(Size size, GeometryScene scene) {
    final double trayTop = size.height - _trayHeight;
    final double drawBottom = trayTop - 10;
    final double availW = math.max(size.width - _padLeft - _padRight, 40);
    final double availH = math.max(drawBottom - _drawTop, 40);
    final double scale = math.min(availW / scene.a, availH / scene.b).clamp(6.0, 200.0);
    final Offset origin = Offset(_padLeft, drawBottom);
    Offset toPixel(Offset m) => Offset(origin.dx + m.dx * scale, origin.dy - m.dy * scale);
    final Offset vertexPx = toPixel(scene.vertex);
    final Offset tipXPx = toPixel(scene.tipX);
    final Offset tipYPx = toPixel(scene.tipY);
    final Offset centroidPx = Offset(
      (vertexPx.dx + tipXPx.dx + tipYPx.dx) / 3,
      (vertexPx.dy + tipXPx.dy + tipYPx.dy) / 3,
    );
    return _Layout(
      scale: scale,
      origin: origin,
      vertexPx: vertexPx,
      tipXPx: tipXPx,
      tipYPx: tipYPx,
      centroidPx: centroidPx,
      trayTop: trayTop,
    );
  }

  double _reveal(String id, double p) {
    final int? beat = lesson.drawBeatOf(id);
    if (beat == null) return 0;
    return (p - (beat - 1)).clamp(0.0, 1.0);
  }

  double _guideAlpha(double p) {
    final int? erase = lesson.eraseGuideBeat;
    if (erase == null) return 0;
    if (p <= erase) return 1;
    if (p >= erase + 1) return 0;
    return 1 - (p - erase);
  }

  void _paintBoard(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = board);

    final Paint gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    const double gap = 26;
    for (double y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (double x = gap; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    canvas.drawLine(
      const Offset(34, 0),
      Offset(34, size.height),
      Paint()
        ..color = line.withAlpha(38)
        ..strokeWidth = 1.2,
    );
  }

  /// Rules one side: the line is drawn up to the pencil, a calibrated ruler runs
  /// alongside it, and both slide forward until the side is complete.
  void _drawSide(Canvas canvas, Offset from, Offset to, Offset centroid, double t, double units, double scale) {
    if (t <= 0) return;
    final Offset delta = to - from;
    final double length = delta.distance;
    if (length <= 0) return;
    final Offset dir = delta / length;
    final Offset outward = _outwardNormal(from, to, centroid);
    final Offset tip = from + delta * t;

    canvas.drawLine(
      from,
      tip,
      Paint()
        ..color = line
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(from, 3.2, Paint()..color = line);

    if (t < 0.999) {
      final double fade = t < 0.9 ? 1.0 : (1 - (t - 0.9) / 0.1);
      _drawRuler(canvas, from, to, outward, units, scale, fade);
      _drawPencil(canvas, tip, dir);
    }
  }

  /// Unit vector pointing away from the triangle's interior, so instruments sit
  /// on the outside of the shape instead of covering it.
  Offset _outwardNormal(Offset from, Offset to, Offset centroid) {
    final Offset delta = to - from;
    final double length = delta.distance;
    final Offset dir = delta / length;
    final Offset normal = Offset(-dir.dy, dir.dx);
    final Offset mid = (from + to) / 2;
    final Offset away = mid - centroid;
    return (normal.dx * away.dx + normal.dy * away.dy) >= 0 ? normal : -normal;
  }

  void _drawRuler(Canvas canvas, Offset from, Offset to, Offset outward, double units, double scale, double fade) {
    final Offset delta = to - from;
    final Offset dir = delta / delta.distance;
    const double near = 15;
    const double far = 45;
    const double overhang = 16;

    final Offset start = from - dir * overhang;
    final Offset end = to + dir * overhang;
    final Path path = Path()
      ..moveTo(start.dx + outward.dx * near, start.dy + outward.dy * near)
      ..lineTo(end.dx + outward.dx * near, end.dy + outward.dy * near)
      ..lineTo(end.dx + outward.dx * far, end.dy + outward.dy * far)
      ..lineTo(start.dx + outward.dx * far, start.dy + outward.dy * far)
      ..close();

    final int intAlpha = (fade.clamp(0.0, 1.0) * 255).round();
    canvas.drawPath(path, Paint()..color = rulerBody.withAlpha((intAlpha * 0.92).round()));
    canvas.drawPath(
      path,
      Paint()
        ..color = rulerEdge.withAlpha((intAlpha * 0.6).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final int count = units.floor();
    final double angle = _uprightAngle(dir);
    for (int i = 0; i <= count; i++) {
      final Offset at = from + dir * (i * scale);
      canvas.drawLine(
        at + outward * near,
        at + outward * (near + 6),
        Paint()
          ..color = graphite.withAlpha(intAlpha)
          ..strokeWidth = 1.1,
      );
      _rotatedText(canvas, '$i', at + outward * (near + 12), angle, graphite.withAlpha(intAlpha), 8.5);
    }
    if (scale > 44) {
      for (int i = 0; i < count; i++) {
        final Offset at = from + dir * ((i + 0.5) * scale);
        canvas.drawLine(
          at + outward * near,
          at + outward * (near + 3.5),
          Paint()
            ..color = graphite.withAlpha((intAlpha * 0.7).round())
            ..strokeWidth = 1,
        );
      }
    }
  }

  /// A simple wooden pencil, its tip resting exactly on the drawing frontier.
  void _drawPencil(Canvas canvas, Offset tip, Offset dir) {
    final double angle = math.atan2(dir.dy, dir.dx);
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-30, -4.5, 24, 9), const Radius.circular(2)),
      Paint()..color = wood,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-30, -4.5, 24, 9), const Radius.circular(2)),
      Paint()
        ..color = Colors.black.withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final Path tipPath = Path()
      ..moveTo(-6, -4.5)
      ..lineTo(0, 0)
      ..lineTo(-6, 4.5)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = const Color(0xFFE6D2C0));
    final Path leadPath = Path()
      ..moveTo(-2.4, -2)
      ..lineTo(0, 0)
      ..lineTo(-2.4, 2)
      ..close();
    canvas.drawPath(leadPath, Paint()..color = graphite);
    canvas.restore();
  }

  /// Lays a protractor on the corner and sweeps out the measured right angle.
  void _drawRightAngle(Canvas canvas, Offset vertex, Offset cornerA, Offset cornerB, double t, double scale) {
    final Offset aDir = cornerA - vertex;
    final Offset bDir = cornerB - vertex;
    if (aDir.distance == 0 || bDir.distance == 0) return;
    final Offset aN = aDir / aDir.distance;
    final Offset bN = bDir / bDir.distance;

    final double baseAngle = math.atan2(aN.dy, aN.dx);
    final double cross = aN.dx * bN.dy - aN.dy * bN.dx;
    final double dot = aN.dx * bN.dx + aN.dy * bN.dy;
    final double sweep = math.atan2(cross, dot);

    final double radius = math.min(scale * 1.15, 58.0);
    final Rect rect = Rect.fromCircle(center: vertex, radius: radius);
    final double semiSweep = sweep.isNegative ? -math.pi : math.pi;

    canvas.drawArc(rect, baseAngle, semiSweep, true, Paint()..color = accent.withAlpha(26));
    canvas.drawArc(
      rect,
      baseAngle,
      semiSweep,
      true,
      Paint()
        ..color = accent.withAlpha(110)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final Paint tick = Paint()
      ..color = accent.withAlpha(130)
      ..strokeWidth = 1;
    for (int k = 0; k <= 18; k++) {
      final double angle = baseAngle + semiSweep * (k / 18);
      final Offset outer = vertex + Offset(math.cos(angle), math.sin(angle)) * radius;
      final Offset inner = vertex + Offset(math.cos(angle), math.sin(angle)) * (radius - 7);
      canvas.drawLine(inner, outer, tick);
    }

    canvas.drawArc(
      rect,
      baseAngle,
      sweep * t,
      false,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );

    final double side = math.min(scale * 0.42, 22.0);
    final Path square = Path()
      ..moveTo(vertex.dx + aN.dx * side, vertex.dy + aN.dy * side)
      ..lineTo(vertex.dx + (aN.dx + bN.dx) * side, vertex.dy + (aN.dy + bN.dy) * side)
      ..lineTo(vertex.dx + bN.dx * side, vertex.dy + bN.dy * side);
    canvas.drawPath(
      square,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    _text(canvas, '90\u00b0', vertex + (aN + bN) * (radius * 0.52), label.withAlpha(200), 11);
  }

  void _drawHighlight(Canvas canvas, Offset from, Offset to, double h) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = accent.withAlpha((70 * h).round())
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawGuide(Canvas canvas, Offset from, Offset to, double alpha) {
    final Offset delta = to - from;
    final double length = delta.distance;
    if (length <= 0) return;
    final Offset dir = delta / length;
    final Paint paint = Paint()
      ..color = guide.withAlpha((alpha * 170).round())
      ..strokeWidth = 1.4;
    const double dash = 6;
    const double space = 5;
    for (double d = 0; d < length; d += dash + space) {
      canvas.drawLine(from + dir * d, from + dir * math.min(d + dash, length), paint);
    }
  }

  void _drawLabels(Canvas canvas, GeometryScene scene, _Layout layout, double p) {
    for (final String id in const <String>['side-a', 'side-b', 'side-c']) {
      final GeometryObject object = scene.byId(id)!;
      final double t = _reveal(id, p);
      if (t <= 0) continue;
      final int alpha = (t.clamp(0.0, 1.0) * 255).round();
      final Offset mid = (layout.toPixel(object.start) + layout.toPixel(object.end)) / 2;
      final Offset offset = _labelOffset(id, layout);
      final String text = '${object.label} = ${_fmt(object.value ?? 0)}';
      _text(
        canvas,
        text,
        mid + offset,
        id == 'side-c' ? accent.withAlpha(alpha) : label.withAlpha(alpha),
        12.5,
      );
    }
  }

  Offset _labelOffset(String id, _Layout layout) {
    if (id == 'side-a') return const Offset(0, 20);
    if (id == 'side-b') return const Offset(-30, 0);
    final Offset mid = (layout.tipXPx + layout.tipYPx) / 2;
    final Offset away = mid - layout.centroidPx;
    final double len = away.distance;
    return len == 0 ? const Offset(24, -12) : away / len * 24;
  }

  void _drawTray(Canvas canvas, Size size, _Layout layout, MathInstrument active) {
    final Rect strip = Rect.fromLTWH(0, layout.trayTop, size.width, size.height - layout.trayTop);
    canvas.drawRect(strip, Paint()..color = tray);
    canvas.drawLine(
      Offset(0, layout.trayTop),
      Offset(size.width, layout.trayTop),
      Paint()
        ..color = panelEdge
        ..strokeWidth = 1,
    );
    final Map<MathInstrument, Offset> slots = _traySlots(size);
    for (final MapEntry<MathInstrument, Offset> entry in slots.entries) {
      _drawToolIcon(canvas, entry.key, entry.value, lifted: entry.key == active);
    }
  }

  Map<MathInstrument, Offset> _traySlots(Size size) {
    final double cy = size.height - _trayHeight / 2;
    return <MathInstrument, Offset>{
      MathInstrument.ruler: Offset(size.width * 0.16, cy),
      MathInstrument.protractor: Offset(size.width * 0.34, cy),
      MathInstrument.pencil: Offset(size.width * 0.50, cy),
      MathInstrument.eraser: Offset(size.width * 0.66, cy),
      MathInstrument.compass: Offset(size.width * 0.82, cy),
    };
  }

  void _drawToolIcon(Canvas canvas, MathInstrument instrument, Offset at, {required bool lifted}) {
    final Color colour = label.withAlpha(lifted ? 70 : 190);
    final Paint paint = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    switch (instrument) {
      case MathInstrument.ruler:
        canvas.drawRect(const Rect.fromLTWH(-18, -6, 36, 12), paint);
        for (double x = -12; x <= 12; x += 6) {
          canvas.drawLine(Offset(x, -6), Offset(x, -1), paint);
        }
      case MathInstrument.protractor:
        canvas.drawArc(const Rect.fromLTWH(-14, -12, 28, 24), math.pi, math.pi, false, paint);
        canvas.drawLine(const Offset(-14, 0), const Offset(14, 0), paint);
      case MathInstrument.pencil:
        canvas.drawRect(const Rect.fromLTWH(-16, -3.5, 22, 7), paint);
        final Path tip = Path()
          ..moveTo(6, -3.5)
          ..lineTo(12, 0)
          ..lineTo(6, 3.5);
        canvas.drawPath(tip, paint);
      case MathInstrument.eraser:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -6, 24, 12), const Radius.circular(3)),
          paint,
        );
      case MathInstrument.compass:
        canvas.drawLine(const Offset(0, -10), const Offset(-9, 8), paint);
        canvas.drawLine(const Offset(0, -10), const Offset(9, 8), paint);
        canvas.drawCircle(const Offset(0, -10), 2.4, paint);
      case MathInstrument.setSquare:
      case MathInstrument.divider:
      case MathInstrument.none:
        canvas.drawCircle(Offset.zero, 6, paint);
    }
    canvas.restore();
  }

  _HandPose _handPose(double p, Size size, _Layout layout) {
    final GeometryScene scene = lesson.scene;
    final Offset vertex = layout.vertexPx;
    final Offset tipX = layout.tipXPx;
    final Offset tipY = layout.tipYPx;
    final Offset sideAMid = (vertex + tipX) / 2;
    final Offset sideBMid = (vertex + tipY) / 2;
    final Offset sideCMid = (tipX + tipY) / 2;
    final GeometryObject guideObj = scene.byId('guide-base')!;
    final Offset guideMid = layout.toPixel((guideObj.start + guideObj.end) / 2);
    final Map<MathInstrument, Offset> slots = _traySlots(size);
    final Offset neutral = Offset(size.width - 30, size.height - 24);

    final Offset outward = sideCMid - layout.centroidPx;
    final Offset pointAt = sideCMid + (outward.distance == 0 ? const Offset(20, -10) : outward / outward.distance * 26);

    final List<_HandPose> anchors = <_HandPose>[
      _HandPose(slots[MathInstrument.ruler]!, 0, MathInstrument.ruler),
      _HandPose(sideAMid, _angle(tipX - vertex), MathInstrument.pencil),
      _HandPose(vertex, 0, MathInstrument.protractor),
      _HandPose(sideBMid, _angle(tipY - vertex), MathInstrument.pencil),
      _HandPose(sideCMid, _angle(tipY - tipX), MathInstrument.pencil),
      _HandPose(guideMid, math.pi, MathInstrument.eraser),
      _HandPose(pointAt, _angle(tipY - tipX), MathInstrument.none, pointing: true),
      _HandPose(neutral, 0, MathInstrument.none),
    ];

    final int lo = p.floor().clamp(0, anchors.length - 1);
    final int hi = (lo + 1).clamp(0, anchors.length - 1);
    final double f = Curves.easeInOut.transform((p - lo).clamp(0.0, 1.0));
    return _lerpPose(anchors[lo], anchors[hi], f);
  }

  _HandPose _lerpPose(_HandPose a, _HandPose b, double f) => _HandPose(
        Offset.lerp(a.position, b.position, f)!,
        a.angle + (b.angle - a.angle) * f,
        f < 0.85 ? a.instrument : b.instrument,
        pointing: f < 0.85 ? a.pointing : b.pointing,
      );

  void _drawHand(Canvas canvas, _HandPose pose) {
    final Offset hand = pose.position;
    final Offset wrist = hand + const Offset(3, 14);
    final Offset elbow = wrist + const Offset(26, 40);
    canvas.drawLine(
      wrist,
      elbow,
      Paint()
        ..color = sleeve
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      wrist,
      elbow,
      Paint()
        ..color = Colors.black.withAlpha(22)
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(pose.angle);
    final Paint skinPaint = Paint()..color = skin;
    final Paint fingerPaint = Paint()
      ..color = skin
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final bool grip = pose.instrument == MathInstrument.pencil ||
        pose.instrument == MathInstrument.eraser ||
        pose.instrument == MathInstrument.protractor;

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-17, -14, 32, 28), const Radius.circular(10)),
      skinPaint,
    );
    for (int i = 0; i < 4; i++) {
      final double y = -10 + i * 6.6;
      final double len = grip ? 11 : 20;
      canvas.drawLine(Offset(6, y), Offset(6 + len, y), fingerPaint);
    }
    canvas.drawLine(
        const Offset(-10, 4),
        const Offset(4, 15),
        Paint()
          ..color = skin
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round);
    if (pose.pointing) {
      canvas.drawLine(const Offset(6, -10), const Offset(32, -10), fingerPaint);
    }
    if (pose.instrument == MathInstrument.eraser) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(14, -8, 20, 16), const Radius.circular(3)),
        Paint()..color = const Color(0xFFF48FB1),
      );
    }
    canvas.restore();
  }

  void _drawPanel(Canvas canvas, Size size, GeometryBeat beat, double p) {
    final RRect rect = RRect.fromRectAndRadius(Rect.fromLTWH(10, 8, size.width - 20, 56), const Radius.circular(9));
    canvas.drawRRect(rect, Paint()..color = panel);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = panelEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final int number = p.round() + 1;
    _textLeft(canvas, 'STEP $number/${lesson.length}', const Offset(22, 17), accent, 10, FontWeight.w700);
    _textLeft(canvas, beat.title, const Offset(22, 30), label, 13, FontWeight.w700);
    final String tool = _instrumentName(beat.instrument);
    final String why = tool.isEmpty ? beat.why : '$tool \u00b7 ${beat.why}';
    _textLeft(canvas, _ellipsize(why, 62), const Offset(22, 47), label.withAlpha(170), 10.5, FontWeight.w500);
  }

  static String _instrumentName(MathInstrument instrument) => switch (instrument) {
        MathInstrument.none => '',
        MathInstrument.ruler => 'Ruler',
        MathInstrument.protractor => 'Protractor',
        MathInstrument.pencil => 'Pencil',
        MathInstrument.compass => 'Compass',
        MathInstrument.eraser => 'Eraser',
        MathInstrument.setSquare => 'Set square',
        MathInstrument.divider => 'Divider',
      };

  static String _ellipsize(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max - 1).trimRight()}\u2026';

  double _angle(Offset d) => math.atan2(d.dy, d.dx);

  void _text(Canvas canvas, String text, Offset centre, Color color, double fontSize) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(centre.dx - painter.width / 2, centre.dy - painter.height / 2));
  }

  void _textLeft(Canvas canvas, String text, Offset at, Color color, double fontSize, FontWeight weight) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  void _rotatedText(Canvas canvas, String text, Offset at, double angle, Color color, double fontSize) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  /// Keeps ruler numerals the right way up regardless of the side's slope.
  double _uprightAngle(Offset dir) {
    double angle = math.atan2(dir.dy, dir.dx);
    if (angle > math.pi / 2) angle -= math.pi;
    if (angle < -math.pi / 2) angle += math.pi;
    return angle;
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return ((value * 100).round() / 100).toString();
  }

  @override
  bool shouldRepaint(_GeometryBoardPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.lesson != lesson ||
      oldDelegate.board != board ||
      oldDelegate.accent != accent;
}

class _Layout {
  const _Layout({
    required this.scale,
    required this.origin,
    required this.vertexPx,
    required this.tipXPx,
    required this.tipYPx,
    required this.centroidPx,
    required this.trayTop,
  });

  final double scale;
  final Offset origin;
  final Offset vertexPx;
  final Offset tipXPx;
  final Offset tipYPx;
  final Offset centroidPx;
  final double trayTop;

  Offset toPixel(Offset m) => Offset(origin.dx + m.dx * scale, origin.dy - m.dy * scale);
}

class _HandPose {
  const _HandPose(this.position, this.angle, this.instrument, {this.pointing = false});

  final Offset position;
  final double angle;
  final MathInstrument instrument;
  final bool pointing;
}
