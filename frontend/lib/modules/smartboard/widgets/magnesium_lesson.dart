import 'package:flutter/material.dart';

import 'magnesium_diagram.dart';

/// The initial demonstration lesson, laid out in board space (1600 x 900).
///
/// Everything is live Flutter text and a painted diagram — never a flattened
/// image — so it stays readable at every zoom level and the ink layer above it
/// can be written on, erased and selected.
class MagnesiumLesson extends StatelessWidget {
  const MagnesiumLesson({super.key});

  static const Color _surface = Color(0xFFF8FBFE);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(64, 52, 64, 44),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(flex: 5, child: _leftColumn()),
          Container(width: 1, color: kInk.withValues(alpha: 0.12)),
          Expanded(flex: 6, child: Padding(padding: const EdgeInsets.only(left: 44), child: _rightColumn())),
        ],
      ),
    );
  }

  Widget _leftColumn() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Magnesium (Mg)',
            style: TextStyle(fontSize: 62, height: 1.05, fontWeight: FontWeight.w700, color: kInk, letterSpacing: -1),
          ),
          const SizedBox(height: 8),
          Text(
            'Atomic number 12',
            style: TextStyle(fontSize: 26, color: kInkMuted.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double side = constraints.biggest.shortestSide.clamp(220.0, 430.0);
                  return MagnesiumDiagram(size: side);
                },
              ),
            ),
          ),
          Text(
            'Electron arrangement: 2, 8, 2',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: kInk,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '12 protons · 12 electrons · neutral atom',
            style: TextStyle(fontSize: 19, color: kInkMuted.withValues(alpha: 0.85)),
          ),
        ],
      );

  Widget _rightColumn() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'How many electrons are in the last orbit?',
            style: TextStyle(fontSize: 40, height: 1.22, fontWeight: FontWeight.w700, color: kInk),
          ),
          const SizedBox(height: 26),
          _step('Atomic number of Mg = 12'),
          _step('Neutral atom: 12 protons and 12 electrons'),
          _step('Electron-shell distribution: 2, 8, 2'),
          _step('Total electrons: 2 + 8 + 2 = 12'),
          _step('Valence shell: third shell (M shell)'),
          _step('Electrons in the last shell: 2'),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            decoration: BoxDecoration(
              color: kEmphasis.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(6),
              border: Border(left: BorderSide(color: kEmphasis, width: 5)),
            ),
            child: const Text(
              'There are 2 electrons in the last orbit of Mg.',
              style: TextStyle(fontSize: 32, height: 1.25, fontWeight: FontWeight.w700, color: kEmphasis),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Shells fill K first, then L, then M — 2 · 8 · 2.',
            style: TextStyle(fontSize: 19, color: kInkMuted.withValues(alpha: 0.9), fontStyle: FontStyle.italic),
          ),
        ],
      );

  Widget _step(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 9, right: 12),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: kInk.withValues(alpha: 0.55), shape: BoxShape.circle),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 26, height: 1.35, color: kInk, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
}
