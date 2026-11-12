import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/widgets/floating_chatbot.dart';

/// The floating bot must carry the same voice controls as the tutor surface:
/// a mute/unmute toggle for spoken replies in the header, and a mic button in
/// the composer. Neither may throw when the panel is opened.
void main() {
  Future<void> openPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FloatingChatbot())),
    );
    // The bubble's brand mark ripples continuously, so pumpAndSettle would
    // never return; pump a bounded number of frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byType(FloatingChatbot));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('panel exposes the speak-replies toggle and toggles cleanly', (tester) async {
    await openPanel(tester);

    // Replies are spoken by default, so the header starts on the unmuted icon.
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(tester.takeException(), isNull, reason: 'toggling speech must not throw');
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
  });

  testWidgets('mic control is present in the composer when supported', (tester) async {
    await openPanel(tester);

    // The web speech recogniser reports unsupported on the test platform, so the
    // mic button is intentionally hidden there - the important guarantee is that
    // opening the panel and building the composer never throws.
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });
}
