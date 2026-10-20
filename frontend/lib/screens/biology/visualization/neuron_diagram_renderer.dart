import 'dart:convert';

import '../../../models/biology_visualization.dart';
import '../neuron/neuron_anatomy.dart';

/// Deterministic scientific renderer for the neuron/synapse diagram.
///
/// Uses the shared [neuronStructures] catalogue as the single source of truth
/// for labels. Draws smooth, connected anatomy with a visible
/// direction-of-signal cue (dendrites/soma → axon hillock → axon → terminal →
/// cleft → postsynaptic receptors). The diagram is a schematic (real neurones
/// vary) and is designed to stay within bounds at the standard canvas size.
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
    b.write(
        '  <desc>${_esc(spec.title)} — neuron communication diagram (electrical conduction within the axon; chemical transmission across the synaptic cleft).</desc>\n');

    final has = _presence(spec);

    _presynaptic(b, p, has);
    _axon(b, p, has);
    _terminal(b, p, has);
    _synapse(b, p, has);
    _postsynaptic(b, p, has);
    if (spec.labelsShown) {
      _labels(b, p, has);
    }
    _legend(b, p);
    _note(b, p);

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

  // ── Presynaptic cell ─────────────────────────────────────────────────
  static void _presynaptic(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (_present(has, 'dendrites')) {
      b.write(
          '  <g fill="none" stroke="${p.dendrite}" stroke-width="14" stroke-linecap="round" stroke-linejoin="round">\n');
      for (final d in const [
        'M 18 640 L 70 588 L 128 560',
        'M 16 520 L 58 512 L 110 504',
        'M 16 380 L 54 372 L 106 362',
        'M 22 290 L 62 266 L 108 240',
        'M 58 224 L 104 176 L 142 148',
      ]) {
        b.write('    <path d="$d"/>\n');
      }
      b.write('  </g>\n');
      for (final d in const [
        '128,560 110,504 106,362 108,240 142,148',
      ]) {
        final pts = d.split(' ');
        b.write('  <g fill="${p.dendrite}">\n');
        for (final pt in pts) {
          final xy = pt.split(',');
          b.write('    <circle cx="${xy[0]}" cy="${xy[1]}" r="6.8"/>\n');
        }
        b.write('  </g>\n');
      }
    }

    if (_present(has, 'soma')) {
      b.write('  <ellipse cx="290" cy="430" rx="92" ry="106" fill="${p.somaFill}" '
          'stroke="${p.line}" stroke-width="3" stroke-linejoin="round"/>\n');
    }
    if (_present(has, 'nucleus')) {
      b.write('  <circle cx="294" cy="426" r="34" fill="${p.nucleusFill}" stroke="${p.line}" stroke-width="2"/>\n');
      b.write('  <circle cx="296" cy="428" r="13" fill="${p.nucleolus}"/>\n');
    }
  }

  // ── Axon + hillock + nodes ───────────────────────────────────────────
  static void _axon(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (_present(has, 'axon_hillock')) {
      b.write('  <path d="M 366 382 Q 384 404 400 426 L 400 438 Q 384 460 366 482 Z" '
          'fill="${p.somaFill}" stroke="${p.line}" stroke-width="2.5" stroke-linejoin="round"/>\n');
    }

    if (!_present(has, 'axon')) return;
    b.write('  <path d="M 400 432 L 914 432" fill="none" stroke="${p.axon}" '
        'stroke-width="8" stroke-linecap="round"/>\n');

    if (_present(has, 'myelin_sheath')) {
      var x = 418.0;
      while (x < 860) {
        final remaining = 860 - x;
        if (remaining <= 0) break;
        final width = remaining < 90 ? remaining : 90.0;
        if (width <= 0) break;
        b.write('  <rect x="$x" y="396" width="$width" height="72" rx="16" fill="${p.myelinFill}" '
            'stroke="${p.myelinStroke}" stroke-width="2"/>\n');
        x += width + 22;
        if (_present(has, 'nodes_of_ranvier')) {
          final nodeX = x - 22 - 11;
          if (nodeX >= 434 && nodeX <= 880) {
            b.write('  <rect x="${nodeX - 7}" y="410" width="14" height="44" rx="4" fill="${p.axon}"/>\n');
          }
        }
      }
    }
  }

  // ── Terminal ─────────────────────────────────────────────────────────
  static void _terminal(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (!_present(has, 'axon_terminal')) return;
    b.write(
        '  <path d="M 914 414 Q 938 392 956 392 L 960 392 Q 970 412 970 432 Q 970 452 960 472 L 956 472 Q 938 472 914 450 Z" '
        'fill="${p.boutonFill}" stroke="${p.line}" stroke-width="2.5" stroke-linejoin="round"/>\n');

    if (_present(has, 'synaptic_vesicles')) {
      const spots = ['934,404', '946,400', '938,416', '950,440', '936,452', '948,448'];
      for (final s in spots) {
        final xy = s.split(',');
        b.write('  <circle cx="${xy[0]}" cy="${xy[1]}" r="5" fill="${p.vesicle}" '
            'stroke="${p.vesicleStroke}" stroke-width="1"/>\n');
      }
    }
  }

  // ── Cleft + neurotransmitter ─────────────────────────────────────────
  static void _synapse(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (_present(has, 'synaptic_cleft')) {
      b.write('  <rect x="972" y="322" width="30" height="220" rx="4" fill="${p.cleftFill}" '
          'stroke="${p.cleftStroke}" stroke-width="1.5"/>\n');
    }
    if (_present(has, 'neurotransmitter')) {
      const spots = ['978,392', '986,414', '980,438', '988,462', '982,486'];
      for (final s in spots) {
        final xy = s.split(',');
        b.write('  <circle cx="${xy[0]}" cy="${xy[1]}" r="4" fill="${p.neurotransmitter}"/>\n');
      }
    }
  }

  // ── Postsynaptic ─────────────────────────────────────────────────────
  static void _postsynaptic(StringBuffer b, _Palette p, Map<String, bool> has) {
    if (_present(has, 'postsynaptic_membrane')) {
      b.write('  <line x1="1006" y1="288" x2="1006" y2="576" stroke="${p.postMembrane}" '
          'stroke-width="10" stroke-linecap="round"/>\n');
    }
    if (_present(has, 'receptors')) {
      for (final y in const ['366', '410', '444', '478']) {
        b.write('  <path d="M 1006 $y L 994 $y" stroke="${p.receptor}" stroke-width="5" stroke-linecap="round"/>\n');
        b.write('  <path d="M 994 $y L 990 ${double.parse(y) - 3} L 988 $y L 990 ${double.parse(y) + 3} Z" '
            'fill="${p.receptor}"/>\n');
      }
    }
    if (_present(has, 'soma')) {
      b.write('  <ellipse cx="1100" cy="432" rx="88" ry="102" fill="${p.postCellFill}" '
          'stroke="${p.line}" stroke-width="3" stroke-linejoin="round"/>\n');
    }
    if (_present(has, 'nucleus')) {
      b.write('  <circle cx="1104" cy="428" r="32" fill="${p.nucleusFill}" stroke="${p.line}" stroke-width="2"/>\n');
      b.write('  <circle cx="1106" cy="430" r="11" fill="${p.nucleolus}"/>\n');
    }
    if (_present(has, 'dendrites')) {
      b.write(
          '  <g fill="none" stroke="${p.dendritePost}" stroke-width="13" stroke-linecap="round" stroke-linejoin="round">\n');
      for (final d in const [
        'M 1176 350 L 1224 308 L 1266 264',
        'M 1178 402 L 1234 404 L 1284 414',
        'M 1178 468 L 1230 506 L 1276 550',
        'M 1176 528 L 1214 566 L 1258 602',
      ]) {
        b.write('    <path d="$d"/>\n');
      }
      b.write('  </g>\n');
      for (final t in const ['1266,264', '1284,414', '1276,550', '1258,602']) {
        final xy = t.split(',');
        b.write('  <circle cx="${xy[0]}" cy="${xy[1]}" r="6.8" fill="${p.dendritePost}"/>\n');
      }
    }
  }

  // ── Labels (anchored, clamped to bounds) ─────────────────────────────
  static void _labels(StringBuffer b, _Palette p, Map<String, bool> has) {
    final rows = <({String id, double ax, double ay, double lx, double ly})>[
      (id: 'dendrites', ax: 110, ay: 270, lx: 16, ly: 164),
      (id: 'soma', ax: 206, ay: 544, lx: 24, ly: 724),
      (id: 'nucleus', ax: 282, ay: 410, lx: 356, ly: 308),
      (id: 'axon_hillock', ax: 384, ay: 476, lx: 150, ly: 826),
      (id: 'myelin_sheath', ax: 466, ay: 404, lx: 516, ly: 262),
      (id: 'nodes_of_ranvier', ax: 718, ay: 404, lx: 758, ly: 262),
      (id: 'axon', ax: 600, ay: 490, lx: 428, ly: 756),
      (id: 'axon_terminal', ax: 930, ay: 432, lx: 754, ly: 96),
      (id: 'synaptic_vesicles', ax: 944, ay: 396, lx: 894, ly: 134),
      (id: 'synaptic_cleft', ax: 988, ay: 238, lx: 902, ly: 40),
      (id: 'neurotransmitter', ax: 998, ay: 604, lx: 856, ly: 814),
      (id: 'receptors', ax: 1014, ay: 444, lx: 1176, ly: 550),
      (id: 'postsynaptic_membrane', ax: 1014, ay: 528, lx: 1100, ly: 766),
    ];
    b.write('  <g fill="${p.ink}" font-size="19">\n');
    for (final r in rows) {
      if (!_present(has, r.id)) continue;
      final text = neuronStructureById[r.id]?.shortName ?? r.id;
      final lx = r.lx.clamp(4.0, w - (text.length * 11.0) - 16);
      final ly = r.ly.clamp(18.0, h - 28);
      final width = text.length * 11.0;
      final endX = lx + width + 10;
      final ax = r.ax.clamp(0.0, w);
      final ay = r.ay.clamp(0.0, h);
      b.write('  <line x1="$endX" y1="${ly + 15}" x2="${ax > endX ? ax - 6 : ax + 6}" '
          'y2="$ay" stroke="${p.leader}" stroke-width="1.5"/>\n');
      b.write('  <circle cx="$ax" cy="$ay" r="3.4" fill="${p.ink}"/>\n');
      b.write('  <text x="$lx" y="$ly" font-weight="700">${_esc(text)}</text>\n');
    }
    b.write('  </g>\n');
  }

  static void _legend(StringBuffer b, _Palette p) {
    b.write('  <g font-size="15">\n');
    b.write('  <rect x="18" y="826" width="14" height="14" rx="3" fill="${p.signalIcon}"/>\n');
    b.write('  <text x="42" y="838" fill="${p.signalInk}" font-weight="700">Electrical signalling</text>\n');
    b.write('  <rect x="278" y="826" width="14" height="14" rx="3" fill="${p.chemIcon}"/>\n');
    b.write('  <text x="302" y="838" fill="${p.chemInk}" font-weight="700">Chemical transmission</text>\n');
    b.write(
        '  <text x="558" y="838" fill="${p.muted}">dendrites/soma → axon hillock → axon → terminal → cleft → receptors</text>\n');
    b.write('  </g>\n');
  }

  static void _note(StringBuffer b, _Palette p) {
    b.write(
        '  <text x="18" y="20" fill="${p.muted}" font-size="13">Schematic — real neurones vary. Vesicles/receptors shown in simplified form.</text>\n');
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
        myelinFill: '#f6f4fa',
        myelinStroke: '#bcb3cc',
        boutonFill: '#e4e9ff',
        vesicle: '#ffc857',
        vesicleStroke: '#b38b1b',
        cleftFill: '#f7f5fb',
        cleftStroke: '#d6d2e6',
        neurotransmitter: '#14b8a6',
        postMembrane: '#6d4fc9',
        receptor: '#7c3aed',
        leader: '#8a94c8',
        signalIcon: '#ffb020',
        signalInk: '#8a5a00',
        chemIcon: '#14b8a6',
        chemInk: '#0d7a6f',
        muted: '#6f6f84',
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
