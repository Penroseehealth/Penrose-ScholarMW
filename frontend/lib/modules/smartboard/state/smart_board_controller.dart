import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/board_models.dart';

/// Owns every piece of smart board state: pages, ink, shapes, text, tool
/// settings, viewport, undo/redo history and local persistence.
///
/// The Ask/Input panel and the canvas both talk to this one controller, so
/// expanding the panel can never reset ink, selection, page or zoom.
class SmartBoardController extends ChangeNotifier {
  static const String storageKey = 'smart_board_chemistry_v1';
  static const int _historyLimit = 60;

  final List<String> _undoStack = <String>[];
  final List<String> _redoStack = <String>[];
  final String _sessionId = DateTime.now().microsecondsSinceEpoch.toString();

  List<BoardPage> _pages = <BoardPage>[];
  int _pageIndex = 0;

  BoardTool _tool = BoardTool.pen;
  Color _color = kBoardInkColors.first;
  double _strokeWidth = 3;
  double _opacity = 1;
  double _eraserRadius = 18;
  BoardShapeType _shapeType = BoardShapeType.line;
  double _zoom = 1;
  Offset _pan = Offset.zero;
  String? _selectedId;
  bool _panelExpanded = true;

  bool _loaded = false;
  bool _dirty = false;
  bool _saving = false;
  DateTime? _savedAt;
  int _idCounter = 0;
  Timer? _autosaveTimer;

  bool get isLoaded => _loaded;
  bool get isDirty => _dirty;
  bool get isSaving => _saving;
  DateTime? get savedAt => _savedAt;
  List<BoardPage> get pages => List<BoardPage>.unmodifiable(_pages);
  int get pageIndex => _pageIndex;
  int get pageCount => _pages.length;
  BoardTool get tool => _tool;
  Color get color => _color;
  double get strokeWidth => _strokeWidth;
  double get opacity => _opacity;
  double get eraserRadius => _eraserRadius;
  BoardShapeType get shapeType => _shapeType;
  double get zoom => _zoom;
  Offset get pan => _pan;
  String? get selectedId => _selectedId;
  bool get panelExpanded => _panelExpanded;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  BoardPage get currentPage => _pages.isEmpty ? _blankPage() : _pages[_pageIndex.clamp(0, _pages.length - 1)];

  // ── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        if (decoded is Map) {
          final Object? rawPages = decoded['pages'];
          if (rawPages is List) {
            final pages = <BoardPage>[];
            for (final Object? entry in rawPages) {
              final BoardPage? page = BoardPage.fromJson(entry);
              if (page != null) pages.add(page);
            }
            if (pages.isNotEmpty) _pages = pages;
          }
          final Object? index = decoded['index'];
          if (index is num) _pageIndex = index.toInt().clamp(0, _pages.isEmpty ? 0 : _pages.length - 1);
        }
      } on FormatException {
        // Corrupt payload: fall through to a fresh demonstration board.
      }
    }
    if (_pages.isEmpty) {
      _pages = <BoardPage>[_demoPage()];
      _pageIndex = 0;
    }
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }

  BoardPage _blankPage() => BoardPage(id: _nextId('page'), title: 'Page ${_pages.length + 1}');

  BoardPage _demoPage() => BoardPage(
        id: _nextId('page'),
        title: 'Magnesium (Mg)',
        lessonId: 'magnesium',
      );

  String _nextId(String prefix) => '$prefix-${++_idCounter}-$_sessionId';

  // ── Tool settings ────────────────────────────────────────────────────────

  void setTool(BoardTool tool) {
    if (_tool == tool) return;
    _tool = tool;
    if (tool != BoardTool.select) _selectedId = null;
    notifyListeners();
  }

  void setColor(Color color) {
    _color = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  void setOpacity(double opacity) {
    _opacity = opacity;
    notifyListeners();
  }

  void setShapeType(BoardShapeType type) {
    _shapeType = type;
    _tool = BoardTool.shape;
    notifyListeners();
  }

  void setEraserRadius(double radius) {
    _eraserRadius = radius;
    notifyListeners();
  }

  void togglePanel() {
    _panelExpanded = !_panelExpanded;
    notifyListeners();
  }

  void setPanelExpanded(bool expanded) {
    if (_panelExpanded == expanded) return;
    _panelExpanded = expanded;
    notifyListeners();
  }

  // ── Viewport ─────────────────────────────────────────────────────────────

  void setZoom(double value) {
    final double clamped = value.clamp(0.5, 3);
    if (clamped == _zoom) return;
    _zoom = clamped;
    notifyListeners();
  }

  void zoomIn() => setZoom(_zoom + 0.15);
  void zoomOut() => setZoom(_zoom - 0.15);

  void resetZoom() {
    _zoom = 1;
    _pan = Offset.zero;
    notifyListeners();
  }

  void fitToBoard() => resetZoom();

  void panBy(Offset delta) {
    _pan += delta;
    notifyListeners();
  }

  // ── History ──────────────────────────────────────────────────────────────

  String _snapshot() => jsonEncode(<String, dynamic>{
        'index': _pageIndex,
        'pages': _pages.map((BoardPage page) => page.toJson()).toList(),
      });

  /// Call once at the start of a mutating gesture so the whole gesture is a
  /// single undo step.
  void pushHistory() {
    _undoStack.add(_snapshot());
    if (_undoStack.length > _historyLimit) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot());
    _restore(_undoStack.removeLast());
    _markDirty();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot());
    _restore(_redoStack.removeLast());
    _markDirty();
    notifyListeners();
  }

  void _restore(String snapshot) {
    final Object? decoded = jsonDecode(snapshot);
    if (decoded is! Map) return;
    final Object? rawPages = decoded['pages'];
    if (rawPages is List) {
      final pages = <BoardPage>[];
      for (final Object? entry in rawPages) {
        final BoardPage? page = BoardPage.fromJson(entry);
        if (page != null) pages.add(page);
      }
      if (pages.isNotEmpty) _pages = pages;
    }
    final Object? index = decoded['index'];
    if (index is num && _pages.isNotEmpty) {
      _pageIndex = index.toInt().clamp(0, _pages.length - 1);
    }
    _selectedId = null;
  }

  // ── Ink ──────────────────────────────────────────────────────────────────

  void commitStroke(List<Offset> points) {
    if (points.isEmpty) return;
    pushHistory();
    currentPage.strokes.add(
      BoardStroke(
        id: _nextId('stroke'),
        points: List<Offset>.from(points),
        color: _color,
        width: _tool == BoardTool.highlighter ? _strokeWidth * 4 : _strokeWidth,
        opacity: _tool == BoardTool.highlighter ? _opacity * 0.35 : _opacity,
        highlighter: _tool == BoardTool.highlighter,
      ),
    );
    _markDirty();
    notifyListeners();
  }

  void commitShape(BoardShapeType type, Offset start, Offset end) {
    if ((end - start).distance < 4) return;
    pushHistory();
    currentPage.shapes.add(
      BoardShape(
        id: _nextId('shape'),
        type: type,
        start: start,
        end: end,
        color: _color,
        width: _strokeWidth,
        opacity: _opacity,
      ),
    );
    _markDirty();
    notifyListeners();
  }

  BoardTextObject addText(String text, Offset at, {double width = 560, double fontSize = 22}) {
    pushHistory();
    final boardText = BoardTextObject(
      id: _nextId('text'),
      text: text,
      position: at,
      width: width,
      color: _color,
      fontSize: fontSize,
    );
    currentPage.texts.add(boardText);
    _selectedId = 't:${boardText.id}';
    _markDirty();
    notifyListeners();
    return boardText;
  }

  /// Places an AI explanation on the board as an editable text object.
  BoardTextObject addAnswerToBoard(String answer) {
    final double y = (520 + currentPage.texts.length * 40).clamp(120.0, kBoardHeight - 220).toDouble();
    return addText(answer.trim(), Offset(860, y), width: 620, fontSize: 19);
  }

  /// Partial erase: removes only the ink beneath the eraser, splitting the
  /// stroke into the remaining segments. Text and shapes under the eraser are
  /// removed whole, matching "erase object".
  bool eraseAt(Offset point, double radius) {
    final BoardPage page = currentPage;
    var changed = false;

    final strokes = <BoardStroke>[];
    for (final BoardStroke stroke in page.strokes) {
      final segments = <List<Offset>>[<Offset>[]];
      for (final Offset candidate in stroke.points) {
        if ((candidate - point).distance <= radius) {
          if (segments.last.isNotEmpty) segments.add(<Offset>[]);
        } else {
          segments.last.add(candidate);
        }
      }
      final bool untouched = segments.length == 1 && segments.first.length == stroke.points.length;
      if (untouched) {
        strokes.add(stroke);
        continue;
      }
      changed = true;
      for (final List<Offset> segment in segments) {
        if (segment.length >= 2) strokes.add(stroke.copyWith(id: _nextId('stroke'), points: segment));
      }
    }

    final texts = page.texts.toList();
    for (final BoardTextObject text in page.texts) {
      final Rect rect = _textRect(text);
      if (rect.inflate(radius * 0.4).contains(point)) {
        texts.remove(text);
        changed = true;
      }
    }

    final shapes = page.shapes.toList();
    for (final BoardShape shape in page.shapes) {
      if (shape.bounds.inflate(radius * 0.4).contains(point)) {
        shapes.remove(shape);
        changed = true;
      }
    }

    if (!changed) return false;
    _pages[_pageIndex] = page.copyWith(strokes: strokes, texts: texts, shapes: shapes);
    _markDirty();
    notifyListeners();
    return true;
  }

  Rect _textRect(BoardTextObject text) {
    final double approxHeight = (text.text.length / 34).ceil() * text.fontSize * 1.35;
    return Rect.fromLTWH(text.position.dx, text.position.dy, text.width, approxHeight);
  }

  // ── Selection ────────────────────────────────────────────────────────────

  String? hitTest(Offset point) {
    final BoardPage page = currentPage;
    for (final BoardTextObject text in page.texts.reversed) {
      if (_textRect(text).inflate(8).contains(point)) return 't:${text.id}';
    }
    for (final BoardShape shape in page.shapes.reversed) {
      if (shape.bounds.contains(point)) return 'k:${shape.id}';
    }
    for (final BoardStroke stroke in page.strokes.reversed) {
      if (stroke.bounds.contains(point)) return 's:${stroke.id}';
    }
    return null;
  }

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void translateSelected(Offset delta) {
    final String? id = _selectedId;
    if (id == null || delta == Offset.zero) return;
    final BoardPage page = currentPage;
    final List<BoardStroke> strokes = page.strokes.toList();
    final List<BoardShape> shapes = page.shapes.toList();
    final List<BoardTextObject> texts = page.texts.toList();
    var changed = false;

    if (id.startsWith('s:')) {
      final String key = id.substring(2);
      for (var i = 0; i < strokes.length; i++) {
        if (strokes[i].id == key) {
          strokes[i] = strokes[i].translated(delta);
          changed = true;
        }
      }
    } else if (id.startsWith('k:')) {
      final String key = id.substring(2);
      for (var i = 0; i < shapes.length; i++) {
        if (shapes[i].id == key) {
          shapes[i] = shapes[i].translated(delta);
          changed = true;
        }
      }
    } else if (id.startsWith('t:')) {
      final String key = id.substring(2);
      for (var i = 0; i < texts.length; i++) {
        if (texts[i].id == key) {
          texts[i] = texts[i].translated(delta);
          changed = true;
        }
      }
    }

    if (!changed) return;
    _pages[_pageIndex] = page.copyWith(strokes: strokes, shapes: shapes, texts: texts);
    _markDirty();
    notifyListeners();
  }

  void deleteSelected() {
    final String? id = _selectedId;
    if (id == null) return;
    final BoardPage page = currentPage;
    final String key = id.substring(2);
    pushHistory();
    _pages[_pageIndex] = page.copyWith(
      strokes: page.strokes.where((BoardStroke stroke) => stroke.id != key).toList(),
      shapes: page.shapes.where((BoardShape shape) => shape.id != key).toList(),
      texts: page.texts.where((BoardTextObject text) => text.id != key).toList(),
    );
    _selectedId = null;
    _markDirty();
    notifyListeners();
  }

  void updateText(String id, String value) {
    final BoardPage page = currentPage;
    final List<BoardTextObject> texts = page.texts.toList();
    for (var i = 0; i < texts.length; i++) {
      if (texts[i].id == id) {
        pushHistory();
        texts[i] = texts[i].copyWith(text: value);
        _pages[_pageIndex] = page.copyWith(texts: texts);
        _markDirty();
        notifyListeners();
        return;
      }
    }
  }

  // ── Clearing ─────────────────────────────────────────────────────────────

  void clearInk() {
    final BoardPage page = currentPage;
    if (page.strokes.isEmpty && page.shapes.isEmpty) return;
    pushHistory();
    _pages[_pageIndex] = page.copyWith(
      strokes: <BoardStroke>[],
      shapes: <BoardShape>[],
      texts: page.texts,
    );
    _selectedId = null;
    _markDirty();
    notifyListeners();
  }

  void clearPage() {
    final BoardPage page = currentPage;
    pushHistory();
    _pages[_pageIndex] = BoardPage(id: page.id, title: page.title, lessonId: '');
    _selectedId = null;
    _markDirty();
    notifyListeners();
  }

  // ── Pages ────────────────────────────────────────────────────────────────

  void goToPage(int index) {
    if (_pages.isEmpty) return;
    final int next = index.clamp(0, _pages.length - 1);
    if (next == _pageIndex) return;
    _pageIndex = next;
    _selectedId = null;
    _markDirty();
    notifyListeners();
  }

  void previousPage() => goToPage(_pageIndex - 1);
  void nextPage() => goToPage(_pageIndex + 1);

  void addPage() {
    pushHistory();
    _pages.add(BoardPage(id: _nextId('page'), title: 'Page ${_pages.length + 1}'));
    _pageIndex = _pages.length - 1;
    _selectedId = null;
    _markDirty();
    notifyListeners();
  }

  void duplicatePage() {
    pushHistory();
    final BoardPage copy = currentPage.copyWith(id: _nextId('page'), title: '${currentPage.title} (copy)');
    _pages.insert(_pageIndex + 1, copy);
    _pageIndex += 1;
    _selectedId = null;
    _markDirty();
    notifyListeners();
  }

  void deletePage() {
    if (_pages.length <= 1) {
      clearPage();
      return;
    }
    pushHistory();
    _pages.removeAt(_pageIndex);
    _pageIndex = _pageIndex.clamp(0, _pages.length - 1);
    _selectedId = null;
    _markDirty();
    notifyListeners();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  void _markDirty() {
    _dirty = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () {
      unawaited(save());
    });
  }

  Future<void> save() async {
    _saving = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(<String, dynamic>{
        'index': _pageIndex,
        'pages': _pages.map((BoardPage page) => page.toJson()).toList(),
      }),
    );
    _dirty = false;
    _saving = false;
    _savedAt = DateTime.now();
    notifyListeners();
  }
}
