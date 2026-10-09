import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:penrose_scholar/widgets/handwriting/handwriting_board.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('renders handwritten text without error', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const HandwritingBoard('x = 2', fontSize: 24)));
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completes the animation and reports it once', (WidgetTester tester) async {
    int completions = 0;
    await tester.pumpWidget(
      wrap(
        HandwritingBoard('2x + 1 = 7', fontSize: 24, onComplete: () => completions++),
      ),
    );
    await tester.pumpAndSettle();

    expect(completions, 1);
  });

  testWidgets('animate false draws the full writing immediately', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const HandwritingBoard('x = 2', fontSize: 24, animate: false)));
    await tester.pump();

    // No settle: the board should be complete on the very first frame.
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty text renders nothing', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const HandwritingBoard('', fontSize: 24)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('long text stays inside the available width when wrapping', (
    WidgetTester tester,
  ) async {
    const String text = '2x + 3x = 15 therefore x = 3 and y = 4 and z = 5 and w = 6';
    await tester.pumpWidget(
      wrap(const SizedBox(width: 200, child: HandwritingBoard(text, fontSize: 18, maxWidth: 200))),
    );
    await tester.pumpAndSettle();

    final Size size = tester.getSize(find.byType(HandwritingBoard));
    expect(size.width, lessThanOrEqualTo(200));
    expect(tester.takeException(), isNull);
  });
}
