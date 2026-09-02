import 'dart:convert';

import 'dart:math' as math;

import '../../../models/biology_visualization.dart';

/// A label anchor: org-anchor point (px,py) on the organelle plus the initial
/// text start (lx,ly).
typedef _Anchor = ({double px, double py, double lx, double ly});

/// An axis-aligned bounding box for a placed label (screen space).
class _Box {
  double x;
  double y;
  final double w;
  final double h;

  _Box(this.x, this.y, this.w, this.h);

  bool get isOutside => x < 0 || y < 0 || x + w > CellDiagramRenderer.w || y + h > CellDiagramRenderer.h;

  double get cx => x + w / 2;
  double get cy => y + h / 2;

  bool overlaps(_Box other) =>
      !(other.x >= x + w || other.x + other.w <= x || other.y >= y + h || other.y + other.h <= y);
}

/// A resolved label ready to draw.
class _PlacedLabel {
  final String text;
  final String key;
  final double ax;
  final double ay;
  _Box box;

  _PlacedLabel(this.text, this.key, this.ax, this.ay, this.box);
}

/// Coordinated, restrained color palette. Every colour is named by semantic
/// role so the diagram stays cohesive across light/dark backgrounds.
class _Palette {
  final String bg;
  final String canvas; // canvas bg fill
  final String line; // base stroking ink
  final String wallFill;
  final String wallStroke;
  final String wallDashed;
  final String membrane;
  final String cytoplasmFill;
  final String nucleusFill;
  final String nucleusStroke;
  final String nucleolus;
  final String membranePore;
  final String mitochondriaFill;
  final String mitochondriaStroke;
  final String cristae;
  final String chloroplastFill;
  final String chloroplastStroke;
  final String stroma;
  final String grana;
  final String erStroke;
  final String erRibosome;
  final String golgiStroke;
  final String golgiVesicle;
  final String vacuoleFill;
  final String vacuoleStroke;
  final String vacuoleInner;
  final String ribosome;
  final String lysosomeFill;
  final String lysosomeStroke;
  final String centriole;
  final String capsuleStroke;
  final String capsuleFill;
  final String nucleoid;
  final String plasmid;
  final String pili;
  final String flagellum;
  final String labelInk;
  final String labelMuted;
  final String leader;

  _Palette.light()
      : bg = '#ffffff',
        canvas = '#ffffff',
        line = '#1e293b',
        wallFill = '#dcfce7',
        wallStroke = '#16a34a',
        wallDashed = '#94a3b8',
        membrane = '#334155',
        cytoplasmFill = '#f8fafc',
        nucleusFill = '#ede9fe',
        nucleusStroke = '#7c3aed',
        nucleolus = '#7c3aed',
        membranePore = '#a78bfa',
        mitochondriaFill = '#fed7aa',
        mitochondriaStroke = '#ea580c',
        cristae = '#c2410c',
        chloroplastFill = '#bbf7d0',
        chloroplastStroke = '#16a34a',
        stroma = '#86efac',
        grana = '#15803d',
        erStroke = '#9333ea',
        erRibosome = '#d97706',
        golgiStroke = '#0891b2',
        golgiVesicle = '#0e7490',
        vacuoleFill = '#dbeafe',
        vacuoleStroke = '#2563eb',
        vacuoleInner = '#93c5fd',
        ribosome = '#f59e0b',
        lysosomeFill = '#fecaca',
        lysosomeStroke = '#dc2626',
        centriole = '#475569',
        capsuleStroke = '#94a3b8',
        capsuleFill = '#f1f5f9',
        nucleoid = '#c2410c',
        plasmid = '#0284c7',
        pili = '#64748b',
        flagellum = '#475569',
        labelInk = '#0f172a',
        labelMuted = '#64748b',
        leader = '#64748b';

  _Palette.dark()
      : bg = '#0b1020',
        canvas = '#0b1020',
        line = '#e2e8f0',
        wallFill = '#14532d',
        wallStroke = '#22c55e',
        wallDashed = '#64748b',
        membrane = '#cbd5e1',
        cytoplasmFill = '#0f172a',
        nucleusFill = '#3b2a66',
        nucleusStroke = '#a78bfa',
        nucleolus = '#c4b5fd',
        membranePore = '#8b5cf6',
        mitochondriaFill = '#4a2c12',
        mitochondriaStroke = '#fb923c',
        cristae = '#fdba74',
        chloroplastFill = '#14532d',
        chloroplastStroke = '#4ade80',
        stroma = '#166534',
        grana = '#86efac',
        erStroke = '#c4b5fd',
        erRibosome = '#fbbf24',
        golgiStroke = '#67e8f9',
        golgiVesicle = '#22d3ee',
        vacuoleFill = '#1e3a8a',
        vacuoleStroke = '#60a5fa',
        vacuoleInner = '#3b82f6',
        ribosome = '#fbbf24',
        lysosomeFill = '#7f1d1d',
        lysosomeStroke = '#f87171',
        centriole = '#94a3b8',
        capsuleStroke = '#94a3b8',
        capsuleFill = '#1e293b',
        nucleoid = '#fdba74',
        plasmid = '#38bdf8',
        pili = '#94a3b8',
        flagellum = '#cbd5e1',
        labelInk = '#e2e8f0',
        labelMuted = '#94a3b8',
        leader = '#94a3b8';
}

/// Deterministic SVG renderer for Cell Biology diagrams.
///
/// Implements the Penrose-style educational-illustration standards:
///   * scientifically accurate organelle morphology (envelope/nucleolus/nuclear
///     pores, inner + outer mitochondrial membranes with cristae, chloroplast
///     grana, golgi cisternae + budding vesicles, rough vs smooth ER, tonic
///     vacuole);
///   * spatial-relationship-correct layout that keeps organelles within the
///     cell boundary and promotes placement relative to the nucleus;
///   * a labelling engine with collision detection, automatic repositioning,
///     and a no-clipping constraint (labels are dropped if they cannot fit);
///   * restrained, coordinated colours and a clear typographic hierarchy.
class CellDiagramRenderer {
  static const double w = 1280;
  static const double h = 860;
  static const double _labelFont = 17;
  static const double _labelPad = 7;

  // Margin that leader anchors / labels must respect from the canvas edge.
  static const double _edge = 18;

  static String render(BiologySpec spec) {
    final dark = spec.background == 'black' || spec.background == 'dark';
    final p = dark ? _Palette.dark() : _Palette.light();
    final bg = spec.background == 'transparent' ? 'none' : p.canvas;

    final b = StringBuffer();
    b.write('<?xml version="1.0" encoding="UTF-8"?>\n');
    b.write('<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" '
        'viewBox="0 0 $w $h" font-family="Arial, Helvetica, sans-serif">\n');
    b.write('<rect width="$w" height="$h" fill="$bg"/>\n');
    b.write('  <title>${_esc(spec.title)}</title>\n');

    final present = <String>{
      for (final s in spec.structures)
        if (s.present) s.id,
    };

    switch (spec.app) {
      case 'bacterial_cell':
        _drawBacterialCell(b, present, p);
        break;
      case 'animal_cell':
        _drawAnimalCell(b, present, p);
        break;
      case 'fungal_cell':
        _drawFungalCell(b, present, p);
        break;
      case 'plant_cell':
      default:
        _drawPlantCell(b, present, p);
        break;
    }

    if (spec.labelsShown && spec.labels.isNotEmpty) {
      _drawLabels(b, spec, present, p);
    }
    _drawLegend(b, spec, p);
    b.writeln('</svg>');
    return b.toString();
  }

  // ── Cells ────────────────────────────────────────────────────────
  // Each cell type organises its organelles so that large, enclosing
  // structures are drawn first (no overlap clipping), the nucleus sits central
  // and the ER is drawn adjacent to it, and every organelle is bounded well
  // inside the cell membrane.

  static void _drawPlantCell(StringBuffer b, Set<String> present, _Palette p) {
    if (_has(present, 'cell_wall')) {
      _rect(b, 60, 60, w - 120, h - 120, rx: 34, fill: p.wallFill, stroke: p.wallStroke, sw: 8);
    }
    if (_has(present, 'cell_membrane')) {
      _rect(b, 98, 98, w - 196, h - 196, rx: 22, fill: 'none', stroke: p.membrane, sw: 3, dashed: '10 6');
    }
    if (_has(present, 'cytoplasm')) {
      _ellipse(b, 640, 430, 505, 322, fill: p.cytoplasmFill, stroke: 'none');
    }
    if (_has(present, 'vacuole')) {
      _vacuole(b, 560, 430, 250, 165, p);
    }
    if (_has(present, 'nucleus')) {
      _nucleus(b, 830, 380, 76, p);
    }
    if (_has(present, 'endoplasmic_reticulum')) {
      _roughER(b, 700, 235, 250, 44, p, rough: true);
      _smoothER(b, 690, 452, 210, 36, p);
    }
    if (_has(present, 'chloroplasts')) {
      _chloroplast(b, 250, 250, 58, 30, p, rot: -15);
      _chloroplast(b, 322, 210, 46, 25, p, rot: 10);
      _chloroplast(b, 230, 640, 60, 30, p, rot: -8);
      _chloroplast(b, 420, 700, 46, 24, p, rot: 22);
      _chloroplast(b, 630, 160, 44, 23, p, rot: -18);
      _chloroplast(b, 520, 268, 40, 21, p, rot: 12);
    }
    if (_has(present, 'mitochondria')) {
      _mitochondrion(b, 180, 500, 46, 20, p, rot: 24);
      _mitochondrion(b, 1120, 470, 44, 19, p, rot: -14);
      _mitochondrion(b, 348, 150, 42, 18, p, rot: 18);
      _mitochondrion(b, 1040, 680, 46, 20, p, rot: 12);
      _mitochondrion(b, 640, 660, 40, 18, p, rot: -22);
    }
    if (_has(present, 'golgi_apparatus')) {
      _golgi(b, 1020, 560, 5, 116, 30, p);
    }
    if (_has(present, 'ribosomes')) {
      _ribosomeCloud(b, p);
    }
  }

  static void _drawAnimalCell(StringBuffer b, Set<String> present, _Palette p) {
    if (_has(present, 'cell_membrane')) {
      _ellipse(b, 640, 430, 520, 320, fill: 'none', stroke: p.membrane, sw: 4);
    }
    if (_has(present, 'cytoplasm')) {
      _ellipse(b, 640, 430, 505, 305, fill: p.cytoplasmFill, stroke: 'none');
    }
    if (_has(present, 'nucleus')) {
      _nucleus(b, 570, 380, 88, p);
    }
    if (_has(present, 'endoplasmic_reticulum')) {
      _roughER(b, 450, 250, 220, 42, p, rough: true);
      _smoothER(b, 640, 250, 230, 40, p);
    }
    if (_has(present, 'mitochondria')) {
      _mitochondrion(b, 900, 240, 46, 20, p, rot: 25);
      _mitochondrion(b, 980, 520, 48, 21, p, rot: -18);
      _mitochondrion(b, 310, 600, 42, 18, p, rot: 16);
      _mitochondrion(b, 420, 700, 46, 20, p, rot: 12);
    }
    if (_has(present, 'golgi_apparatus')) {
      _golgi(b, 880, 620, 5, 126, 34, p);
    }
    if (_has(present, 'lysosomes')) {
      _lysosome(b, 240, 330, 24, p);
      _lysosome(b, 1080, 660, 26, p);
      _lysosome(b, 330, 220, 22, p);
    }
    if (_has(present, 'centrioles')) {
      _centriole(b, 640, 590, 74, p);
    }
    if (_has(present, 'ribosomes')) {
      _ribosomeCloud(b, p);
    }
  }

  static void _drawBacterialCell(StringBuffer b, Set<String> present, _Palette p) {
    if (_has(present, 'capsule')) {
      _ellipse(b, 600, 430, 530, 310, fill: p.capsuleFill, stroke: p.capsuleStroke, sw: 2, dashed: '8 6');
    }
    if (_has(present, 'cell_wall')) {
      _ellipse(b, 600, 430, 472, 252, fill: p.wallFill, stroke: p.wallStroke, sw: 6);
    }
    if (_has(present, 'cell_membrane')) {
      _ellipse(b, 600, 430, 452, 232, fill: 'none', stroke: p.membrane, sw: 3);
    }
    if (_has(present, 'cytoplasm')) {
      _ellipse(b, 600, 430, 442, 222, fill: p.cytoplasmFill, stroke: 'none');
    }
    if (_has(present, 'nucleoid_dna')) {
      _nucleoid(b, 500, 390, 190, 42, p);
    }
    if (_has(present, 'plasmid')) {
      _circle(b, 760, 540, 26, fill: 'none', stroke: p.plasmid, sw: 3);
      _circle(b, 760, 540, 10, fill: p.plasmid, sw: 0);
    }
    if (_has(present, 'ribosomes')) {
      for (final (x, y) in [(660, 300), (720, 460), (460, 520), (640, 560), (520, 300)]) {
        _dot(b, x.toDouble(), y.toDouble(), 6, p.ribosome);
      }
    }
    if (_has(present, 'pili')) {
      _pili(b, p);
    }
    if (_has(present, 'flagellum')) {
      _flagellum(b, 1040, 396, p.flagellum, 5);
    }
  }

  static void _drawFungalCell(StringBuffer b, Set<String> present, _Palette p) {
    if (_has(present, 'cell_wall')) {
      _rect(b, 80, 90, w - 160, h - 200, rx: 70, fill: p.wallFill, stroke: p.wallStroke, sw: 8);
    }
    if (_has(present, 'cell_membrane')) {
      _rect(b, 132, 142, w - 264, h - 284, rx: 50, fill: 'none', stroke: p.membrane, sw: 3);
    }
    if (_has(present, 'cytoplasm')) {
      _rect(b, 134, 144, w - 268, h - 288, rx: 50, fill: p.cytoplasmFill, sw: 0);
    }
    if (_has(present, 'nucleus')) {
      _nucleus(b, 420, 360, 80, p);
    }
    if (_has(present, 'endoplasmic_reticulum')) {
      _roughER(b, 340, 240, 200, 38, p, rough: true);
      _smoothER(b, 480, 470, 200, 40, p);
    }
    if (_has(present, 'vacuole')) {
      _vacuole(b, 900, 500, 190, 122, p);
    }
    if (_has(present, 'mitochondria')) {
      _mitochondrion(b, 660, 608, 46, 20, p, rot: 20);
      _mitochondrion(b, 250, 620, 42, 18, p, rot: -12);
      _mitochondrion(b, 560, 180, 44, 19, p, rot: 14);
      _mitochondrion(b, 300, 460, 40, 17, p, rot: 26);
    }
    if (_has(present, 'golgi_apparatus')) {
      _golgi(b, 700, 300, 5, 108, 28, p);
    }
    if (_has(present, 'ribosomes')) {
      _ribosomeCloud(b, p);
    }
  }

  // ── Organelle morphology ─────────────────────────────────────────
  // Each organelle is drawn with scientifically grounded detail.

  static void _nucleus(StringBuffer b, double cx, double cy, double r, _Palette p) {
    // Envelope (double membrane): outer circle + slightly smaller inner ring.
    _circle(b, cx, cy, r, fill: p.nucleusFill, stroke: p.nucleusStroke, sw: 3);
    _circle(b, cx, cy, r - 8, fill: 'none', stroke: p.nucleusStroke, sw: 1.4, opacity: 0.5);
    // Nucleolus (darker inner body), offset off centre.
    _circle(b, cx + r * 0.18, cy - r * 0.1, r * 0.32, fill: p.nucleolus, sw: 0);
    // Nuclear pore complexes: small dots ringing the envelope.
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi * 2 / 10;
      final px = cx + (r - 4) * math.cos(a);
      final py = cy + (r - 4) * math.sin(a);
      _dot(b, px, py, 2.4, p.membranePore);
    }
  }

  static void _mitochondrion(StringBuffer b, double cx, double cy, double rx, double ry, _Palette p,
      {required double rot}) {
    // Outer membrane.
    _ellipse(b, cx, cy, rx, ry, fill: p.mitochondriaFill, stroke: p.mitochondriaStroke, sw: 2.4, rot: rot);
    // Inner membrane: smaller ellipse pushed toward one pole.
    final off = rx * 0.22;
    final dx = off * math.cos(rot * math.pi / 180);
    final dy = off * math.sin(rot * math.pi / 180);
    _ellipse(b, cx + dx, cy + dy, rx * 0.72, ry * 0.62,
        fill: 'none', stroke: p.mitochondriaStroke, sw: 1.6, rot: rot, opacity: 0.8);
    // Cristae: transverse membrane infoldings.
    for (var k = -1; k <= 1; k++) {
      final px = cx + dx * (1 - (k * 0.28));
      final py = cy + dy * (1 - (k * 0.28));
      _cristaLine(b, px, py, ry * 0.5, rot, p);
    }
  }

  static void _cristaLine(StringBuffer b, double cx, double cy, double len, double rot, _Palette p) {
    final rad = rot * math.pi / 180;
    final dx = (len * math.sin(rad)) / 2;
    final dy = (len * math.cos(rad)) / 2;
    b.write('  <line x1="${_n(cx - dx)}" y1="${_n(cy - dy)}" x2="${_n(cx + dx)}" y2="${_n(cy + dy)}" '
        'stroke="${p.cristae}" stroke-width="1.6" stroke-linecap="round"/>\n');
  }

  static void _chloroplast(StringBuffer b, double cx, double cy, double rx, double ry, _Palette p,
      {required double rot}) {
    // Envelope (double membrane) around the stroma.
    _ellipse(b, cx, cy, rx, ry, fill: p.chloroplastFill, stroke: p.chloroplastStroke, sw: 2.4, rot: rot);
    _ellipse(b, cx, cy, rx - 5, ry - 5, fill: p.stroma, stroke: 'none', rot: rot);
    // Grana: small stacks of thylakoid discs (rounded bars).
    final granaPlaces = <(double, double)>[(-rx * 0.28, 0.0), (rx * 0.18, -ry * 0.15), (rx * 0.12, ry * 0.28)];
    for (final (gx, gy) in granaPlaces) {
      final rad = rot * math.pi / 180;
      final cxr = cx + gx * math.cos(rad) - gy * math.sin(rad);
      final cyr = cy + gx * math.sin(rad) + gy * math.cos(rad);
      _granum(b, cxr, cyr, math.max(6, rx * 0.22), 3, rot, p);
    }
  }

  static void _granum(StringBuffer b, double cx, double cy, double bw, int discs, double rot, _Palette p) {
    const stack = 2.6;
    for (var i = 0; i < discs; i++) {
      final rad = rot * math.pi / 180;
      final dyv = (i - (discs - 1) / 2) * stack;
      final tx = -dyv * math.sin(rad);
      final ty = dyv * math.cos(rad);
      _rect(b, cx - bw / 2 + tx, cy - bw / 2 - 1.2 + ty, bw, bw / 2,
          rx: bw * 0.25, fill: p.grana, stroke: 'none', sw: 0);
    }
  }

  static void _golgi(StringBuffer b, double x, double y, int n, double wlen, double hei, _Palette p) {
    // Cisternae stack: each is a squat curved membrane sac.
    for (var i = 0; i < n; i++) {
      final dy = i * (hei * 0.52);
      b.write('  <path d="M${_n(x)} ${_n(y + dy)} q${_n(wlen * 0.2)} -${_n(hei * 0.6)} ${_n(wlen * 0.5)} 0 '
          'q${_n(wlen * 0.3)} ${_n(hei * 0.6)} ${_n(wlen)} 0" fill="none" stroke="${p.golgiStroke}" '
          'stroke-width="3" stroke-linecap="round"/>\n');
    }
    // Budding transport vesicles at the cis-face.
    _dot(b, x + 8, y - 12, 5, p.golgiVesicle);
    _dot(b, x + wlen - 8, y - 12, 5, p.golgiVesicle);
    _dot(b, x + wlen - 8, y + n * hei * 0.5 + 8, 5, p.golgiVesicle);
  }

  static void _roughER(StringBuffer b, double x, double y, double wlen, double amp, _Palette p, {required bool rough}) {
    final pts = <String>[];
    var up = true;
    for (var x0 = 0.0; x0 <= wlen; x0 += 40) {
      final yy = up ? y : y + amp;
      pts.add('${_n(x0 + x)},${_n(yy)}');
      up = !up;
    }
    b.write('  <polyline points="${pts.join(' ')}" fill="none" stroke="${p.erStroke}" '
        'stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>\n');
    if (rough) {
      // Bound ribosomes stud the membrane surface.
      up = true;
      for (var x0 = 10.0; x0 < wlen; x0 += 40) {
        final yy = up ? y + amp / 2 : y + amp;
        _dot(b, x + x0, yy, 2.6, p.erRibosome);
        up = !up;
      }
    }
  }

  static void _smoothER(StringBuffer b, double x, double y, double wlen, double amp, _Palette p) {
    final pts = <String>[];
    var up = true;
    for (var x0 = 0.0; x0 <= wlen; x0 += 44) {
      final yy = up ? y : y + amp;
      pts.add('${_n(x0 + x)},${_n(yy)}');
      up = !up;
    }
    b.write('  <polyline points="${pts.join(' ')}" fill="none" stroke="${p.erStroke}" '
        'stroke-width="2.4" stroke-dasharray="6 5" stroke-linecap="round" stroke-linejoin="round"/>\n');
  }

  static void _vacuole(StringBuffer b, double cx, double cy, double rx, double ry, _Palette p) {
    // Tonoplast membrane (outline) with watery contents inside.
    _ellipse(b, cx, cy, rx, ry, fill: p.vacuoleFill, stroke: p.vacuoleStroke, sw: 3);
    _ellipse(b, cx, cy, rx * 0.86, ry * 0.84, fill: 'none', stroke: p.vacuoleInner, sw: 1.6, opacity: 0.7);
  }

  static void _nucleoid(StringBuffer b, double x, double y, double wlen, double amp, _Palette p) {
    // A loose, circular loop of DNA (the prokaryotic chromosome).
    final pts = <String>[];
    var up = true;
    for (var x0 = 0.0; x0 <= wlen; x0 += 40) {
      final yy = up ? y : y + amp;
      pts.add('${_n(x0 + x)},${_n(yy)}');
      up = !up;
    }
    b.write('  <polyline points="${pts.join(' ')}" fill="none" stroke="${p.nucleoid}" '
        'stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>\n');
  }

  static void _lysosome(StringBuffer b, double cx, double cy, double r, _Palette p) {
    _circle(b, cx, cy, r, fill: p.lysosomeFill, stroke: p.lysosomeStroke, sw: 2);
    // A few digestive enzyme granules.
    _dot(b, cx - r * 0.3, cy - r * 0.2, 2.2, p.lysosomeStroke);
    _dot(b, cx + r * 0.25, cy + r * 0.2, 2.0, p.lysosomeStroke);
  }

  static void _centriole(StringBuffer b, double cx, double cy, double len, _Palette p) {
    // Nine triplet microtubules: draw the two perpendicular barrel silhouettes.
    _rect(b, cx - len / 2, cy - 8, len, 16, rx: 8, fill: 'none', stroke: p.centriole, sw: 3);
    _rect(b, cx - 8, cy - len / 2, 16, len, rx: 8, fill: 'none', stroke: p.centriole, sw: 3);
  }

  static void _pili(StringBuffer b, _Palette p) {
    for (final (x1, y1, x2, y2) in [(300, 430, 220, 360), (300, 430, 230, 480), (300, 430, 260, 320)]) {
      _line(b, x1.toDouble(), y1.toDouble(), x2.toDouble(), y2.toDouble(), stroke: p.pili, sw: 3);
      _dot(b, x2.toDouble(), y2.toDouble(), 5, p.pili);
    }
  }

  static void _flagellum(StringBuffer b, double x, double y, String stroke, double sw) {
    b.write('  <path d="M${_n(x)} ${_n(y)} q${_n(140)} -94 ${_n(300)} 24" fill="none" '
        'stroke="$stroke" stroke-width="$sw" stroke-linecap="round"/>\n');
  }

  // A sparse scatter of free ribosomes in the cytosol (cytoplasm region).
  static void _ribosomeCloud(StringBuffer b, _Palette p) {
    for (final (x, y) in [(190, 250), (240, 700), (1120, 300), (1080, 620), (620, 130), (700, 760), (380, 178)]) {
      _dot(b, x.toDouble(), y.toDouble(), 4.6, p.ribosome);
    }
  }

  // ── Labelling engine ─────────────────────────────────────────────
  // Labels start near their organelle anchor, then a deterministic separation
  // pass resolves collisions and a hard clamp enforces the no-clipping rule;
  // any label that still cannot fit inside the canvas is dropped.

  static void _drawLabels(StringBuffer b, BiologySpec spec, Set<String> present, _Palette p) {
    final anchors = _anchorsFor(spec.app);
    final seen = <String>{};
    final placed = <_PlacedLabel>[];

    for (final labelText in spec.labels) {
      final key = _labelKey(labelText);
      if (seen.contains(key) || !present.contains(key)) continue;
      seen.add(key);
      final anchor = anchors[key];
      if (anchor == null) continue;

      final tw = _textWidth(labelText);
      final bw = tw + _labelPad * 2;
      const bh = _labelFont + 7;
      // Initial box: anchored just right/below the leader start.
      final bx = anchor.lx + 2;
      final by = anchor.ly - 5;
      placed.add(_PlacedLabel(labelText, key, anchor.px, anchor.py, _Box(bx, by, bw, bh)));
    }

    _resolveLayout(placed);

    // Draw resolved labels + leaders.
    for (final l in placed) {
      final box = l.box;
      // Clip leader to the box edge nearest the anchor point.
      final endX = l.ax.clamp(box.x, box.x + box.w);
      final endY = l.ay.clamp(box.y, box.y + box.h);
      b.write('  <line x1="${_n(l.ax)}" y1="${_n(l.ay)}" '
          'x2="${_n(endX)}" y2="${_n(endY)}" stroke="${p.leader}" '
          'stroke-width="1.6" stroke-opacity="0.9"/>\n');
      b.write('  <text x="${_n(box.x + _labelPad)}" y="${_n(box.y + _labelFont + 2)}" '
          'font-size="$_labelFont" font-weight="600" fill="${p.labelInk}" '
          'paint-order="stroke" stroke="${_labelHalo(p)}" stroke-width="3" '
          'stroke-linejoin="round">${_esc(l.text)}</text>\n');
    }
  }

  // Halo is drawn in the background colour so text stays readable over
  // organelles (no-clipping / legibility rule).
  static String _labelHalo(_Palette p) => p.bg == 'none' ? '#ffffff' : p.bg;

  static void _resolveLayout(List<_PlacedLabel> placed) {
    // Greedy separation: iteratively push overlapping pairs apart along the
    // axis of least penetration until stable or the iteration budget is spent.
    for (var pass = 0; pass < 60; pass++) {
      var moved = false;
      for (var i = 0; i < placed.length; i++) {
        for (var j = i + 1; j < placed.length; j++) {
          final a = placed[i].box;
          final bb = placed[j].box;
          if (!a.overlaps(bb)) continue;
          final ox = math.min(a.x + a.w, bb.x + bb.w) - math.max(a.x, bb.x);
          final oy = math.min(a.y + a.h, bb.y + bb.h) - math.max(a.y, bb.y);
          if (ox < oy) {
            final push = (ox / 2) + 1;
            if (a.cx <= bb.cx) {
              a.x -= push;
              bb.x += push;
            } else {
              a.x += push;
              bb.x -= push;
            }
          } else {
            final push = (oy / 2) + 1;
            if (a.cy <= bb.cy) {
              a.y -= push;
              bb.y += push;
            } else {
              a.y += push;
              bb.y -= push;
            }
          }
          moved = true;
        }
      }
      if (!moved) break;
    }

    // No-clipping: constrain to the canvas with an edge margin; drop any label
    // that cannot be brought fully inside without its width exceeding the area.
    placed.removeWhere((l) {
      final bx = l.box;
      bx.x = bx.x.clamp(_edge, w - _edge - bx.w);
      bx.y = bx.y.clamp(_edge, h - _edge - bx.h);
      return bx.isOutside;
    });
  }

  static double _textWidth(String s) => _labelFont * 0.6 * s.length;

  // ── Legend ───────────────────────────────────────────────────────

  static void _drawLegend(StringBuffer b, BiologySpec spec, _Palette p) {
    final present = <String>{
      for (final s in spec.structures)
        if (s.present) s.name,
    };
    if (present.isEmpty) return;
    b.write('  <text x="40" y="${_n(h - 40)}" font-size="13" font-weight="700" fill="${p.labelMuted}" '
        'letter-spacing="1">KEY · ${_esc(spec.title.toUpperCase())} · FORM ${spec.form}</text>\n');
    b.write('  <text x="40" y="${_n(h - 16)}" font-size="12" fill="${p.labelMuted}">'
        '${_esc(present.join(' · '))}</text>\n');
  }

  static Map<String, _Anchor> _anchorsFor(String app) {
    final m = <String, _Anchor>{};
    void add(String key, double px, double py, double lx, double ly) => m[key] = (px: px, py: py, lx: lx, ly: ly);
    switch (app) {
      case 'bacterial_cell':
        add('capsule', 170, 300, 40, 200);
        add('cell_wall', 600, 172, 700, 110);
        add('cell_membrane', 830, 150, 900, 110);
        add('cytoplasm', 1000, 430, 1080, 520);
        add('nucleoid_dna', 600, 400, 660, 600);
        add('ribosomes', 700, 300, 360, 640);
        add('plasmid', 760, 540, 880, 700);
        add('pili', 260, 410, 150, 520);
        add('flagellum', 1080, 400, 1210, 300);
        break;
      case 'animal_cell':
        add('cell_membrane', 640, 110, 660, 70);
        add('cytoplasm', 1180, 680, 1240, 720);
        add('nucleus', 570, 380, 360, 220);
        add('mitochondria', 900, 240, 1030, 160);
        add('endoplasmic_reticulum', 560, 250, 380, 120);
        add('golgi_apparatus', 880, 620, 1150, 700);
        add('lysosomes', 340, 220, 250, 330);
        add('centrioles', 640, 590, 460, 700);
        add('ribosomes', 300, 700, 200, 740);
        break;
      case 'fungal_cell':
        add('cell_wall', 640, 110, 660, 70);
        add('cell_membrane', 640, 150, 720, 120);
        add('cytoplasm', 1120, 700, 1200, 740);
        add('vacuole', 900, 500, 1140, 480);
        add('nucleus', 420, 360, 260, 200);
        add('mitochondria', 660, 608, 660, 780);
        add('endoplasmic_reticulum', 380, 250, 220, 150);
        add('golgi_apparatus', 700, 300, 880, 220);
        add('ribosomes', 300, 180, 170, 240);
        break;
      case 'plant_cell':
      default:
        add('cell_wall', 640, 70, 700, 60);
        add('cell_membrane', 640, 110, 720, 100);
        add('cytoplasm', 230, 700, 360, 780);
        add('vacuole', 560, 430, 320, 600);
        add('nucleus', 830, 380, 700, 250);
        add('chloroplasts', 250, 250, 130, 180);
        add('mitochondria', 180, 500, 90, 560);
        add('endoplasmic_reticulum', 700, 240, 560, 150);
        add('golgi_apparatus', 1020, 560, 1190, 570);
        add('ribosomes', 240, 240, 170, 330);
        break;
    }
    return m;
  }

  // ── Geometry primitives ──────────────────────────────────────────

  static void _rect(StringBuffer b, double x, double y, double wdt, double ht,
      {required String fill, required double sw, double rx = 0, String? stroke, String? dashed, double opacity = 1}) {
    final st = stroke == null ? '' : ' stroke="$stroke" stroke-width="$sw"';
    final ds = dashed != null ? ' stroke-dasharray="$dashed"' : '';
    final op = opacity < 1 ? ' opacity="$opacity"' : '';
    b.write('  <rect x="${_n(x)}" y="${_n(y)}" width="${_n(wdt)}" height="${_n(ht)}" rx="$rx" '
        'fill="$fill"$st$ds$op/>\n');
  }

  static void _ellipse(StringBuffer b, double cx, double cy, double rx, double ry,
      {required String fill, double sw = 0, String? stroke, double rot = 0, String? dashed, double opacity = 1}) {
    final st = (stroke == null || sw == 0) ? '' : ' stroke="$stroke" stroke-width="$sw"';
    final tr = rot != 0 ? ' transform="rotate($rot ${_n(cx)} ${_n(cy)})"' : '';
    final ds = dashed != null ? ' stroke-dasharray="$dashed"' : '';
    final op = opacity < 1 ? ' opacity="$opacity"' : '';
    b.write('  <ellipse cx="${_n(cx)}" cy="${_n(cy)}" rx="${_n(rx)}" ry="${_n(ry)}" '
        'fill="$fill"$st$tr$ds$op/>\n');
  }

  static void _circle(StringBuffer b, double cx, double cy, double r,
      {required String fill, required double sw, String? stroke, double opacity = 1}) {
    final st = (stroke == null || sw == 0) ? '' : ' stroke="$stroke" stroke-width="$sw"';
    final op = opacity < 1 ? ' opacity="$opacity"' : '';
    b.write('  <circle cx="${_n(cx)}" cy="${_n(cy)}" r="${_n(r)}" fill="$fill"$st$op/>\n');
  }

  static void _dot(StringBuffer b, double x, double y, double r, String fill) {
    b.write('  <circle cx="${_n(x)}" cy="${_n(y)}" r="${_n(r)}" fill="$fill"/>\n');
  }

  static void _line(StringBuffer b, double x1, double y1, double x2, double y2,
      {required String stroke, required double sw}) {
    b.write('  <line x1="${_n(x1)}" y1="${_n(y1)}" x2="${_n(x2)}" y2="${_n(y2)}" '
        'stroke="$stroke" stroke-width="$sw" stroke-linecap="round"/>\n');
  }

  static bool _has(Set<String> set, String key) => set.contains(key);

  static String _n(double v) => v.toStringAsFixed(1);

  static String _esc(String s) => const HtmlEscape().convert(s);
}

String _labelKey(String labelText) {
  final t = labelText.toLowerCase().trim();
  if (t.contains('cell wall')) return 'cell_wall';
  if (t.contains('cell membrane')) return 'cell_membrane';
  if (t.contains('nucleus')) return 'nucleus';
  if (t.contains('cytoplasm')) return 'cytoplasm';
  if (t.contains('chloroplast')) return 'chloroplasts';
  if (t.contains('vacuole')) return 'vacuole';
  if (t.contains('mitochond')) return 'mitochondria';
  if (t.contains('ribosome')) return 'ribosomes';
  if (t.contains('endoplasmic')) return 'endoplasmic_reticulum';
  if (t.contains('golgi')) return 'golgi_apparatus';
  if (t.contains('lysosome')) return 'lysosomes';
  if (t.contains('centriole')) return 'centrioles';
  if (t.contains('capsule')) return 'capsule';
  if (t.contains('nucleoid')) return 'nucleoid_dna';
  if (t.contains('flagell')) return 'flagellum';
  if (t.contains('pili')) return 'pili';
  if (t.contains('plasmid')) return 'plasmid';
  return t.replaceAll(' ', '_');
}
