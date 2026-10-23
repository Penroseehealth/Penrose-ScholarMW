import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penrose_scholar/core/networking/api_client.dart';
import 'package:penrose_scholar/features/msce_papers/msce_papers_controller.dart';
import 'package:penrose_scholar/features/msce_papers/msce_papers_page.dart';

const Map<String, dynamic> _catalogue = <String, dynamic>{
  'papers': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': '2023_mathematics_p1',
      'year': 2023,
      'subject': 'Mathematics',
      'paper': 1,
      'subject_code': '131',
      'title': 'MSCE 2023 Mathematics Paper 1',
      'pages': 14,
      'verified': true,
      'verification': <String, dynamic>{'maneb_header': true},
    },
    <String, dynamic>{
      'id': '2023_mathematics_p2',
      'year': 2023,
      'subject': 'Mathematics',
      'paper': 2,
      'subject_code': '131',
      'title': 'MSCE 2023 Mathematics Paper 2',
      'pages': 18,
      'verified': true,
    },
    <String, dynamic>{
      'id': '2026_biology_p1',
      'year': 2026,
      'subject': 'Biology',
      'paper': 1,
      'subject_code': '022',
      'title': 'MSCE 2026 Biology Paper 1',
      'pages': 12,
      'verified': true,
    },
  ],
  'years': <int>[2026, 2023],
  'subjects': <String>['Biology', 'Mathematics'],
  'available': true,
};

MscePapersController _controller() {
  final client = MockClient((http.Request request) async {
    if (request.url.path.endsWith('/msce-papers')) {
      return http.Response(jsonEncode(_catalogue), 200, headers: {'content-type': 'application/json'});
    }
    if (request.url.path.endsWith('/msce-papers/status')) {
      return http.Response('{"available":true,"count":3}', 200, headers: {'content-type': 'application/json'});
    }
    return http.Response('{}', 404);
  });
  return MscePapersController(apiClient: ApiClient(baseUrl: '/api/v1', client: client));
}

Finder _card(String id) => find.byKey(ValueKey<String>('paper-$id'));

void _bigSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(MscePapersController controller) => MaterialApp(
      home: MscePapersPage(controller: controller),
    );

void main() {
  testWidgets('lists the verified catalogue and filters by subject and paper', (tester) async {
    _bigSurface(tester);
    final controller = _controller();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.text('MSCE Past Papers'), findsOneWidget);
    expect(_card('2023_mathematics_p1'), findsOneWidget);
    expect(_card('2023_mathematics_p2'), findsOneWidget);
    expect(_card('2026_biology_p1'), findsOneWidget);
    expect(find.text('Page'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Biology'));
    await tester.pumpAndSettle();
    expect(_card('2023_mathematics_p1'), findsNothing);
    expect(_card('2026_biology_p1'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Paper II'));
    await tester.pumpAndSettle();
    expect(_card('2026_biology_p1'), findsNothing);
    expect(find.text('No paper matches these filters'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'All years'));
    await tester.pumpAndSettle();
    expect(find.text('No paper matches these filters'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Biology'));
    await tester.pumpAndSettle();
    expect(_card('2023_mathematics_p2'), findsOneWidget);
    expect(_card('2023_mathematics_p1'), findsNothing);
  });

  testWidgets('opens a paper in the page-by-page viewer', (tester) async {
    _bigSurface(tester);
    final controller = _controller();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.tap(_card('2023_mathematics_p1'));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 14'), findsOneWidget);
    expect(find.text('M131/I'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Page 2 of 14'), findsOneWidget);

    await tester.tap(find.byTooltip('Paper details'));
    await tester.pumpAndSettle();
    expect(find.text('Verified against the MANEB header'), findsOneWidget);
    expect(find.text('Nothing is saved to this device.'), findsNothing);
    expect(find.textContaining('Nothing is saved'), findsWidgets);
  });
}
