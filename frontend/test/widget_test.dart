// Basic smoke test: unsigned-in app boots to the login gate.

import 'package:flutter_test/flutter_test.dart';

import 'package:trust_rummy_app/main.dart';

void main() {
  testWidgets('App boots to the login screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(const TrustRummyApp());
    await tester.pumpAndSettle();

    expect(find.text('Trust Rummy'), findsWidgets);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
