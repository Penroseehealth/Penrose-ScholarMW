import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/board_models.dart';
import '../state/smart_board_controller.dart';

class _TrailPoint {
  _TrailPoint(this.position, this.born);

  final Offset position;
  final DateTime born;
}

/// The live writing surface: lesson layer below, ink above, both in one
/// logical coordinate space so nothing drifts when the layout changes.
class BoardCanvas extends StatefulWidget {
  const BoardCanvas({
    super.key,
    required this.controller,
    required this.lesson,
    this.onRequestText,
    this.onEditText,
  });

  final SmartBoardController controller;
  final Widget lesson;

  /// Fired when the text tool is tapped, with the board-space point.
  final void Function(Offset boardPoint)? onRequestText;

  /// Fired when an existing text object is activated for editing. The id has
  /// the `t:` selection prefix stripped.
  final void Function(String textId)? onEditText;

  @override
  State<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends State<BoardCanvas> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'smart-board-canvas');
  final List<Offset> _draft = <Offset>[];
  final List<_TrailPoint> _trail = <_TrailPoint>[];

  Offset? _shapeStart;
  Offset? _shapeEnd;
  Offset? _dragAnchor;
  String? _lastSelectId;
  DateTime? _lastSelectAt;
  Offset _lastLocal = Offset.zero;
  bool _panning = false;
  bool _spaceDown = false;
  bool _erasing = false;
  double _scale = 1;
  Offset _origin = Offset.zero;
  Timer? _trailTimer;

  @override
  void dispose() {
    _trailTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Offset _toBoard(Offset local) => (local - _origin) / _scale;

  MouseCursor get _cursor {
    if (_panning) return SystemMouseCursors.grabbing;
    if (_spaceDown) return SystemMouseCursors.grab;
    switch (widget.controller.tool) {
      case BoardTool.select:
        return SystemMouseCursors.click;
      case BoardTool.pointer:
        return SystemMouseCursors.click;
      case BoardTool.eraser:
        return SystemMouseCursors.cell;
      case BoardTool.pen:
      case BoardTool.highlighter:
      case BoardTool.shape:
      case BoardTool.text:
        return SystemMouseCursors.precise;
    }
  }

  @override
  Widget build(BuildContext context) {
    final SmartBoardController controller = widget.controller;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: MouseRegion(
        cursor: _cursor,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = Size(constraints.maxWidth, constraints.maxHeight);
            final double fit = math.min(size.width / kBoardWidth, size.height / kBoardHeight);
            final double scale = fit.isFinite && fit > 0 ? fit * controller.zoom : 1;
            _scale = scale;
            _origin = Offset(
                  (size.width - kBoardWidth * scale) / 2,
                  (size.height - kBoardHeight * scale) / 2,
                ) +
                controller.pan;

            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              onPointerSignal: _onPointerSignal,
              child: ClipRect(
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Transform.translate(
                        offset: _origin,
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.topLeft,
                          // The lesson always lays out at full board size, even
                          // when the surface on screen is smaller — otherwise the
                          // fixed-size canvas would shrink the layout box and the
                          // lesson would overflow and drift out of step with the
                          // ink coordinate space.
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: kBoardWidth,
                            maxWidth: kBoardWidth,
                            minHeight: kBoardHeight,
                            maxHeight: kBoardHeight,
                            child: SizedBox(
                              width: kBoardWidth,
                              height: kBoardHeight,
                              child: widget.lesson,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BoardPainter(
                          page: controller.currentPage,
                          selectedId: controller.selectedId,
                          draft: _draft,
                          draftColor: controller.color,
                          draftWidth: controller.strokeWidth,
                          draftOpacity: controller.opacity,
                          draftHighlighter: controller.tool == BoardTool.highlighter,
                          shapeStart: _shapeStart,
                          shapeEnd: _shapeEnd,
                          shapeType: controller.shapeType,
                          shapeColor: controller.color,
                          shapeWidth: controller.strokeWidth,
                          trail: _trail,
                          origin: _origin,
                          scale: scale,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Pointer handling ─────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    final SmartBoardController controller = widget.controller;
    final Offset point = _toBoard(event.localPosition);

    if (_spaceDown || event.buttons == kMiddleMouseButton) {
      _panning = true;
      _lastLocal = event.localPosition;
      setState(() {});
      return;
    }

    switch (controller.tool) {
      case BoardTool.select:
        final String? hit = controller.hitTest(point);
        controller.select(hit);

        // Second click on the same text object opens it for editing.
        final bool isText = hit != null && hit.startsWith('t:');
        final bool isDouble = isText &&
            hit == _lastSelectId &&
            _lastSelectAt != null &&
            DateTime.now().difference(_lastSelectAt!) < const Duration(milliseconds: 450);
        _lastSelectId = hit;
        _lastSelectAt = DateTime.now();

        if (isDouble) {
          _dragAnchor = null;
          widget.onEditText?.call(hit.substring(2));
          break;
        }
        if (hit != null) {
          controller.pushHistory();
          _dragAnchor = point;
        }
        break;
      case BoardTool.pen:
      case BoardTool.highlighter:
        setState(() {
          _draft
            ..clear()
            ..add(point);
        });
        break;
      case BoardTool.eraser:
        controller.pushHistory();
        _erasing = true;
        controller.eraseAt(point, controller.eraserRadius);
        break;
      case BoardTool.pointer:
        _addTrail(point);
        break;
      case BoardTool.shape:
        setState(() {
          _shapeStart = point;
          _shapeEnd = point;
        });
        break;
      case BoardTool.text:
        final String? hit = controller.hitTest(point);
        if (hit != null && hit.startsWith('t:')) {
          widget.onEditText?.call(hit.substring(2));
        } else {
          widget.onRequestText?.call(point);
        }
        break;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final SmartBoardController controller = widget.controller;

    if (_panning) {
      controller.panBy(event.localPosition - _lastLocal);
      _lastLocal = event.localPosition;
      return;
    }

    final Offset point = _toBoard(event.localPosition);

    if (_dragAnchor != null) {
      controller.translateSelected(point - _dragAnchor!);
      _dragAnchor = point;
      return;
    }

    if (_draft.isNotEmpty) {
      if ((point - _draft.last).distance > 0.8) {
        setState(() => _draft.add(point));
      }
      return;
    }

    if (_erasing) {
      controller.eraseAt(point, controller.eraserRadius);
      return;
    }

    if (_shapeStart != null) {
      setState(() => _shapeEnd = point);
      return;
    }

    if (controller.tool == BoardTool.pointer) _addTrail(point);
  }

  void _onPointerUp(PointerUpEvent event) {
    final SmartBoardController controller = widget.controller;

    if (_panning) {
      _panning = false;
      setState(() {});
      return;
    }
    if (_dragAnchor != null) {
      _dragAnchor = null;
      return;
    }
    if (_draft.isNotEmpty) {
      final List<Offset> points = List<Offset>.from(_draft);
      setState(_draft.clear);
      controller.commitStroke(points);
      return;
    }
    if (_erasing) {
      _erasing = false;
      return;
    }
    if (_shapeStart != null && _shapeEnd != null) {
      final Offset start = _shapeStart!;
      final Offset end = _shapeEnd!;
      setState(() {
        _shapeStart = null;
        _shapeEnd = null;
      });
      controller.commitShape(controller.shapeType, start, end);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    setState(() {
      _draft.clear();
      _shapeStart = null;
      _shapeEnd = null;
      _panning = false;
      _erasing = false;
      _dragAnchor = null;
    });
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final Set<LogicalKeyboardKey> keys = HardwareKeyboard.instance.logicalKeysPressed;
    final bool mod = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    if (mod) {
      widget.controller.setZoom(widget.controller.zoom + (event.scrollDelta.dy > 0 ? -0.1 : 0.1));
    } else {
      widget.controller.panBy(Offset(-event.scrollDelta.dx, -event.scrollDelta.dy));
    }
  }

  void _addTrail(Offset point) {
    _trail.add(_TrailPoint(point, DateTime.now()));
    _trailTimer ??= Timer.periodic(const Duration(milliseconds: 40), (Timer timer) {
      final DateTime now = DateTime.now();
      _trail.removeWhere((_TrailPoint dot) => now.difference(dot.born).inMilliseconds > 900);
      if (_trail.isEmpty) {
        timer.cancel();
        _trailTimer = null;
      }
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final SmartBoardController controller = widget.controller;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        _spaceDown = true;
      } else if (event is KeyUpEvent) {
        _spaceDown = false;
        _panning = false;
      }
      return KeyEventResult.handled;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final Set<LogicalKeyboardKey> keys = HardwareKeyboard.instance.logicalKeysPressed;
    final bool mod = keys.contains(LogicalKeyboardKey.controlLeft) || keys.contains(LogicalKeyboardKey.controlRight);

    if (mod && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (keys.contains(LogicalKeyboardKey.shiftLeft) || keys.contains(LogicalKeyboardKey.shiftRight)) {
        controller.redo();
      } else {
        controller.undo();
      }
      return KeyEventResult.handled;
    }
    if (mod && event.logicalKey == LogicalKeyboardKey.keyY) {
      controller.redo();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
      controller.deleteSelected();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      controller.select(null);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.page,
    required this.selectedId,
    required this.draft,
    required this.draftColor,
    required this.draftWidth,
    required this.draftOpacity,
    required this.draftHighlighter,
    required this.shapeStart,
    required this.shapeEnd,
    required this.shapeType,
    required this.shapeColor,
    required this.shapeWidth,
    required this.trail,
    required this.origin,
    required this.scale,
  });

  final BoardPage page;
  final String? selectedId;
  final List<Offset> draft;
  final Color draftColor;
  final double draftWidth;
  final double draftOpacity;
  final bool draftHighlighter;
  final Offset? shapeStart;
  final Offset? shapeEnd;
  final BoardShapeType shapeType;
  final Color shapeColor;
  final double shapeWidth;
  final List<_TrailPoint> trail;
  final Offset origin;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    for (final BoardStroke stroke in page.strokes) {
      _paintStroke(canvas, stroke.points, stroke.color.withValues(alpha: stroke.opacity.clamp(0, 1)), stroke.width,
          stroke.highlighter);
    }
    for (final BoardShape shape in page.shapes) {
      _paintShape(
          canvas, shape.start, shape.end, shape.type, shape.color.withValues(alpha: shape.opacity), shape.width);
    }
    for (final BoardTextObject text in page.texts) {
      _paintText(canvas, text);
    }

    if (draft.isNotEmpty) {
      _paintStroke(canvas, draft, draftColor.withValues(alpha: draftOpacity.clamp(0, 1)),
          draftHighlighter ? draftWidth * 4 : draftWidth, draftHighlighter);
    }
    if (shapeStart != null && shapeEnd != null) {
      _paintShape(canvas, shapeStart!, shapeEnd!, shapeType, shapeColor.withValues(alpha: 0.7), shapeWidth);
    }

    _paintSelection(canvas);
    _paintTrail(canvas);

    canvas.restore();
  }

  void _paintStroke(Canvas canvas, List<Offset> points, Color color, double width, bool highlighter) {
    if (points.isEmpty) return;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..isAntiAlias = true;
    if (highlighter) paint.blendMode = BlendMode.multiply;

    if (points.length == 1) {
      canvas.drawCircle(points.first, width / 2, Paint()..color = color);
      return;
    }

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length - 1; i++) {
      final Offset midpoint = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, midpoint.dx, midpoint.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  void _paintShape(Canvas canvas, Offset start, Offset end, BoardShapeType type, Color color, double width) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..isAntiAlias = true;
    final Rect rect = Rect.fromPoints(start, end);

    switch (type) {
      case BoardShapeType.line:
        canvas.drawLine(start, end, paint);
        break;
      case BoardShapeType.arrow:
        canvas.drawLine(start, end, paint);
        _paintArrowHead(canvas, start, end, paint);
        break;
      case BoardShapeType.rectangle:
        canvas.drawRect(rect, paint);
        break;
      case BoardShapeType.ellipse:
        canvas.drawOval(rect, paint);
        break;
      case BoardShapeType.triangle:
        final Path path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..lineTo(rect.left, rect.bottom)
          ..close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  void _paintArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
    final double angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const double headLength = 18;
    const double spread = 0.42;
    final Offset left = end - Offset(math.cos(angle - spread), math.sin(angle - spread)) * headLength;
    final Offset right = end - Offset(math.cos(angle + spread), math.sin(angle + spread)) * headLength;
    final Path head = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(
        head,
        Paint()
          ..color = paint.color
          ..style = PaintingStyle.fill);
  }

  void _paintText(Canvas canvas, BoardTextObject text) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text.text,
        style: TextStyle(
          color: text.color,
          fontSize: text.fontSize,
          height: 1.35,
          fontWeight: text.bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: text.width);

    painter.paint(canvas, text.position);

    if (selectedId == 't:${text.id}') {
      final Rect bounds = Rect.fromLTWH(text.position.dx, text.position.dy, painter.width, painter.height);
      _paintSelectionRect(canvas, bounds.inflate(6));
    }
  }

  void _paintSelection(Canvas canvas) {
    final String? id = selectedId;
    if (id == null || id.startsWith('t:')) return;
    final String key = id.substring(2);

    if (id.startsWith('s:')) {
      for (final BoardStroke stroke in page.strokes) {
        if (stroke.id == key) _paintSelectionRect(canvas, stroke.bounds);
      }
    } else if (id.startsWith('k:')) {
      for (final BoardShape shape in page.shapes) {
        if (shape.id == key) _paintSelectionRect(canvas, shape.bounds);
      }
    }
  }

  void _paintSelectionRect(Canvas canvas, Rect rect) {
    final Paint paint = Paint()
      ..color = const Color(0xFF1D4ED8).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
  }

  void _paintTrail(Canvas canvas) {
    final DateTime now = DateTime.now();
    for (final _TrailPoint dot in trail) {
      final int age = now.difference(dot.born).inMilliseconds;
      final double life = (1 - age / 900).clamp(0.0, 1.0);
      if (life <= 0) continue;
      canvas.drawCircle(
          dot.position, 7 * life + 2, Paint()..color = const Color(0xFFB42318).withValues(alpha: 0.55 * life));
      canvas.drawCircle(
          dot.position, 3 * life + 1, Paint()..color = const Color(0xFFB42318).withValues(alpha: 0.95 * life));
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) => true;
}
