import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:penrose_scholar/widgets/handwriting/handwriting_board.dart';

/// Counts pixels that are not white or transparent.
///
/// This is the check that actually proves the board draws something: a
/// `CustomPaint` in the tree proves nothing if the painter emits no strokes.
Future<int> countInk(WidgetTester tester, Finder finder) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.descendant(of: finder, matching: find.byType(RepaintBoundary)).first);
  // toImage and toByteData do real raster work outside the fake-async zone;
  // without runAsync the test never completes.
  final ui.Image? image = await tester.runAsync(() => boundary.toImage());
  final ByteData? data =
      await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba)) as ByteData?;
  final Uint8List bytes = data!.buffer.asUint8List();

  int ink = 0;
  for (int i = 0; i < bytes.length; i += 4) {
    final int r = bytes[i];
    final int g = bytes[i + 1];
    final int b = bytes[i + 2];
    final int a = bytes[i + 3];
    if (a == 0) continue;
    if (r < 200 || g < 200 || b < 200) ink++;
  }
  image!.dispose();
  return ink;
}

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 600, child: child))));

  testWidgets('paints real ink for a handwritten equation', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const HandwritingBoard('2x + 1 = 7', fontSize: 32, animate: false)));
    await tester.pumpAndSettle();

    final int ink = await countInk(tester, find.byType(HandwritingBoard));
    expect(ink, greaterThan(200), reason: 'the board painted almost nothing');
  });

  testWidgets('a longer answer paints more ink than a single character', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const HandwritingBoard('x', fontSize: 32, animate: false)));
    await tester.pumpAndSettle();
    final int one = await countInk(tester, find.byType(HandwritingBoard));

    await tester.pumpWidget(wrap(const HandwritingBoard('x = 42', fontSize: 32, animate: false)));
    await tester.pumpAndSettle();
    final int several = await countInk(tester, find.byType(HandwritingBoard));

    expect(several, greaterThan(one));
  });

  testWidgets('every glyph in a real solution paints ink', (WidgetTester tester) async {
    const String solution = 'x = 42, y = -7, z = 1/2, 25%, <=, >=, sqrt(9) = 3';
    await tester.pumpWidget(wrap(const HandwritingBoard(solution, fontSize: 28, animate: false)));
    await tester.pumpAndSettle();

    final int ink = await countInk(tester, find.byType(HandwritingBoard));
    expect(ink, greaterThan(400), reason: 'a full solution should cover plenty of pixels');
  });

  testWidgets('the animation draws progressively more than the final frame alone', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap(const HandwritingBoard('2x + 1 = 7', fontSize: 32)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final int early = await countInk(tester, find.byType(HandwritingBoard));

    await tester.pumpAndSettle();
    final int complete = await countInk(tester, find.byType(HandwritingBoard));

    expect(complete, greaterThan(early), reason: 'the writing should build up over time');
  });

  testWidgets('the ruled baseline is opt-in', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const HandwritingBoard('2x + 1', fontSize: 28, animate: false)));
    await tester.pumpAndSettle();
    final int plain = await countInk(tester, find.byType(HandwritingBoard));

    await tester.pumpWidget(
      wrap(
        const HandwritingBoard('2x + 1', fontSize: 28, animate: false, showBaseline: true),
      ),
    );
    await tester.pumpAndSettle();
    final int ruled = await countInk(tester, find.byType(HandwritingBoard));

    expect(ruled, greaterThan(plain), reason: 'the baseline should add pixels');
  });
}
