import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Layout contract for §2 (MathDrill full-screen workspace), asserted on the
/// router SOURCE because importing `app_router.dart` into a VM test pulls the
/// whole screen graph, which transitively imports `dart:html` (web-only).
///
/// Contract:
///   * `/mathsdrill` and `/mathsdrill/progress` are registered exactly once,
///     OUTSIDE the HomeShell ShellRoute (no sidebar width reserved);
///   * the HomeShell ShellRoute itself still exists for every other route
///     (sidebar returns automatically when leaving MathDrill).
void main() {
  final src = File('lib/router/app_router.dart').readAsStringSync();

  int indexOfRoute(String path) => src.indexOf("_route('$path'");

  test('/mathsdrill routes are registered outside the HomeShell shell', () {
    final shellIdx = src.indexOf('ShellRoute(');
    final homeShellIdx = src.indexOf('HomeShell(');

    expect(shellIdx, greaterThan(0), reason: 'HomeShell ShellRoute must exist');
    expect(homeShellIdx, greaterThan(0),
        reason: 'HomeShell must still wrap the normal routes');

    for (final path in ['/mathsdrill', '/mathsdrill/progress']) {
      final occurrences = "_route('$path'".allMatches(src).length;
      expect(occurrences, 1,
          reason: '$path must be registered exactly once (found $occurrences)');
      final idx = indexOfRoute(path);
      expect(idx, greaterThan(0), reason: '$path registration missing');
      expect(idx, lessThan(shellIdx),
          reason: '$path must sit OUTSIDE the ShellRoute so HomeShell '
              '(and its sidebar) is not mounted while MathDrill is open');
    }
  });
}
