import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:penrose_scholar/modules/smartboard/models/board_models.dart';
import 'package:penrose_scholar/modules/smartboard/screens/smart_board_screen.dart';
import 'package:penrose_scholar/modules/smartboard/state/smart_board_controller.dart';
import 'package:penrose_scholar/modules/smartboard/widgets/magnesium_diagram.dart';

/// Verifies the Chemistry AI Tutor Smart Board: magnesium lesson content and
/// scientific accuracy, board chrome, panel behaviour, controller state
/// (undo/redo, partial erasing, pages, persistence) and responsive layouts.
void main() {
  Future<void> pumpBoard(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      // flutter_test defaults: 800x600 logical at DPR 3.
      tester.view.physicalSize = const Size(2400, 1800);
      tester.view.devicePixelRatio = 3;
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MaterialApp(home: SmartBoardScreen()));
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('magnesium lesson', () {
    test('electron shells are 2, 8, 2 for the neutral atom and 2, 8 for Mg²⁺', () {
      expect(kMagnesiumShells, <int>[2, 8, 2]);
      expect(kMagnesiumShells.reduce((int a, int b) => a + b), 12);
      expect(kMagnesiumShells.last, 2, reason: 'the outermost shell holds 2 electrons');
      expect(kMagnesiumIonShells, <int>[2, 8]);
      expect(kMagnesiumIonShells.reduce((int a, int b) => a + b), 10, reason: 'Mg²⁺ lost two valence electrons');
    });

    testWidgets('diagram exposes an accessible 2, 8, 2 description', (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      String label;
      try {
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MagnesiumDiagram(size: 240))));
        label = tester.getSemantics(find.byType(MagnesiumDiagram)).label;
      } finally {
        // Disposed inline: testWidgets verifies handle disposal before any
        // addTearDown callback would get the chance to run.
        handle.dispose();
      }
      expect(label, 'Magnesium Bohr diagram. Electron arrangement 2, 8, 2. Twelve electrons.');
    });

    testWidgets('shows the question, worked steps and the final answer', (WidgetTester tester) async {
      await pumpBoard(tester, const Size(1600, 900));

      expect(find.text('Magnesium (Mg)'), findsOneWidget);
      expect(find.text('Atomic number 12'), findsOneWidget);
      expect(find.text('Electron arrangement: 2, 8, 2'), findsOneWidget);
      expect(find.text('12 protons · 12 electrons · neutral atom'), findsOneWidget);

      expect(find.text('How many electrons are in the last orbit?'), findsOneWidget);
      expect(find.text('Atomic number of Mg = 12'), findsOneWidget);
      expect(find.text('Electron-shell distribution: 2, 8, 2'), findsOneWidget);
      expect(find.text('Total electrons: 2 + 8 + 2 = 12'), findsOneWidget);
      expect(find.text('Valence shell: third shell (M shell)'), findsOneWidget);
      expect(find.text('Electrons in the last shell: 2'), findsOneWidget);
      expect(find.text('There are 2 electrons in the last orbit of Mg.'), findsOneWidget);

      await tester.runAsync<void>(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await expectLater(
        find.byType(SmartBoardScreen),
        matchesGoldenFile('goldens/smart_board_wide.png'),
      );
    });
  });

  group('board chrome', () {
    testWidgets('header, toolbar and footer are all wired up', (WidgetTester tester) async {
      await pumpBoard(tester, const Size(1600, 900));

      // Header: identity, label and the navigation actions back to the app.
      expect(find.text('Chemistry AI Tutor'), findsOneWidget);
      expect(find.text('Smart Board'), findsOneWidget);
      expect(find.byTooltip('Home'), findsOneWidget);
      expect(find.byTooltip('Lessons'), findsOneWidget);
      expect(find.byTooltip('Q&A'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byTooltip('Back to chemistry dashboard'), findsOneWidget);

      // Teacher tools.
      for (final String tooltip in <String>[
        'Select and move',
        'Pen',
        'Highlighter',
        'Eraser',
        'Laser pointer',
        'Shapes',
        'Text',
        'Math / equation',
        'Edit selected text',
        'Erase selected object',
        'Undo (Ctrl+Z)',
        'Redo (Ctrl+Shift+Z)',
        'Clear board',
      ]) {
        expect(find.byTooltip(tooltip), findsOneWidget, reason: 'missing tool: $tooltip');
      }

      // Page, zoom and save controls.
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.byTooltip('Add page'), findsOneWidget);
      expect(find.byTooltip('Duplicate page'), findsOneWidget);
      expect(find.byTooltip('Delete page'), findsOneWidget);
      expect(find.byTooltip('Zoom in'), findsOneWidget);
      expect(find.byTooltip('Zoom out'), findsOneWidget);
      expect(find.byTooltip('Fit to board'), findsOneWidget);
      expect(find.byTooltip('Save board'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('ask panel collapses to a handle and expands again without losing the board',
        (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);
      await pumpBoard(tester, const Size(1600, 900));

      // Expanded by default: input, modes and quick questions are visible.
      expect(find.text('Ask / Input'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Voice'), findsOneWidget);
      expect(find.text('Quick questions'), findsOneWidget);
      expect(find.text('How many electrons are in the last orbit?'), findsOneWidget);
      expect(find.text('Balance: Mg + O₂ → MgO.'), findsOneWidget);

      // Collapse.
      await tester.tap(find.byTooltip('Collapse panel'));
      await tester.pump(const Duration(milliseconds: 320));
      expect(find.bySemanticsLabel('Open Ask / Input panel'), findsOneWidget);
      // The lesson is still on the board while the panel is collapsed.
      expect(find.text('Magnesium (Mg)'), findsOneWidget);

      // Expand again.
      await tester.tap(find.bySemanticsLabel('Open Ask / Input panel'));
      await tester.pump(const Duration(milliseconds: 320));
      expect(find.text('Quick questions'), findsOneWidget);
      expect(find.text('Magnesium (Mg)'), findsOneWidget);
    });
  });

  group('SmartBoardController', () {
    late SmartBoardController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      controller = SmartBoardController();
      await controller.load();
    });

    tearDown(() => controller.dispose());

    test('starts on the magnesium demonstration page', () {
      expect(controller.pageCount, 1);
      expect(controller.currentPage.title, 'Magnesium (Mg)');
      expect(controller.currentPage.lessonId, 'magnesium');
      expect(controller.tool, BoardTool.pen);
    });

    test('undo and redo cover ink edits', () {
      controller.commitStroke(<Offset>[const Offset(10, 10), const Offset(60, 60)]);
      expect(controller.currentPage.strokes, hasLength(1));
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.currentPage.strokes, isEmpty);
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.currentPage.strokes, hasLength(1));
    });

    test('partial erasing removes only the segment under the eraser', () {
      controller.commitStroke(<Offset>[for (int i = 0; i <= 20; i++) Offset(i * 10.0, 100)]);
      controller.commitStroke(<Offset>[const Offset(500, 500), const Offset(560, 560)]);

      final bool changed = controller.eraseAt(const Offset(100, 100), 20);

      expect(changed, isTrue);
      // The erased stroke was split into the parts either side of the gap.
      expect(controller.currentPage.strokes.length, greaterThan(1));
      // The untouched stroke far away is still there.
      expect(
        controller.currentPage.strokes.any(
          (BoardStroke stroke) => stroke.points.first == const Offset(500, 500),
        ),
        isTrue,
      );
      // Nothing close to the eraser survived.
      expect(
        controller.currentPage.strokes.any(
          (BoardStroke stroke) => stroke.points.any((Offset p) => (p - const Offset(100, 100)).distance < 20),
        ),
        isFalse,
      );
    });

    test('expanding the ask panel keeps ink, zoom, selection and the current page', () {
      controller.commitStroke(<Offset>[const Offset(5, 5), const Offset(40, 40)]);
      controller.setZoom(1.6);
      controller.select(controller.currentPage.strokes.first.id); // not prefixed: select() accepts raw id
      controller.addText('Note', const Offset(100, 100));
      final String pageId = controller.currentPage.id;

      controller.setPanelExpanded(false);
      controller.setPanelExpanded(true);

      expect(controller.currentPage.strokes, hasLength(1));
      expect(controller.currentPage.texts, hasLength(1));
      expect(controller.zoom, 1.6);
      expect(controller.currentPage.id, pageId);
      expect(controller.selectedId, isNotNull);
    });

    test('text objects can be edited and the edit is undoable', () {
      final BoardTextObject note = controller.addText('first', const Offset(20, 20));
      controller.updateText(note.id, 'second');

      expect(controller.currentPage.texts.single.text, 'second');
      controller.undo();
      expect(controller.currentPage.texts.single.text, 'first');
    });

    test('pages keep their own content and support add, duplicate and delete', () {
      controller.commitStroke(<Offset>[const Offset(1, 1), const Offset(2, 2)]);
      controller.addPage();
      expect(controller.pageCount, 2);
      expect(controller.pageIndex, 1);
      expect(controller.currentPage.strokes, isEmpty, reason: 'a new page starts empty');

      controller.previousPage();
      expect(controller.currentPage.strokes, hasLength(1));

      controller.duplicatePage();
      expect(controller.pageCount, 3);
      expect(controller.currentPage.strokes, hasLength(1), reason: 'duplicate copies the ink');

      controller.deletePage();
      expect(controller.pageCount, 2);
    });

    test('board content survives a save and reload', () async {
      controller.commitStroke(<Offset>[const Offset(15, 25), const Offset(90, 95)]);
      controller.addText('persisted', const Offset(120, 200));
      await controller.save();

      final SmartBoardController reloaded = SmartBoardController();
      await reloaded.load();
      expect(reloaded.currentPage.strokes, hasLength(1));
      expect(reloaded.currentPage.texts.single.text, 'persisted');
      reloaded.dispose();
      expect(reloaded.isDirty, isFalse);
    });

    test('clearing ink keeps text and clears only the current page', () {
      controller.commitStroke(<Offset>[const Offset(3, 3), const Offset(9, 9)]);
      controller.addText('keep me', const Offset(50, 50));
      controller.clearInk();

      expect(controller.currentPage.strokes, isEmpty);
      expect(controller.currentPage.texts, hasLength(1));
    });
  });

  group('responsive layout', () {
    testWidgets('narrow screens keep the whole workspace usable', (WidgetTester tester) async {
      await pumpBoard(tester, const Size(700, 900));

      expect(find.text('Chemistry AI Tutor'), findsOneWidget);
      expect(find.text('Magnesium (Mg)'), findsOneWidget);
      expect(find.byTooltip('Pen'), findsOneWidget, reason: 'toolbar stays reachable as a strip');
      expect(find.text('Ask / Input'), findsOneWidget);

      await tester.runAsync<void>(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await expectLater(
        find.byType(SmartBoardScreen),
        matchesGoldenFile('goldens/smart_board_narrow.png'),
      );
    });
  });
}
