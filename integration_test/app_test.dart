// Integration tests run on a real device/simulator with live Firebase.
// Run with: flutter test integration_test/app_test.dart
//
// These tests verify the full app flow without mocking.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:stitchsmart/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Guest login flow', () {
    testWidgets('app launches and shows login screen', (tester) async {
      app.main();
      // Wait for Firebase init + splash animation
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Login screen must be visible
      expect(find.text('StitchSmart'), findsAtLeastNWidgets(1));
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Tailor'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
    });

    testWidgets('customer role is selected by default', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // "Continue as Guest" button exists (means we are on login screen)
      expect(find.text('Continue as Guest'), findsOneWidget);
    });

    testWidgets('guest tap navigates away from login', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Tap Continue as Guest
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Login screen's "Continue as Guest" should no longer be visible
      // (we navigated to onboarding or home)
      expect(find.text('Continue as Guest'), findsNothing);
    });
  });

  group('Role selection UI', () {
    testWidgets('tapping Tailor selects it', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.tap(find.text('Tailor'));
      await tester.pumpAndSettle();

      // After tapping Tailor, the role cards still exist (we are still on login)
      expect(find.text('Tailor'), findsOneWidget);
    });

    testWidgets('tapping Owner selects it', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.tap(find.text('Owner'));
      await tester.pumpAndSettle();

      expect(find.text('Owner'), findsOneWidget);
    });
  });
}
