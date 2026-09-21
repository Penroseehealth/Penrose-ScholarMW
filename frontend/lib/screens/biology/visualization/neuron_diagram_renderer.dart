import 'dart:convert';

import '../../../models/biology_visualization.dart';

/// Deterministic scientific renderer for neuron diagrams.
///
/// The AI layer only decides WHAT the diagram contains (a structured
/// `BiologySpec` with neuron `structures`); this renderer decides HOW it is
/// drawn. It produces a static anatomical image of two communicating neurones
/// showing both signal types: electrical conduction within the axon and
/// chemical signalling across the synaptic cleft. Labels are drawn with leader
/// lines on a fixed, non-overlapping layout (mirroring `NeuronPainter`).
class NeuronDiagramRenderer {
  static const double w = 1280;
  static const double h = 860;

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
    b.write('  <desc>${_esc(spec.title)} — neuron communication diagram.</desc>\n');

    final has = _presence(spec);

    _presynaptic(b, p, has);
    _axon(b, p, has);
    _terminal(b, p, has);
    _synapse(b, p, has);
    _postsynaptic(b, p, has);
    if (spec.labelsShown) _labels(b, p, has);
    _legend(b, p);

    b.writeln('</svg>');
    return b.toString();
  }

  static Map<String, bool> _presence(BiologySpec spec) {
    if (spec.structures.isEmpty) return const {};
    return {for (final s in spec.structures) s.id: s.present};
  }

  static bool _present(Map<String, bool> has, String id) {
    if (has.isEmpty) return true;
    return has[id] ?? true;
  }

  // ── Presynaptic cell body ────────────────────────────────────────────

  static void _presynaptic(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (_present(has, 'dendrites')) {
      b.write('  <g fill="none" stroke="${p.dendrite}" stroke-width="14" stroke-linecap="round">\n');
      for (final d in [
        'M 20 620 L 70 575 L 118 555',
        'M 20 500 L 55 495 L 98 495',
        'M 20 365 L 52 360 L 96 357',
        'M 24 280 L 60 258 L 96 236',
        'M 50 220 L 96 175 L 128 150',
      ]) {
        b.write('    <path d="$d"/>\n');
      }
      b.write('  </g>\n');
      for (final d in [
        '118,555 98,495 96,357 96,236 128,150',
      ]) {
        final pts = d.split(' ');
        b.write('  <g fill="${p.dendrite}">\n');
        for (final pt in pts) {
          final xy = pt.split(',');
          b.write('    <circle cx="${xy[0]}" cy="${xy[1]}" r="6.5"/>\n');
        }
        b.write('  </g>\n');
      }
    }

    if (_present(has, 'soma')) {
      b.write('  <ellipse cx="280" cy="430" rx="88" ry="102" fill="${p.somaFill}" '
          'stroke="${p.line}" stroke-width="3" stroke-linejoin="round"/>\n');
      _nucleus(b, p);
    }
  }

  static void _nucleus(StringBuffer b, _Palette p) {
    b.write('  <circle cx="284" cy="426" r="32" fill="${p.nucleusFill}" stroke="${p.line}" stroke-width="2.5"/>\n');
    b.write('  <circle cx="284" cy="426" r="12" fill="${p.nucleolus}"/>\n');
  }

  // ── Axon (electrical conduction) ─────────────────────────────────────

  static void _axon(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (!_present(has, 'axon')) return;
    b.write('  <path d="M 368 430 L 906 430" fill="none" stroke="${p.axon}" '
        'stroke-width="8" stroke-linecap="round"/>\n');
    if (!_present(has, 'myelin_sheath')) return;
    var x = 386.0;
    var i = 0;
    while (x < 856) {
      final width = (856 - x) < 84 ? (856 - x) : 84.0;
      b.write('  <rect x="$x" y="396" width="$width" height="68" rx="14" fill="${p.myelinFill}" '
          'stroke="${p.myelinStroke}" stroke-width="2"/>\n');
      x += width + 18;
      if (i == 1 && _present(has, 'nodes_of_ranvier')) {
        b.write('  <line x1="${x - 9 - 4}" y1="396" x2="${x - 9 - 4}" y2="464" '
            'stroke="${p.leader}" stroke-width="2" stroke-dasharray="4 5"/>\n');
      }
      i++;
    }
  }

  // ── Axon terminal / boutons ──────────────────────────────────────────

  static void _terminal(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (!_present(has, 'axon_terminal')) return;
    for (final c in ['924,398', '924,462']) {
      final xy = c.split(',');
      b.write('  <ellipse cx="${xy[0]}" cy="${xy[1]}" rx="23" ry="19" fill="${p.boutonFill}" '
          'stroke="${p.line}" stroke-width="2"/>\n');
    }
    if (_present(has, 'synaptic_vesicles')) {
      final spots = ['912,390', '930,386', '916,404', '934,440', '918,448', '932,444'];
      for (final s in spots) {
        final xy = s.split(',');
        b.write('  <circle cx="${xy[0]}" cy="${xy[1]}" r="4.5" fill="${p.vesicle}" '
            'stroke="${p.vesicleStroke}" stroke-width="1.2"/>\n');
      }
    }
  }

  // ── Synaptic cleft (chemical signalling) ─────────────────────────────

  static void _synapse(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (_present(has, 'synaptic_cleft')) {
      b.write('  <rect x="956" y="330" width="40" height="200" fill="${p.cleftFill}" '
          'stroke="${p.cleftStroke}" stroke-width="1.5"/>\n');
    }
    if (_present(has, 'neurotransmitter')) {
      final spots = ['962,392', '974,414', '964,438', '978,462', '968,486'];
      for (final s in spots) {
        final xy = s.split(',');
        b.write('  <circle cx="${xy[0]}" cy="${xy[1]}" r="4" fill="${p.neurotransmitter}"/>\n');
      }
    }
  }

  // ── Postsynaptic membrane + cell body ────────────────────────────────

  static void _postsynaptic(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (_present(has, 'postsynaptic_membrane')) {
      b.write('  <line x1="1000" y1="292" x2="1000" y2="568" stroke="${p.postMembrane}" '
          'stroke-width="9" stroke-linecap="round"/>\n');
    }
    if (_present(has, 'receptors')) {
      for (final y in ['368', '410', '444', '478']) {
        b.write('  <line x1="1000" y1="$y" x2="988" y2="$y" stroke="${p.receptor}" '
            'stroke-width="5" stroke-linecap="round"/>\n');
        b.write('  <circle cx="987" cy="$y" r="5" fill="${p.receptor}"/>\n');
      }
    }
    if (_present(has, 'soma')) {
      b.write('  <ellipse cx="1090" cy="430" rx="84" ry="98" fill="${p.postCellFill}" '
          'stroke="${p.line}" stroke-width="3" stroke-linejoin="round"/>\n');
      b.write('  <circle cx="1094" cy="426" r="31" fill="${p.nucleusFill}" stroke="${p.line}" stroke-width="2.5"/>\n');
      b.write('  <circle cx="1094" cy="426" r="11" fill="${p.nucleolus}"/>\n');
    }
    if (_present(has, 'dendrites')) {
      b.write('  <g fill="none" stroke="${p.dendritePost}" stroke-width="13" stroke-linecap="round">\n');
      for (final d in [
        'M 1166 346 L 1210 308 L 1250 266',
        'M 1166 398 L 1218 398 L 1268 406',
        'M 1166 462 L 1214 498 L 1258 540',
        'M 1166 520 L 1200 556 L 1240 590',
      ]) {
        b.write('    <path d="$d"/>\n');
      }
      b.write('  </g>\n');
      final tips = ['1250,266', '1268,406', '1258,540', '1240,590'];
      for (final t in tips) {
        final xy = t.split(',');
        b.write('  <circle cx="${xy[0]}" cy="${xy[1]}" r="6.5" fill="${p.dendritePost}"/>\n');
      }
    }
  }

  // ── Labels ───────────────────────────────────────────────────────────

  static void _labels(StringBuffer b, _Palette p, Map<String, bool> has) {
    final rows = <({String id, String text, double ax, double ay, double lx, double ly})>[
      (id: 'dendrites', text: 'Dendrites', ax: 98, ay: 275, lx: 21, ly: 173),
      (id: 'soma', text: 'Cell body (soma)', ax: 192, ay: 541, lx: 32, ly: 705),
      (id: 'nucleus', text: 'Nucleus', ax: 272, ay: 411, lx: 341, ly: 312),
      (id: 'myelin_sheath', text: 'Myelin sheath', ax: 459, ay: 405, lx: 501, ly: 266),
      (id: 'nodes_of_ranvier', text: 'Node of Ranvier', ax: 708, ay: 405, lx: 747, ly: 266),
      (id: 'axon', text: 'Axon', ax: 597, ay: 486, lx: 427, ly: 740),
      (id: 'axon_terminal', text: 'Axon terminal', ax: 915, ay: 428, lx: 747, ly: 104),
      (id: 'synaptic_vesicles', text: 'Synaptic vesicles', ax: 964, ay: 398, lx: 885, ly: 139),
      (id: 'synaptic_cleft', text: 'Synaptic cleft', ax: 986, ay: 243, lx: 896, ly: 46),
      (id: 'receptors', text: 'Receptors', ax: 1007, ay: 444, lx: 1163, ly: 543),
      (id: 'postsynaptic_membrane', text: 'Postsynaptic membrane', ax: 1007, ay: 523, lx: 1088, ly: 749),
      (id: 'neurotransmitter', text: 'Neurotransmitters', ax: 990, ay: 601, lx: 853, ly: 798),
    ];
    b.write('  <g fill="${p.ink}" font-size="20">\n');
    for (final r in rows) {
      if (!_present(has, r.id)) continue;
      final width = r.text.length * 11.0;
      final endX = r.lx + width + 8;
      b.write('  <line x1="$endX" y1="${r.ly + 15}" x2="${r.ax > endX ? r.ax - 6 : r.ax + 6}" '
          'y2="${r.ay}" stroke="${p.leader}" stroke-width="1.5"/>\n');
      b.write('  <circle cx="${r.ax}" cy="${r.ay}" r="3.2" fill="${p.ink}"/>\n');
      b.write('  <text x="${r.lx}" y="${r.ly}" font-weight="700">${_esc(r.text)}</text>\n');
    }
    b.write('  </g>\n');
  }

  static void _legend(StringBuffer b, _Palette p) {
    b.write('  <g font-size="15">\n');
    b.write('  <rect x="20" y="820" width="14" height="14" rx="3" fill="${p.signalIcon}"/>');
    b.write('  <text x="44" y="832" fill="${p.signalInk}" font-weight="700">Electrical signalling</text>');
    b.write('  <rect x="270" y="820" width="14" height="14" rx="3" fill="${p.chemIcon}"/>');
    b.write('  <text x="294" y="832" fill="${p.chemInk}" font-weight="700">Chemical signalling</text>');
    b.write('  <text x="540" y="832" fill="${p.muted}">within neurones · across the synapse</text>');
    b.write('  </g>\n');
  }

  static String _esc(String s) => const HtmlEscape().convert(s);
}

// ── Palette ───────────────────────────────────────────────────────────
class _Palette {
  final String canvas;
  final String ink;
  final String line;
  final String dendrite;
  final String dendritePost;
  final String somaFill;
  final String postCellFill;
  final String nucleusFill;
  final String nucleolus;
  final String axon;
  final String myelinFill;
  final String myelinStroke;
  final String boutonFill;
  final String vesicle;
  final String vesicleStroke;
  final String cleftFill;
  final String cleftStroke;
  final String neurotransmitter;
  final String postMembrane;
  final String receptor;
  final String leader;
  final String signalIcon;
  final String signalInk;
  final String chemIcon;
  final String chemInk;
  final String muted;

  const _Palette({
    required this.canvas,
    required this.ink,
    required this.line,
    required this.dendrite,
    required this.dendritePost,
    required this.somaFill,
    required this.postCellFill,
    required this.nucleusFill,
    required this.nucleolus,
    required this.axon,
    required this.myelinFill,
    required this.myelinStroke,
    required this.boutonFill,
    required this.vesicle,
    required this.vesicleStroke,
    required this.cleftFill,
    required this.cleftStroke,
    required this.neurotransmitter,
    required this.postMembrane,
    required this.receptor,
    required this.leader,
    required this.signalIcon,
    required this.signalInk,
    required this.chemIcon,
    required this.chemInk,
    required this.muted,
  });

  factory _Palette.light() => const _Palette(
        canvas: '#ffffff',
        ink: '#1e1e2a',
        line: '#4f5aa8',
        dendrite: '#8a9bff',
        dendritePost: '#7d6bc4',
        somaFill: '#e4e9ff',
        postCellFill: '#eee3ff',
        nucleusFill: '#8a5bd6',
        nucleolus: '#cdb4ff',
        axon: '#6b79c9',
        myelinFill: '#f3eef5',
        myelinStroke: '#b9b0c9',
        boutonFill: '#e4e9ff',
        vesicle: '#ffc857',
        vesicleStroke: '#b38b1b',
        cleftFill: '#f4f1fa',
        cleftStroke: '#d6d2e6',
        neurotransmitter: '#14b8a6',
        postMembrane: '#6d4fc9',
        receptor: '#7c3aed',
        leader: '#8a94c8',
        signalIcon: '#ffb020',
        signalInk: '#8a5a00',
        chemIcon: '#14b8a6',
        chemInk: '#0d7a6f',
        muted: '#7a7a90',
      );

  factory _Palette.dark() => const _Palette(
        canvas: '#0e0e1a',
        ink: '#ededf6',
        line: '#9aa0ff',
        dendrite: '#7d8cf0',
        dendritePost: '#8b7ad8',
        somaFill: '#2a2952',
        postCellFill: '#3e3a5c',
        nucleusFill: '#574080',
        nucleolus: '#c4a8ff',
        axon: '#c9c2ff',
        myelinFill: '#26263f',
        myelinStroke: '#7c7a9c',
        boutonFill: '#2a2952',
        vesicle: '#ffc857',
        vesicleStroke: '#a98c2f',
        cleftFill: '#191931',
        cleftStroke: '#3a3a58',
        neurotransmitter: '#34d6c1',
        postMembrane: '#a78bfa',
        receptor: '#c4a4ff',
        leader: '#9aa0ff',
        signalIcon: '#ffb020',
        signalInk: '#ffd580',
        chemIcon: '#34d6c1',
        chemInk: '#8af0e3',
        muted: '#a5a5c4',
      );
}