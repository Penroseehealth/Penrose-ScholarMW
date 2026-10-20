import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penrose_scholar/widgets/floating_chatbot.dart';

/// Reproduces the REAL mount: [FloatingChatbot.wrap] is passed to
/// [MaterialApp.router]'s `builder`, i.e. above the router's [Navigator].
/// The panel's `TextField` / `SelectableText` need an [Overlay] ancestor, so
/// this must not throw.
void main() {
  testWidgets('chatbot works when mounted from MaterialApp.router builder', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Center(child: Text('page')))),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => FloatingChatbot.wrap(context, child),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'mount must not throw');

    await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'opening the panel must not throw');
    expect(find.text('Ask me anything about your studies.'), findsOneWidget);

    // Focus the composer: this is the path that resolves the context menu
    // through the root Overlay.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'focusing the TextField must not throw');
  });
}
