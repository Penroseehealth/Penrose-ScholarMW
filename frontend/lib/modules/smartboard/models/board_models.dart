import 'dart:ui';

/// Interaction tools offered by the smart board.
enum BoardTool { select, pen, highlighter, eraser, pointer, shape, text }

/// Shapes the board can draw with the shape tool.
enum BoardShapeType { line, arrow, rectangle, ellipse, triangle }

/// Logical board coordinate space. Every stored point lives in this space so
/// ink keeps its alignment across resizes, zoom changes and relayouts.
const double kBoardWidth = 1600;
const double kBoardHeight = 900;

/// Restrained classroom palette: board ink, never neon.
const List<Color> kBoardInkColors = <Color>[
  Color(0xFF12294A), // navy (default)
  Color(0xFF1D4ED8), // blue
  Color(0xFFB42318), // red emphasis
  Color(0xFF15803D), // green
  Color(0xFFB45309), // amber emphasis
  Color(0xFF4B5563), // graphite
];

double _doubleFrom(Object? value, double fallback) => value is num ? value.toDouble() : fallback;

int _intFrom(Object? value, int fallback) => value is num ? value.toInt() : fallback;

String _stringFrom(Object? value, String fallback) => value is String ? value : fallback;

/// A freehand ink stroke, stored in logical board coordinates.
class BoardStroke {
  BoardStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
    required this.opacity,
    this.highlighter = false,
  });

  final String id;
  final List<Offset> points;
  final Color color;
  final double width;
  final double opacity;
  final bool highlighter;

  Rect get bounds {
    if (points.isEmpty) return Rect.zero;
    var minX = points.first.dx;
    var minY = points.first.dy;
    var maxX = points.first.dx;
    var maxY = points.first.dy;
    for (final point in points) {
      if (point.dx < minX) minX = point.dx;
      if (point.dx > maxX) maxX = point.dx;
      if (point.dy < minY) minY = point.dy;
      if (point.dy > maxY) maxY = point.dy;
    }
    final pad = (highlighter ? width * 2 : width) + 4;
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(pad);
  }

  BoardStroke copyWith({String? id, List<Offset>? points}) => BoardStroke(
        id: id ?? this.id,
        points: points ?? this.points,
        color: color,
        width: width,
        opacity: opacity,
        highlighter: highlighter,
      );

  BoardStroke translated(Offset delta) =>
      copyWith(points: points.map((Offset point) => point + delta).toList(growable: false));

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'points': points.expand((Offset point) => <double>[point.dx, point.dy]).toList(),
        'color': color.toARGB32(),
        'width': width,
        'opacity': opacity,
        'highlighter': highlighter,
      };

  static BoardStroke? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Object? rawPoints = raw['points'];
    if (rawPoints is! List) return null;
    final points = <Offset>[];
    for (var i = 0; i + 1 < rawPoints.length; i += 2) {
      final Object? x = rawPoints[i];
      final Object? y = rawPoints[i + 1];
      if (x is num && y is num) points.add(Offset(x.toDouble(), y.toDouble()));
    }
    if (points.isEmpty) return null;
    return BoardStroke(
      id: _stringFrom(raw['id'], 'stroke'),
      points: points,
      color: Color(_intFrom(raw['color'], 0xFF12294A)),
      width: _doubleFrom(raw['width'], 3),
      opacity: _doubleFrom(raw['opacity'], 1),
      highlighter: raw['highlighter'] == true,
    );
  }
}

/// A geometric shape placed with the shape tool.
class BoardShape {
  BoardShape({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.color,
    required this.width,
    required this.opacity,
  });

  final String id;
  final BoardShapeType type;
  final Offset start;
  final Offset end;
  final Color color;
  final double width;
  final double opacity;

  Rect get bounds => Rect.fromPoints(start, end).inflate(width + 6);

  BoardShape copyWith({Offset? start, Offset? end}) => BoardShape(
        id: id,
        type: type,
        start: start ?? this.start,
        end: end ?? this.end,
        color: color,
        width: width,
        opacity: opacity,
      );

  BoardShape translated(Offset delta) => copyWith(start: start + delta, end: end + delta);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'sx': start.dx,
        'sy': start.dy,
        'ex': end.dx,
        'ey': end.dy,
        'color': color.toARGB32(),
        'width': width,
        'opacity': opacity,
      };

  static BoardShape? fromJson(Object? raw) {
    if (raw is! Map) return null;
    BoardShapeType? type;
    for (final BoardShapeType candidate in BoardShapeType.values) {
      if (candidate.name == raw['type']) type = candidate;
    }
    if (type == null) return null;
    return BoardShape(
      id: _stringFrom(raw['id'], 'shape'),
      type: type,
      start: Offset(_doubleFrom(raw['sx'], 0), _doubleFrom(raw['sy'], 0)),
      end: Offset(_doubleFrom(raw['ex'], 0), _doubleFrom(raw['ey'], 0)),
      color: Color(_intFrom(raw['color'], 0xFF12294A)),
      width: _doubleFrom(raw['width'], 3),
      opacity: _doubleFrom(raw['opacity'], 1),
    );
  }
}

/// An editable text block — used for typed notes and AI answers written to the board.
class BoardTextObject {
  BoardTextObject({
    required this.id,
    required this.text,
    required this.position,
    required this.width,
    required this.color,
    this.fontSize = 22,
    this.bold = false,
  });

  final String id;
  final String text;
  final Offset position;
  final double width;
  final Color color;
  final double fontSize;
  final bool bold;

  BoardTextObject copyWith({String? text, Offset? position, double? width, double? fontSize, Color? color}) =>
      BoardTextObject(
        id: id,
        text: text ?? this.text,
        position: position ?? this.position,
        width: width ?? this.width,
        color: color ?? this.color,
        fontSize: fontSize ?? this.fontSize,
        bold: bold,
      );

  BoardTextObject translated(Offset delta) => copyWith(position: position + delta);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'x': position.dx,
        'y': position.dy,
        'width': width,
        'color': color.toARGB32(),
        'fontSize': fontSize,
        'bold': bold,
      };

  static BoardTextObject? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final String text = _stringFrom(raw['text'], '');
    if (text.isEmpty) return null;
    return BoardTextObject(
      id: _stringFrom(raw['id'], 'text'),
      text: text,
      position: Offset(_doubleFrom(raw['x'], 0), _doubleFrom(raw['y'], 0)),
      width: _doubleFrom(raw['width'], 560),
      color: Color(_intFrom(raw['color'], 0xFF12294A)),
      fontSize: _doubleFrom(raw['fontSize'], 22),
      bold: raw['bold'] == true,
    );
  }
}

/// One board page. Each page owns its ink, shapes, text and lesson context.
class BoardPage {
  BoardPage({
    required this.id,
    required this.title,
    this.lessonId = '',
    List<BoardStroke>? strokes,
    List<BoardShape>? shapes,
    List<BoardTextObject>? texts,
  })  : strokes = strokes ?? <BoardStroke>[],
        shapes = shapes ?? <BoardShape>[],
        texts = texts ?? <BoardTextObject>[];

  final String id;
  final String title;
  final String lessonId;
  final List<BoardStroke> strokes;
  final List<BoardShape> shapes;
  final List<BoardTextObject> texts;

  bool get isEmpty => strokes.isEmpty && shapes.isEmpty && texts.isEmpty;

  BoardPage copyWith({
    String? id,
    String? title,
    String? lessonId,
    List<BoardStroke>? strokes,
    List<BoardShape>? shapes,
    List<BoardTextObject>? texts,
  }) =>
      BoardPage(
        id: id ?? this.id,
        title: title ?? this.title,
        lessonId: lessonId ?? this.lessonId,
        strokes: strokes ?? List<BoardStroke>.from(this.strokes),
        shapes: shapes ?? List<BoardShape>.from(this.shapes),
        texts: texts ?? List<BoardTextObject>.from(this.texts),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'lessonId': lessonId,
        'strokes': strokes.map((BoardStroke stroke) => stroke.toJson()).toList(),
        'shapes': shapes.map((BoardShape shape) => shape.toJson()).toList(),
        'texts': texts.map((BoardTextObject text) => text.toJson()).toList(),
      };

  static BoardPage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final strokes = <BoardStroke>[];
    final Object? rawStrokes = raw['strokes'];
    if (rawStrokes is List) {
      for (final Object? entry in rawStrokes) {
        final BoardStroke? stroke = BoardStroke.fromJson(entry);
        if (stroke != null) strokes.add(stroke);
      }
    }
    final shapes = <BoardShape>[];
    final Object? rawShapes = raw['shapes'];
    if (rawShapes is List) {
      for (final Object? entry in rawShapes) {
        final BoardShape? shape = BoardShape.fromJson(entry);
        if (shape != null) shapes.add(shape);
      }
    }
    final texts = <BoardTextObject>[];
    final Object? rawTexts = raw['texts'];
    if (rawTexts is List) {
      for (final Object? entry in rawTexts) {
        final BoardTextObject? text = BoardTextObject.fromJson(entry);
        if (text != null) texts.add(text);
      }
    }
    return BoardPage(
      id: _stringFrom(raw['id'], 'page'),
      title: _stringFrom(raw['title'], 'Page'),
      lessonId: _stringFrom(raw['lessonId'], ''),
      strokes: strokes,
      shapes: shapes,
      texts: texts,
    );
  }
}
