// Auth-UI integration test — renders the real auth flow on a device/simulator
// and drives navigation through the updated design (welcome → email+password
// → one-time-code). Self-contained: it pumps [AuthRouter] inside a
// ProviderScope + AppScope, so it needs no backend, flavor, or database — it
// verifies the widgets render and navigate on-device.
//
// Run on a booted iOS simulator:
//   flutter test integration_test/auth_ui_test.dart -d <simulator-udid>

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/auth_flow.dart';
import 'package:core/core.dart' show FlavorConfig, AppBrand, Flavor;
import 'package:material_ui/material_ui.dart';
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

  testWidgets('welcome → one screen serves everyone', (tester) async {
    final state = PatientAppState();
    await pumpAuth(tester, state);

    expect(find.text('Get started'), findsOneWidget);
    // The separate sign-in route is gone: sign-up and sign-in merged into one
    // email+password screen that falls back to an emailed code.
    expect(find.textContaining('I already have an account', findRichText: true), findsNothing);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Copy that names neither audience — which one this patient is, the screen
    // is not told and must not imply.
    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(find.text('Create your account'), findsNothing);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Forgot password?'), findsOneWidget);

    // DOB is NOT asked here. The age gate lives on profile setup, and asking
    // sooner would collect PHI before the account exists.
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
