// Shared steps for the demo-readiness e2e cycle (integration_test/patrol/demo).
//
// Every test boots the REAL app — `bootstrap()` from main_balsm.dart, no API
// fakes — against the local Cloud-mode API, in Arabic, with the Mother & Child
// and family-link flags forced on. Patrol's Android runner clears the app's
// data before each test (clearPackageData in android/app/build.gradle.kts), so
// each test signs up its own throwaway account and builds what it needs.
//
// Labels come from the Arabic i69n bundle, never typed out, so a copy change
// does not break a test. Gendered labels are matched in every gender form:
// they switch from `Gender.other` to `Gender.female` once the profile's sex
// is saved.
//
// pumpAndSettle is never used: the walkthrough, spinners and the QR scan line
// animate forever and several screens run 1 s timers (see
// integration_test/offline_account_test.dart for the same rule).
//
// Fixtures are invented (example.com addresses, "اختبار" names); nothing here
// is PHI.

import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/i18n/strings_ar.i69n.dart' as ar;
import 'package:app/balsm_app/prefs.dart';
import 'package:app/balsm_app/widgets/num_pad.dart';
import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
// The app's TextField is material_ui's, not Flutter's — match the same class.
import 'package:material_ui/material_ui.dart';
import 'package:patrol/patrol.dart';

/// The Arabic bundle every label is read from.
const t = ar.Strings_ar();

/// The local Dev API accepts this code for any address (DevOtpCodePolicy).
const devOtp = '123456';

const e2ePassword = 'E2eDemo!2026';

/// A fresh address per call, so every run signs up a new account.
String freshEmail(String tag) => 'e2e.$tag.${DateTime.now().millisecondsSinceEpoch}@example.com';

// ---------------------------------------------------------------------------
// Waiting and tapping
// ---------------------------------------------------------------------------

/// Pumps frame by frame until [finder] matches.
Future<void> pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> settle(WidgetTester tester, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Waits until [finder] is hit-testable (route and sheet transitions cover it
/// for a few frames), then taps the last match.
Future<void> tapWhenReady(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
  await pumpUntil(tester, finder.hitTestable(), timeout: timeout);
  await settle(tester, 3);
  await tester.tap(finder.hitTestable().last);
  await settle(tester, 5);
}

/// Matches when either finder does.
Finder either(Finder a, Finder b) =>
    find.byElementPredicate((e) => a.evaluate().contains(e) || b.evaluate().contains(e));

/// A gendered label in any of its forms.
Finder textAnyGender(String Function(Gender) label) {
  final forms = {for (final g in Gender.values) label(g)};
  return find.byWidgetPredicate((w) => w is Text && forms.contains(w.data));
}

/// Scrolls the screen's main scrollable until [finder] is built and visible.
Future<void> scrollTo(WidgetTester tester, Finder finder, {double delta = 250}) async {
  for (var i = 0; i < 40; i++) {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    final scrollables = find.byType(Scrollable).hitTestable();
    if (scrollables.evaluate().isEmpty) break;
    await tester.drag(scrollables.first, Offset(0, -delta));
    await settle(tester, 3);
  }
  await pumpUntil(tester, finder.hitTestable(), timeout: const Duration(seconds: 3));
}

Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tapWhenReady(tester, finder);
}

/// Types [text] into the hit-testable TextField whose hint is [hint].
Future<void> enterByHint(WidgetTester tester, String hint, String text) async {
  final field = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == hint);
  await scrollTo(tester, field);
  await tester.enterText(field.hitTestable().first, text);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, 3);
}

/// Taps the screen's back (or close) round button.
Future<void> goBack(WidgetTester tester) async {
  final back = either(find.bySemanticsLabel(t.common.a11y_back), find.bySemanticsLabel(t.common.a11y_close));
  await tapWhenReady(tester, back);
  await settle(tester, 5);
}

/// Taps the digits of [value] on the visible NumPad.
Future<void> typeOnNumPad(WidgetTester tester, String value) async {
  final pad = find.byType(NumPad).hitTestable();
  await pumpUntil(tester, pad);
  for (final ch in value.split('')) {
    await tester.tap(find.descendant(of: pad.first, matching: find.text(ch)).first);
    await settle(tester, 2);
  }
}

/// Picks a day in the app's date picker sheet: switches to [year] through the
/// year grid, or moves [monthsAhead] months forward, when given; taps [day]
/// when given; then confirms with [confirm]. With none of them the picker's
/// initial day is kept (it counts as selected).
Future<void> pickDate(WidgetTester tester, {int? year, int monthsAhead = 0, int? day, String? confirm}) async {
  final confirmLabel = confirm ?? t.onboarding.dob_confirm;
  await pumpUntil(tester, find.text(confirmLabel).hitTestable());
  // The app runs in Arabic (RTL): "next month" is the left-pointing chevron.
  for (var i = 0; i < monthsAhead; i++) {
    await tapWhenReady(tester, find.byIcon(Icons.chevron_left));
  }
  if (year != null) {
    // The header reads "<month> <year>"; tapping it opens the year grid.
    final header = find.byWidgetPredicate((w) => w is Text && RegExp(r' \d{4}$').hasMatch(w.data ?? ''));
    await tapWhenReady(tester, header);
    final y = find.text('$year');
    for (var i = 0; i < 30 && y.hitTestable().evaluate().isEmpty; i++) {
      final grid = find.byType(GridView).hitTestable();
      // Older years sit above the current one in the grid.
      await tester.drag(grid.first, const Offset(0, 300));
      await settle(tester, 2);
    }
    await tapWhenReady(tester, y);
  }
  if (day != null) {
    await tapWhenReady(tester, find.text('$day'));
  }
  await tapWhenReady(tester, find.text(confirmLabel));
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

/// Grants a native permission dialog if one is showing (location is asked as
/// soon as Home renders; the camera on the QR scan screen).
Future<void> grantPermissionIfAsked(PatrolIntegrationTester $) async {
  if (await $.platform.mobile.isPermissionDialogVisible(timeout: const Duration(seconds: 2))) {
    await $.platform.mobile.grantPermissionWhenInUse();
    await settle($.tester, 5);
  }
}

/// Boots the real app in Arabic with both Mother & Child flags forced on.
/// [skipWalkthrough] marks the walkthrough seen so the app opens on Welcome.
Future<void> bootApp(PatrolIntegrationTester $, {bool skipWalkthrough = true}) async {
  final prefs = PatientAppPrefs(await SharedPrefsKVDataSource.create());
  await prefs.setLang('ar');
  if (skipWalkthrough) await prefs.setWalkthroughSeen(true);

  // bootstrap() rewires FlutterError.onError and debugPrint for telemetry;
  // both are put back so the test still fails on framework errors.
  final onError = FlutterError.onError;
  final print = debugPrint;
  await app.bootstrap(
    onContainerReady: (c) async {
      // Overrides win over PostHog and the build's FEATURE_FLAGS, so the
      // demo features are on whatever remote config says.
      final flags = FeatureFlags.current!;
      await flags.setOverride(AppFlags.motherChild, true);
      await flags.setOverride(AppFlags.familyLink, true);
    },
  );
  FlutterError.onError = onError;
  debugPrint = print;
  await settle($.tester);
}

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

/// Welcome → Create account → email + password → code → privacy notice →
/// the app shell. Returns the address used.
Future<String> signUp(PatrolIntegrationTester $, {required String tag}) async {
  final tester = $.tester;
  final email = freshEmail(tag);
  await tapWhenReady(tester, find.text(t.onboarding.w_create), timeout: const Duration(seconds: 60));
  await pumpUntil(tester, find.byKey(const ValueKey('emailField')).hitTestable());
  await tester.enterText(find.byKey(const ValueKey('emailField')).hitTestable().first, email);
  await tester.enterText(find.byKey(const ValueKey('passwordField')).hitTestable().first, e2ePassword);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, 3);
  await tapWhenReady(tester, find.text(t.auth.signup_send));

  // The code field is a hidden six-digit TextField; the sixth digit verifies.
  final code = find.byWidgetPredicate((w) => w is TextField && w.maxLength == 6);
  await pumpUntil(tester, code, timeout: const Duration(seconds: 60));
  await tester.enterText(code.first, devOtp);
  await settle(tester);
  if (find.text(t.auth.verify).hitTestable().evaluate().isNotEmpty) {
    await tapWhenReady(tester, find.text(t.auth.verify));
  }
  await acceptDisclosure(tester);
  await waitForShell($);
  return email;
}

/// Scrolls the privacy notice to its end, then accepts it.
Future<void> acceptDisclosure(WidgetTester tester) async {
  await pumpUntil(tester, find.text(t.privacy.pv_agree), timeout: const Duration(seconds: 60));
  for (var i = 0; i < 8; i++) {
    await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -2000));
    await settle(tester, 2);
  }
  await tapWhenReady(tester, find.text(t.privacy.pv_agree));
}

/// Waits for the tab bar, granting the location prompt Home raises.
Future<void> waitForShell(PatrolIntegrationTester $) async {
  await pumpUntil($.tester, find.text(t.nav.tab_meds).hitTestable(), timeout: const Duration(seconds: 60));
  await grantPermissionIfAsked($);
  await settle($.tester);
}

/// Boot + sign up: the start of every test after onboarding's own.
Future<String> startSignedIn(PatrolIntegrationTester $, {required String tag, bool withProfile = true}) async {
  await bootApp($);
  final email = await signUp($, tag: tag);
  if (withProfile) await completeProfile($);
  return email;
}

const testFirstName = 'سلمى';
const testLastName = 'اختبار';

/// Profile → Account details: first and last name, a date of birth (the
/// picker's default, 25 years ago) and female, then save. The QR code and
/// gendered copy need these.
Future<void> completeProfile(PatrolIntegrationTester $) async {
  final tester = $.tester;
  await openTab(tester, t.nav.tab_profile);
  await scrollToAndTap(tester, find.text(t.profile.p_personal));
  await pumpUntil(tester, find.text(t.onboarding.pf_fname).hitTestable());

  // The name fields have no hints: they follow their labels in order.
  Finder fieldAfter(String label) => find
      .descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      )
      .first;
  await tester.enterText(fieldAfter(t.onboarding.pf_fname), testFirstName);
  await tester.enterText(fieldAfter(t.onboarding.pf_lname), testLastName);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, 3);

  await scrollToAndTap(tester, find.text(t.onboarding.dob_title));
  await pickDate(tester);
  await scrollToAndTap(tester, find.text(t.onboarding.pf_female));
  await scrollToAndTap(tester, find.text(t.profile.pd_save));
  await pumpUntil(tester, find.text(t.profile.pd_saved));
  await goBack(tester);
}

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

/// Taps a bottom tab by its label.
Future<void> openTab(WidgetTester tester, String label) async {
  await tapWhenReady(tester, find.text(label));
  await settle(tester, 5);
}

/// Fails the test if the framework raised an error since the last check — a
/// RenderFlex overflow on screen, most often.
void expectNoOverflowErrors(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: 'a framework error (layout overflow?) was raised: $exception');
}
