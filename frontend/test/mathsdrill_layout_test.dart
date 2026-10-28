import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/modules/mathsdrill/screens/mathsdrill_screen.dart';
import 'package:penrose_scholar/providers/auth_provider.dart';
import 'package:penrose_scholar/router/app_router.dart';
import 'package:penrose_scholar/screens/home/home_shell.dart';
import 'package:provider/provider.dart';

/// Authenticated stand-in: the router guard only reads `isAuthenticated`,
/// which is an overridable getter, so no services or HTTP are touched.
class _FakeAuth extends AuthProvider {
  @override
  bool get isAuthenticated => true;

  @override
  String get userName => 'Test Student';
}

/// §2 layout contract: `/mathsdrill` (+ `/progress`) are registered OUTSIDE
/// the HomeShell shell, so the main navigation rail is not reserved while the
/// workspace is open, and it returns automatically for every other route.
void main() {
  testWidgets(
      'MathDrill routes render full-screen without HomeShell, other routes keep it',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = _FakeAuth();
    final appRouter = AppRouter(auth);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: appRouter.router),
      ),
    );
    await tester.pumpAndSettle();

    // MathDrill: full-screen — no HomeShell (no reserved sidebar width).
    appRouter.router.go('/mathsdrill');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: '/mathsdrill must build cleanly');
    expect(find.byType(MathsdrillScreen), findsOneWidget,
        reason: 'the workspace screen must show');
    expect(
      find.byType(HomeShell),
      findsNothing,
      reason:
          'MathDrill must run outside HomeShell so no sidebar width is reserved',
    );
    expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets,
        reason: 'a compact control must keep navigation reachable');

    // Progress route: same full-screen treatment.
    appRouter.router.go('/mathsdrill/progress');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(HomeShell), findsNothing,
        reason: '/mathsdrill/progress is part of the workspace');

    // Leaving MathDrill: the sidebar comes back untouched.
    appRouter.router.go('/student');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'regular routes must keep working');
    expect(find.byType(HomeShell), findsOneWidget,
        reason: 'HomeShell must be restored when exiting MathDrill');
  });
}
