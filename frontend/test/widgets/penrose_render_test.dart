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

    final RenderRepaintBoundary boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(r'C:\Users\zispaas\AppData\Local\Temp\opencode\penrose.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
