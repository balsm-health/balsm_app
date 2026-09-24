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

  testWidgets('welcome → Get started opens sign-up, not sign-in', (tester) async {
    final state = PatientAppState();
    await pumpAuth(tester, state);

    expect(find.text('Get started'), findsOneWidget);

    // Get started sets AuthIntent.signUp, so this is account creation: no
    // "Forgot password?" (there is no account yet) and the button says so.
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Password'), findsWidgets);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);

    // DOB is NOT asked here. The age gate and date of birth live on profile
    // setup, and asking at sign-up would collect PHI before the account
    // exists.
    expect(find.text('Date of birth'), findsNothing);
  });

  testWidgets('welcome → I already have an account opens sign-in', (tester) async {
    final state = PatientAppState();
    await pumpAuth(tester, state);

    // One RichText — "I already have an account" plus an accented "Sign in" —
    // so find.text, which only sees whole Text widgets, matches nothing.
    await tester.tap(find.textContaining('I already have an account', findRichText: true));
    await tester.pumpAndSettle();

    // The same screen under AuthIntent.signIn: a returning patient, so
    // password recovery appears and the button changes.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
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
