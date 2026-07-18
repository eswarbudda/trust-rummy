// Basic smoke test: the app boots and lands on the dev-tools launcher screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trust_rummy_app/main.dart';

void main() {
  testWidgets('App boots to the dev-tools home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TrustRummyApp());

    expect(find.text('Trust Rummy — Dev Tools'), findsOneWidget);
    expect(find.byIcon(Icons.videogame_asset), findsOneWidget);
  });
}
