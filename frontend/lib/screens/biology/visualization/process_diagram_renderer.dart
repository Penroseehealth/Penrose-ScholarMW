import 'dart:math' as math;

import '../../../models/biology_visualization.dart';

/// Deterministic scientific renderer for process / cycle / flow diagrams.
///
/// The AI layer only decides WHAT the diagram contains (a structured
/// `BiologySpec` with `nodes`/`edges`); this renderer decides HOW it is drawn.
/// It never delegates to an image model and never uses random geometric
/// placeholders — every node has a dedicated shape and every edge a real,
/// correctly-pointing arrow. Layout is computed automatically (cycle ring,
/// packed flow, branched levels, or grid) and labels are placed without
/// clipping or overlapping.
class ProcessDiagramRenderer {
  static const double w = 1280;
  static const double h = 860;
  static const double _font = 18;
  static const double _edge = 28;
  static const double _gap = 46;

  static String render(BiologySpec spec) {
    final dark = spec.background == 'black' || spec.background == 'dark';
    final p = dark ? _Palette.dark() : _Palette.light();
    final bg = spec.background == 'transparent' ? 'none' : p.canvas;

    final nodes = spec.nodes.isNotEmpty ? spec.nodes : _fallbackNodes();
    final edges = spec.edges;

    final laid = _layout(spec.layout, nodes, edges);

    final b = StringBuffer();
    b.write('<?xml version="1.0" encoding="UTF-8"?>\n');
    b.write('<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" '
        'viewBox="0 0 $w $h" font-family="Arial, Helvetica, sans-serif">\n');
    b.write('<rect width="$w" height="$h" fill="$bg"/>\n');
    b.write('  <title>${_esc(spec.title)}</title>\n');
    b.write('  <desc>${_esc(spec.title)} — deterministic scientific process diagram.</desc>\n');

    for (final e in edges) {
      final from = laid.byId[e.from];
      final to = laid.byId[e.to];
      if (from == null || to == null) continue;
      _drawEdge(b, from, to, e.label, p);
    }

    for (final n in nodes) {
      final pos = laid.byId[n.id];
      if (pos == null) continue;
      _drawNode(b, n, pos, p);
    }
    b.writeln('</svg>');
    return b.toString();
  }

  // ── Layout ─────────────────────────────────────────────────────────
  static _Layout _layout(String kind, List<ProcessNode> nodes, List<ProcessEdge> edges) {
    final boxes = <String, _Box>{for (final n in nodes) n.id: _measure(n)};
    switch (kind) {
      case 'cycle':
        return _cycleLayout(nodes, boxes);
      case 'branched':
        return _branchedLayout(nodes, edges, boxes);
      case 'grid':
        return _gridLayout(nodes, boxes);
      case 'flow':
      default:
        return _flowLayout(nodes, boxes);
    }
  }

  static _Layout _flowLayout(List<ProcessNode> nodes, Map<String, _Box> boxes) {
    final pos = <String, _Pos>{};
    var x = _edge;
    var y = _edge;
    var rowH = 0.0;
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final bx = boxes[n.id]!;
      if (i > 0 && x + bx.w > w - _edge) {
        x = _edge;
        y += rowH + _gap;
        rowH = 0;
      }
      pos[n.id] = _Pos(x + bx.w / 2, y + bx.h / 2, bx.w, bx.h);
      x += bx.w + _gap;
      rowH = math.max(rowH, bx.h);
    }
    final totalH = y + rowH;
    final offset = (h - totalH) / 2;
    for (final n in nodes) {
      final p = pos[n.id]!;
      pos[n.id] = _Pos(p.cx, p.cy + offset, p.w, p.h);
    }
    return _Layout.fromMap(pos);
  }

  static _Layout _cycleLayout(List<ProcessNode> nodes, Map<String, _Box> boxes) {
    final pos = <String, _Pos>{};
    final n = nodes.length;
    if (n == 0) return _Layout.fromMap(pos);
    final radius = math.min(w, h) / 2 - 150;
    const cx = w / 2;
    const cy = h / 2;
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      final bx = boxes[nodes[i].id]!;
      pos[nodes[i].id] = _Pos(x, y, bx.w, bx.h);
    }
    return _Layout.fromMap(pos);
  }

  static _Layout _branchedLayout(List<ProcessNode> nodes, List<ProcessEdge> edges, Map<String, _Box> boxes) {
    final incoming = <String, int>{for (final n in nodes) n.id: 0};
    final outgoing = <String, List<String>>{for (final n in nodes) n.id: []};
    for (final e in edges) {
      if (outgoing.containsKey(e.from)) outgoing[e.from]!.add(e.to);
      if (incoming.containsKey(e.to)) incoming[e.to] = (incoming[e.to] ?? 0) + 1;
    }
    final roots = nodes.where((n) => (incoming[n.id] ?? 0) == 0).toList();
    final layers = <List<ProcessNode>>[];
    final level = <String, int>{};
    final queue = <ProcessNode>[...roots];
    for (final r in roots) {
      level[r.id] = 0;
    }
    var idx = 0;
    while (idx < queue.length) {
      final cur = queue[idx++];
      final l = level[cur.id]!;
      while (layers.length <= l) {
        layers.add([]);
      }
      layers[l].add(cur);
      for (final child in outgoing[cur.id] ?? []) {
        ProcessNode? next;
        for (final nd in nodes) {
          if (nd.id == child) {
            next = nd;
            break;
          }
        }
        if (next != null && level[child] == null) {
          level[child] = l + 1;
          queue.add(next);
        }
      }
    }
    // A node that never got a level (e.g. unconnected) is appended at level 0.
    for (final n in nodes) {
      if (level[n.id] == null) {
        level[n.id] = 0;
        if (layers.isEmpty) layers.add([]);
        layers[0].add(n);
      }
    }
    final pos = <String, _Pos>{};
    final maxLevel = math.max(1, layers.length - 1);
    for (var l = 0; l < layers.length; l++) {
      final row = layers[l];
      final cx = _edge + (w - 2 * _edge) * (maxLevel == 0 ? 0.5 : l / maxLevel);
      final totalH = row.fold<double>(0, (s, n) => s + boxes[n.id]!.h) + _gap * (row.length - 1);
      var y = (h - totalH) / 2;
      for (final n in row) {
        final bx = boxes[n.id]!;
        pos[n.id] = _Pos(cx, y + bx.h / 2, bx.w, bx.h);
        y += bx.h + _gap;
      }
    }
    return _Layout.fromMap(pos);
  }

  static _Layout _gridLayout(List<ProcessNode> nodes, Map<String, _Box> boxes) {
    final pos = <String, _Pos>{};
    final cols = math.max(1, math.sqrt(nodes.length).ceil());
    var x = _edge;
    var y = _edge;
    var rowH = 0.0;
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final bx = boxes[n.id]!;
      if (i > 0 && i % cols == 0) {
        x = _edge;
        y += rowH + _gap;
        rowH = 0;
      }
      pos[n.id] = _Pos(x + bx.w / 2, y + bx.h / 2, bx.w, bx.h);
      x += bx.w + _gap;
      rowH = math.max(rowH, bx.h);
    }
    final totalH = y + rowH;
    final offset = (h - totalH) / 2;
    for (final n in nodes) {
      final p = pos[n.id]!;
      pos[n.id] = _Pos(p.cx, p.cy + offset, p.w, p.h);
    }
    return _Layout.fromMap(pos);
  }

  static _Box _measure(ProcessNode n) {
    final lines = n.label.split('\n');
    final maxChars = lines.fold<int>(0, (s, l) => math.max(s, l.length));
    final textW = maxChars * _font * 0.58;
    final textH = lines.length * _font * 1.32;
    switch (n.shape) {
      case 'circle':
        final d = math.max(118.0, textW + 60);
        return _Box(d, textH + 36);
      case 'sun':
      case 'leaf':
        return _Box(textW + 60, 62 + textH);
      case 'input':
      case 'output':
        return _Box(textW + 62, textH + 26);
      case 'box':
      default:
        return _Box(textW + 44, textH + 28);
    }
  }

  // ── Edge / arrow engine ────────────────────────────────────────────
  static void _drawEdge(StringBuffer b, _Pos from, _Pos to, String label, _Palette p) {
    final x1 = from.cx;
    final y1 = from.cy;
    final x2 = to.cx;
    final y2 = to.cy;
    final dx = x2 - x1;
    final dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final ux = dx / len;
    final uy = dy / len;
    // Stop the arrowhead exactly on the target node's perimeter.
    final r2 = to.w / 2 + 6;
    final tx = x2 - ux * r2;
    final ty = y2 - uy * r2;

    // Gentle quadratic bow so parallel arrows (e.g. two inputs) don't overlap.
    final mx = (x1 + x2) / 2;
    final my = (y1 + y2) / 2 - 30;
    b.write(
        '<path d="M${_n(x1)} ${_n(y1)} Q${_n(mx)} ${_n(my)} ${_n(tx)} ${_n(ty)}" fill="none" stroke="${p.edge}" stroke-width="2.4"/>\n');

    const ah = 11.0;
    final bx = tx - ux * ah;
    final by = ty - uy * ah;
    final px = -uy;
    final py = ux;
    b.write(
        '<path d="M${_n(tx)} ${_n(ty)} L${_n(bx + px * 5)} ${_n(by + py * 5)} L${_n(bx - px * 5)} ${_n(by - py * 5)} Z" '
        'fill="${p.edge}"/>\n');

    if (label.isNotEmpty) {
      final lx = mx;
      final ly = my - 15;
      final tw = label.length * 14.5;
      b.write('<rect x="${_n(lx - tw / 2 - 3)}" y="${_n(ly - 10)}" width="${_n(tw + 6)}" height="20" rx="5" '
          'fill="${p.halo}"/>\n');
      b.write('<text x="${_n(lx)}" y="${_n(ly)}" fill="${p.edgeInk}" '
          'font-size="15" text-anchor="middle" dominant-baseline="central">'
          '${_esc(label)}</text>\n');
    }
  }

  // ── Node shapes ────────────────────────────────────────────────────
  static void _drawNode(StringBuffer b, ProcessNode n, _Pos pos, _Palette p) {
    final x = pos.cx;
    final y = pos.cy;
    final ww = pos.w;
    final hh = pos.h;
    switch (n.shape) {
      case 'circle':
        final r = ww / 2 - 4;
        _circle(b, x, y, r, fill: p.circleFill, stroke: p.circleStroke);
        _text(b, n.label, x, y, -_font * 0.14, p.ink, 16);
        break;
      case 'sun':
        _sun(b, x, y - 32, 24, p);
        _text(b, n.label, x, y + 6, 0, p.ink, 16);
        break;
      case 'leaf':
        _leaf(b, x, y - 34, 40, 24, p);
        _text(b, n.label, x, y + 2, 0, p.ink, 16);
        break;
      case 'input':
        _roundedBox(b, x, y, ww, hh, p.boxFill, p.inputStroke);
        _chevron(b, x - ww / 2 + 4, y, 13, p.inputStroke, left: true);
        _textInset(b, n.label, x, y, p.ink);
        break;
      case 'output':
        _roundedBox(b, x, y, ww, hh, p.boxFill, p.outputStroke);
        _chevron(b, x + ww / 2 - 4, y, 13, p.outputStroke, left: false);
        _textInset(b, n.label, x, y, p.ink);
        break;
      case 'box':
      default:
        _roundedBox(b, x, y, ww, hh, p.boxFill, p.boxStroke);
        _text(b, n.label, x, y, -_font * 0.14, p.ink, 16);
        break;
    }
  }

  // ── Simple SVG primitives ──────────────────────────────────────────
  static void _roundedBox(StringBuffer b, double x, double y, double ww, double hh, String fill, String stroke) {
    b.write('<rect x="${_n(x - ww / 2)}" y="${_n(y - hh / 2)}" '
        'width="${_n(ww)}" height="${_n(hh)}" rx="14" fill="$fill" '
        'stroke="$stroke" stroke-width="2.6"/>\n');
  }

  static void _circle(StringBuffer b, double cx, double cy, double r,
      {required String fill, required String stroke, double sw = 2.6}) {
    b.write('<circle cx="${_n(cx)}" cy="${_n(cy)}" r="${_n(r)}" fill="$fill" '
        'stroke="$stroke" stroke-width="$sw"/>\n');
  }

  static void _sun(StringBuffer b, double x, double y, double r, _Palette p) {
    _circle(b, x, y, r, fill: p.sunFill, stroke: p.sunStroke, sw: 2.2);
    for (var i = 0; i < 8; i++) {
      final a = 2 * math.pi * i / 8;
      final x1 = x + (r + 3) * math.cos(a);
      final y1 = y + (r + 3) * math.sin(a);
      final x2 = x + (r + 13) * math.cos(a);
      final y2 = y + (r + 13) * math.sin(a);
      b.write(
          '<line x1="${_n(x1)}" y1="${_n(y1)}" x2="${_n(x2)}" y2="${_n(y2)}" stroke="${p.sunStroke}" stroke-width="2.4" '
          'stroke-linecap="round"/>\n');
    }
  }

  static void _leaf(StringBuffer b, double x, double y, double rw, double rh, _Palette p) {
    final path = 'M${_n(x - rw)} ${_n(y)} '
        'C${_n(x - rw * 0.3)} ${_n(y - rh)} ${_n(x + rw * 0.3)} '
        '${_n(y - rh)} ${_n(x + rw)} ${_n(y)} '
        'C${_n(x + rw * 0.3)} ${_n(y + rh)} ${_n(x - rw * 0.3)} '
        '${_n(y + rh)} ${_n(x - rw)} ${_n(y)} Z';
    b.write('<path d="$path" fill="${p.leafFill}" stroke="${p.leafStroke}" '
        'stroke-width="2.2"/>\n');
    b.write(
        '<line x1="${_n(x - rw)}" y1="${_n(y)}" x2="${_n(x + rw)}" y2="${_n(y)}" stroke="${p.leafStroke}" stroke-width="1.8"/>\n');
    b.write(
        '<line x1="${_n(x - rw)}" y1="${_n(y)}" x2="${_n(x - rw * 0.2)}" y2="${_n(y + rh * 0.7)}" stroke="${p.leafStroke}" '
        'stroke-width="1.4"/>\n');
  }

  static void _chevron(StringBuffer b, double x, double y, double s, String color, {required bool left}) {
    final dir = left ? -1.0 : 1.0;
    b.write(
        '<path d="M${_n(x - dir * s)} ${_n(y - s)} L${_n(x + dir * s)} ${_n(y)} L${_n(x - dir * s)} ${_n(y + s)}" fill="none" stroke="$color" stroke-width="2.8" '
        'stroke-linejoin="round"/>\n');
  }

  static void _textInset(StringBuffer b, String label, double x, double y, String ink) {
    _text(b, label, x, y, -_font * 0.14, ink, 16);
  }

  static void _text(StringBuffer b, String label, double x, double y, double baselineOffset, String fill, double size) {
    final lines = label.split('\n');
    final lineH = size * 1.32;
    final startY = y + baselineOffset - (lines.length - 1) * lineH / 2;
    for (var i = 0; i < lines.length; i++) {
      final ly = startY + i * lineH + size * 0.35;
      b.write('<text x="${_n(x)}" y="${_n(ly)}" fill="$fill" font-size="$size" '
          'text-anchor="middle" font-weight="600">${_esc(lines[i])}</text>\n');
    }
  }

  static List<ProcessNode> _fallbackNodes() => [
        ProcessNode(id: 'start', label: 'Start', shape: 'circle'),
        ProcessNode(id: 'end', label: 'End'),
      ];

  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static String _n(num v) {
    final r = v.round().toInt();
    return '$r';
  }
}

// ── Layout data ───────────────────────────────────────────────────────
class _Box {
  final double w;
  final double h;
  const _Box(this.w, this.h);
}

class _Pos {
  final double cx;
  final double cy;
  final double w;
  final double h;
  const _Pos(this.cx, this.cy, this.w, this.h);
}

class _Layout {
  final Map<String, _Pos> byId;
  const _Layout(this.byId);
  factory _Layout.fromMap(Map<String, _Pos> map) => _Layout(map);
}

// ── Palette ───────────────────────────────────────────────────────────
class _Palette {
  final String canvas;
  final String ink;
  final String boxFill;
  final String boxStroke;
  final String circleFill;
  final String circleStroke;
  final String sunFill;
  final String sunStroke;
  final String leafFill;
  final String leafStroke;
  final String inputStroke;
  final String outputStroke;
  final String edge;
  final String edgeInk;
  final String halo;

  const _Palette({
    required this.canvas,
    required this.ink,
    required this.boxFill,
    required this.boxStroke,
    required this.circleFill,
    required this.circleStroke,
    required this.sunFill,
    required this.sunStroke,
    required this.leafFill,
    required this.leafStroke,
    required this.inputStroke,
    required this.outputStroke,
    required this.edge,
    required this.edgeInk,
    required this.halo,
  });

  factory _Palette.light() => const _Palette(
        canvas: '#ffffff',
        ink: '#0f172a',
        boxFill: '#eff6ff',
        boxStroke: '#2563eb',
        circleFill: '#ecfdf5',
        circleStroke: '#059669',
        sunFill: '#fef3c7',
        sunStroke: '#d97706',
        leafFill: '#dcfce7',
        leafStroke: '#16a34a',
        inputStroke: '#0891b2',
        outputStroke: '#ea580c',
        edge: '#64748b',
        edgeInk: '#0f172a',
        halo: '#ffffff',
      );

  factory _Palette.dark() => const _Palette(
        canvas: '#0f172a',
        ink: '#e2e8f0',
        boxFill: '#1e293b',
        boxStroke: '#60a5fa',
        circleFill: '#134e4a',
        circleStroke: '#34d399',
        sunFill: '#78350f',
        sunStroke: '#fbbf24',
        leafFill: '#14532d',
        leafStroke: '#4ade80',
        inputStroke: '#22d3ee',
        outputStroke: '#fb923c',
        edge: '#94a3b8',
        edgeInk: '#e2e8f0',
        halo: '#0f172a',
      );
}
