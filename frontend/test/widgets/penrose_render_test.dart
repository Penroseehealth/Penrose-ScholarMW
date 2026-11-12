import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:penrose_scholar/widgets/brand/penrose_logo.dart';

void main() {
  testWidgets('render PenroseTriangle to PNG', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              child: PenroseTriangle(size: 360),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(
      find.ancestor(of: find.byType(PenroseTriangle), matching: find.byType(RepaintBoundary)).first,
    );

    // Rasterising and PNG-encoding run on the engine thread. Widget tests use a
    // fake async clock, so these futures only complete inside runAsync - which
    // is why the previous version hung until the 10-minute test timeout.
    final ByteData? bytes = await tester.runAsync<ByteData?>(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 2);
      final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data;
    });

    expect(bytes, isNotNull, reason: 'the logo must rasterise to PNG bytes');
    final png = bytes!.buffer.asUint8List();
    expect(png.length, greaterThan(0));

    // Keep a copy in the system temp directory for manual inspection; the
    // previous hardcoded developer path made this fail on every other machine.
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}penrose_triangle.png');
    file.writeAsBytesSync(png);
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    expect(file.lengthSync(), greaterThan(0));
  });
}
