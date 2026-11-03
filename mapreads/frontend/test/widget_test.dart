import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mapreads_frontend/main.dart';

void main() {
  testWidgets('MapReads opens the workspace and map library navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MapReadsApp());

    expect(find.text('MapReads'), findsOneWidget);
    expect(find.text('Map library'), findsOneWidget);
  });
}
