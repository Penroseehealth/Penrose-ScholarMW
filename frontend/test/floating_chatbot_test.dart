import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/widgets/floating_chatbot.dart';

void main() {
  testWidgets('floating chatbot bubble is positioned bottom-right and tappable', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FloatingChatbot.wrap(
            context,
            const Scaffold(body: Center(child: Text('page'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder buttonIcon = find.byIcon(Icons.chat_bubble_rounded);
    expect(buttonIcon, findsOneWidget, reason: 'the bubble button should render');

    final Rect rect = tester.getRect(buttonIcon);
    expect(rect.right, greaterThan(800 - 80), reason: 'button should hug the right edge, got ${rect.right}');
    expect(rect.bottom, greaterThan(600 - 80), reason: 'button should hug the bottom edge, got ${rect.bottom}');
    expect(rect.width, lessThanOrEqualTo(56));
    expect(rect.height, lessThanOrEqualTo(56));

    // Tapping the bubble opens the chat panel.
    await tester.tap(buttonIcon);
    await tester.pumpAndSettle();
    expect(find.text('Ask me anything about your studies.'), findsOneWidget,
        reason: 'tapping the bubble should open the assistant panel');
    expect(find.text('ScholarAI Assistant'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsWidgets);
  });
}
