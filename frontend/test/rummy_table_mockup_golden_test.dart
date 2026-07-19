// Renders the static Rummy table mockup screen (see
// `lib/screens/rummy_table_mockup_screen.dart`) at a phone-like resolution
// and saves it as a golden PNG — the easiest way to get a real screenshot
// of this screen out of a headless dev sandbox without needing an emulator
// or a live display, purely for design/layout review purposes.
//
// Note: `flutter test`'s Skia backend doesn't load real glyph outlines by
// default, so text renders as solid placeholder boxes in this PNG — the
// layout, colors, card shapes, and table geometry are otherwise accurate.
// For a screenshot with legible text, run the app directly
// (`flutter run -d chrome`, or on a device/emulator) and open the "Rummy
// Table — Visual Mockup" entry from the home screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_rummy_app/screens/rummy_table_mockup_screen.dart';

void main() {
  testWidgets('Rummy table mockup — visual review screenshot', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RummyTableMockupScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RummyTableMockupScreen),
      matchesGoldenFile('goldens/rummy_table_mockup.png'),
    );
  });
}
