// Auth-UI integration test — renders the real auth flow on a device/simulator
// and drives navigation through the updated design (welcome → email+password
// → one-time-code). Self-contained: it pumps [AuthRouter] inside a
// ProviderScope + AppScope, so it needs no backend, flavor, or database — it
// verifies the widgets render and navigate on-device.
//
// Run on a booted iOS simulator:
//   flutter test integration_test/auth_ui_test.dart -d <simulator-udid>

import 'package:app/patient_app/app_state.dart';
import 'package:app/patient_app/screens/auth_flow.dart';
import 'package:core/core.dart' show FlavorConfig, AppBrand, Flavor;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.dev));

  Future<void> pumpAuth(WidgetTester tester, PatientAppState state) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        // The app shell provides a Material/Scaffold ancestor for the auth
        // screens' TextFields; mirror that here.
        home: Scaffold(
          body: AppScope(state: state, child: const AuthRouter()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('welcome → email+password → one-time-code renders + navigates', (tester) async {
    final state = PatientAppState();
    await pumpAuth(tester, state);

    // 1. Welcome screen.
    expect(find.text('Get started'), findsOneWidget);

    // 2. Get started → sign-in screen (email + password is the default mode).
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Password'), findsWidgets);
    expect(find.text('Use a one-time code instead'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget); // primary button label

    // 3. Switch to the one-time-code path → password field goes away, and DOB
    //    is NOT asked here (design-aligned: the age gate + DOB live on profile
    //    setup for new accounts). The toggle sits below the fold, so scroll it
    //    into view before tapping.
    await tester.ensureVisible(find.text('Use a one-time code instead'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use a one-time code instead'));
    await tester.pumpAndSettle();
    expect(find.text('Use a password instead'), findsOneWidget);
    expect(find.text('Date of birth'), findsNothing);
  });

  testWidgets('welcome shows the language pill and toggles AR ⇄ EN', (tester) async {
    final state = PatientAppState();
    await pumpAuth(tester, state);

    // Pill shows the OTHER language (Arabic) while in English.
    expect(find.text('العربية'), findsOneWidget);
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    // Now Arabic; pill offers English.
    expect(find.text('English'), findsOneWidget);
  });
}
