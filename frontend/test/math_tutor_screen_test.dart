import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/screens/mathematics/math_tutor_screen.dart';
import 'package:penrose_scholar/services/voice_catalog_service.dart';
import 'package:penrose_scholar/widgets/math_tutor/math_tutor_audio_bar.dart';
import 'package:penrose_scholar/widgets/math_tutor/voice_accent_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline catalog holder so the picker can be exercised without the API.
class VoiceCatalogServiceForTest {
  static final VoiceCatalogService catalog = VoiceCatalogService();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// The tutor screen is a long scrollable; give the tests a tall surface so
  /// the canvas, the worked steps and the voice picker are all laid out.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('settings drawer offers three accents with male and female voices', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: MathTutorScreen(enableRemote: false)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The accent list lives behind the hamburger, off the solving board.
    expect(find.text('Tutor voice'), findsNothing);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Tutor voice'), findsOneWidget);
    for (final accent in <String>['American', 'British', 'Indian']) {
      expect(find.text(accent), findsOneWidget);
      expect(find.text('$accent male'), findsOneWidget);
      expect(find.text('$accent female'), findsOneWidget);
    }
  });

  testWidgets('audio bar shows the narration transport controls', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: MathTutorScreen(enableRemote: false)));
    await tester.pump();

    expect(find.text('Narration'), findsOneWidget);
    for (final tooltip in <String>[
      'Restart from the beginning',
      'Previous step',
      'Play',
      'Stop',
      'Next step',
      'Replay this step',
      'Narration speed',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: 'missing $tooltip');
    }
  });

  testWidgets('solving a problem renders the worked steps on screen', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: MathTutorScreen(enableRemote: false)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Find the hypotenuse of a right triangle with legs 3 and 4 cm');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Worked solution'), findsOneWidget);
    expect(find.textContaining('Answer: 5'), findsOneWidget);
    expect(find.textContaining('1. Identify the triangle'), findsOneWidget);
    expect(find.textContaining('Apply the Pythagorean theorem'), findsWidgets);
    expect(find.textContaining('Step '), findsWidgets);
  });

  testWidgets('an unrecognised problem explains what is supported', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: MathTutorScreen(enableRemote: false)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Who won the world cup in 1998?');
    await tester.tap(find.byTooltip('Solve'));
    await tester.pump();

    expect(find.textContaining('could not recognise'), findsOneWidget);
    expect(find.text('Worked solution'), findsNothing);
  });

  testWidgets('speed presets are offered', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: MathTutorScreen(enableRemote: false)));
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<double>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final speed in MathTutorAudioBar.speeds) {
      expect(find.text('${speed}x'), findsWidgets);
    }
  });

  testWidgets('picker preview and selection callbacks fire', (tester) async {
    String? selected;
    String? previewed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceAccentPicker(
            catalog: VoiceCatalogServiceForTest.catalog,
            selectedVoiceId: 'en-gb-female',
            onSelected: (id) => selected = id,
            onPreview: (id) => previewed = id,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Indian male'));
    expect(selected, 'en-in-male');

    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded).first);
    expect(previewed, isNotNull);
  });
}
