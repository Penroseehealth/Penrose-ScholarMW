import 'package:flutter_test/flutter_test.dart';

import 'package:penrose_scholar/widgets/handwriting/handwriting_board.dart';
import 'package:penrose_scholar/widgets/handwriting/handwriting_glyphs.dart';

const List<String> _commands = <String>['M', 'L', 'Q', 'C', 'Z'];

void main() {
  group('glyph coverage', () {
    test('covers every digit and letter a solution needs', () {
      for (final String digit in '0123456789'.split('')) {
        expect(hasGlyph(digit), isTrue, reason: 'missing digit $digit');
      }
      for (int code = 0x41; code <= 0x5A; code++) {
        final String letter = String.fromCharCode(code);
        expect(hasGlyph(letter), isTrue, reason: 'missing uppercase $letter');
      }
      for (int code = 0x61; code <= 0x7A; code++) {
        final String letter = String.fromCharCode(code);
        expect(hasGlyph(letter), isTrue, reason: 'missing lowercase $letter');
      }
    });

    test('covers the operators used in school algebra', () {
      for (final String symbol in <String>[
        '+',
        '-',
        '=',
        '/',
        '(',
        ')',
        '^',
        '<',
        '>',
        '≤',
        '≥',
        '×',
        '÷',
        '±',
        '%',
        '√',
        '²',
      ]) {
        expect(hasGlyph(symbol), isTrue, reason: 'missing symbol $symbol');
      }
    });
  });

  group('stroke data', () {
    test('every stroke tokenises into drawable commands', () {
      for (final MapEntry<String, List<String>> entry in glyphStrokes.entries) {
        for (final String stroke in entry.value) {
          final List<String> tokens = HandwritingLayout.tokenizeStroke(stroke);
          expect(tokens, isNotEmpty, reason: '${entry.key} has an empty stroke');
          expect(tokens.first, 'M', reason: '${entry.key} stroke must start with a move');
          for (final String token in tokens) {
            final bool isNumber = double.tryParse(token) != null;
            expect(
              _commands.contains(token) || isNumber,
              isTrue,
              reason: 'unparseable token "$token" in $stroke',
            );
          }
        }
      }
    });

    test('coordinate values stay inside the unit box', () {
      for (final MapEntry<String, List<String>> entry in glyphStrokes.entries) {
        for (final String stroke in entry.value) {
          for (final String token in HandwritingLayout.tokenizeStroke(stroke)) {
            final double? value = double.tryParse(token);
            if (value == null) continue;
            expect(
              value,
              inInclusiveRange(-0.1, 1.2),
              reason: '${entry.key} value $value out of range in $stroke',
            );
          }
        }
      }
    });
  });

  group('metrics', () {
    test('narrow and wide glyphs advance differently', () {
      expect(advanceFor('i'), lessThan(advanceFor('m')));
      expect(advanceFor(' '), greaterThan(advanceFor('i')));
    });

    test('unknown glyphs still advance and are drawable', () {
      expect(advanceFor('\u2603'), greaterThan(0));
      expect(strokesFor('\u2603'), isNotEmpty);
    });

    test('space draws nothing but still advances', () {
      expect(strokesFor(' '), isEmpty);
      expect(advanceFor(' '), greaterThan(0));
    });

    test('descenders are marked for the letters that need them', () {
      expect(descendsFor('g'), isTrue);
      expect(descendsFor('y'), isTrue);
      expect(descendsFor('o'), isFalse);
    });
  });

  group('layout', () {
    test('lays out strokes for written characters', () {
      expect(HandwritingLayout.build('2x + 1', fontSize: 20).strokes, isNotEmpty);
    });

    test('more characters means more strokes', () {
      final int short = HandwritingLayout.build('2x', fontSize: 20).strokes.length;
      final int longer = HandwritingLayout.build('2x + 1', fontSize: 20).strokes.length;
      expect(longer, greaterThan(short));
    });

    test('a space adds no strokes', () {
      final int plain = HandwritingLayout.build('xx', fontSize: 20).strokes.length;
      final int spaced = HandwritingLayout.build('x x', fontSize: 20).strokes.length;
      expect(spaced, plain);
    });

    test('empty text produces no strokes', () {
      expect(HandwritingLayout.build('', fontSize: 20).strokes, isEmpty);
    });
  });
}
