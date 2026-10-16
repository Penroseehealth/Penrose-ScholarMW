import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penrose_scholar/modules/chemistry_lab/screens/chemistry_lab_screen.dart';

void main() {
  testWidgets('chemistry lab preserves the reference photograph and offers a photo view', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChemistryLabScreen()));

    expect(find.text('Chemistry Laboratory. Photo Match'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      image.image,
      isA<AssetImage>().having(
        (asset) => asset.assetName,
        'assetName',
        'assets/chemistry_lab/reference/chemi_lab.jpeg',
      ),
    );
    expect(find.byTooltip('View sharp reference photo'), findsOneWidget);
    expect(find.textContaining('Burette'), findsNothing);
    expect(find.textContaining('titration'), findsNothing);

    await tester.tap(find.byTooltip('View sharp reference photo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Return to orbitable 3D laboratory'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
