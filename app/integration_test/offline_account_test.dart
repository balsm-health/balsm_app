// Offline (device-only) account, end to end — the real app boot
// (`bootstrap()` in main_balsm.dart) with the API layer swapped for in-memory
// fakes through its `extraOverrides` seam, the same seam the Patrol suite uses.
//
//   1. no session → Device only → create → add a medication → relaunch →
//      unlock → go online; the server ADOPTS the device's id → the medication
//      is still listed and `balsm.user_id` is unchanged.
//   2. no session → Device only → create → add a medication → Profile →
//      "Remove this account from this phone" → Welcome; the keychain and the
//      database hold nothing of it, and a relaunch does not ask to unlock.
//   3. no session → Device only → create → add a medication → go online; the
//      email already has an account (is_new_user: false) → merge screen →
//      Merge → the medication is listed under the server's id.
//
// "Relaunch" inside one integration run: the first app's widget tree is torn
// down, its database closed and its ProviderContainer disposed, then
// `bootstrap()` runs again against the same keychain and the same on-disk
// SQLCipher database — a true process restart is not possible from inside a
// `flutter test` integration run.
//
// Fixtures are deliberately fake (example.com email, "Test med"); nothing here
// is PHI.
//
// Run on a booted iOS simulator (from app/):
//   fvm flutter test integration_test/offline_account_test.dart \
//     -d <simulator-udid> --flavor balsm \
//     --dart-define-from-file=env/balsm/dev.json \
//     --dart-define-from-file=env/shared.json

import 'dart:io';

import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:balsm_api/balsm_api.dart' show AuthTokensResponse, CancelToken, VerifyOtpRequest;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// The app's TextField is material_ui's, not Flutter's — match the same class.
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = 'offline.e2e@example.com';
const _password = 'offline-e2e-pass';
const _medName = 'Test med';

/// Verify-OTP answers the two go-online outcomes under test; every other call
/// is the shared [FakeAuthApi] (requestOtp and setPassword succeed).
class _GoOnlineAuthApi extends FakeAuthApi {
  _GoOnlineAuthApi({required this.adopt});

  /// true: the server kept the device's id (`adopted_client_id: true`).
  /// false: the email already had an account (`is_new_user: false`) whose id
  /// is [E2eFixture.userId].
  final bool adopt;

  /// The id the client offered on verify — must be the device's own id.
  String? offeredClientId;

  @override
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request, {CancelToken? cancelToken}) async {
    offeredClientId = request.clientAccountId;
    if (adopt) {
      return AuthTokensResponse(
        accessToken: E2eFixture.accessToken,
        refreshToken: E2eFixture.refreshToken,
        userId: request.clientAccountId!,
        isNewUser: true,
        adoptedClientId: true,
      );
    }
    return const AuthTokensResponse(
      accessToken: E2eFixture.accessToken,
      refreshToken: E2eFixture.refreshToken,
      userId: E2eFixture.userId,
      isNewUser: false,
    );
  }
}

/// Matches when either finder does.
Finder _either(Finder a, Finder b) =>
    find.byElementPredicate((e) => a.evaluate().contains(e) || b.evaluate().contains(e));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The container of the app currently running, captured through
  /// bootstrap's `onContainerReady` seam.
  ProviderContainer? container;

  const storage = SecureStorageWrapper.storage;

  /// Pumps frame by frame until [finder] matches (pumpAndSettle can't be used:
  /// the shell has looping animations and countdown timers).
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

  /// Waits until [finder] is hit-testable (route and tab transitions put
  /// overlays over it for a few frames), then taps it.
  Future<void> tapWhenReady(WidgetTester tester, Finder finder) async {
    await pumpUntil(tester, finder.hitTestable());
    await settle(tester, 3);
    await tester.tap(finder.hitTestable().last);
    await settle(tester, 3);
  }

  /// Stops the running app (if any) and releases its database, as a process
  /// exit would.
  Future<void> shutDown(WidgetTester tester) async {
    final c = container;
    if (c == null) return;
    await tester.pumpWidget(const SizedBox.shrink());
    await c.read(appDatabaseProvider).close();
    c.dispose();
    container = null;
  }

  /// Runs the real bootstrap. bootstrap() rewires FlutterError.onError and
  /// debugPrint for telemetry; both are put back so the test framework still
  /// sees (and fails on) framework errors and its invariants hold.
  Future<void> launch(WidgetTester tester, FakeAuthApi auth) async {
    final onError = FlutterError.onError;
    final print = debugPrint;
    await app.bootstrap(
      extraOverrides: e2eApiOverrides(auth: auth),
      onContainerReady: (c) async => container = c,
    );
    FlutterError.onError = onError;
    debugPrint = print;
    await settle(tester);
  }

  /// A first-install device: no keychain entries (so no session and no DB
  /// key), no prefs, no database file.
  Future<void> wipeDevice(WidgetTester tester) async {
    await shutDown(tester);
    await storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final docs = await getApplicationDocumentsDirectory();
    final db = File('${docs.path}/balsm.db');
    if (db.existsSync()) db.deleteSync();
  }

  Future<void> createDeviceOnlyAccount(WidgetTester tester) async {
    await pumpUntil(tester, _either(find.text('Skip').hitTestable(), find.text('Get started')));
    if (find.text('Skip').hitTestable().evaluate().isNotEmpty) {
      await tapWhenReady(tester, find.text('Skip').hitTestable());
      await pumpUntil(tester, find.text('Get started'));
    }
    await tapWhenReady(tester, find.text('Get started'));
    await pumpUntil(tester, find.text('Device only'));

    await tapWhenReady(tester, find.text('Device only'));
    await pumpUntil(tester, find.text('Account on this device'));

    await tester.enterText(find.byKey(const ValueKey('emailField')).hitTestable().first, _email);
    await tester.enterText(find.byKey(const ValueKey('passwordField')).hitTestable().first, _password);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
    await tapWhenReady(tester, find.text('Create account on device'));

    // Same disclosure gate as every sign-in: scroll the notice to the end,
    // then accept.
    await pumpUntil(tester, find.text('I agree & continue'));
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -2000));
      await settle(tester, 2);
    }
    await tapWhenReady(tester, find.text('I agree & continue'));
    await pumpUntil(tester, find.text('Meds').hitTestable());
    await settle(tester, 10);
  }

  Future<void> addMedication(WidgetTester tester) async {
    await tapWhenReady(tester, find.text('Meds'));
    await pumpUntil(tester, find.bySemanticsLabel('Add'));
    await tapWhenReady(tester, find.bySemanticsLabel('Add'));
    await pumpUntil(tester, find.widgetWithText(TextField, 'Medication name'));
    await tester.enterText(find.widgetWithText(TextField, 'Medication name'), _medName);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
    final addBtn = find.text('Add medication').last;
    await tester.ensureVisible(addBtn);
    await settle(tester, 2);
    await tester.tap(addBtn);
    await pumpUntil(tester, find.text('Medication added'));
    // The sheet closes itself after its confirmation.
    await pumpUntil(tester, find.text(_medName));
  }

  /// Profile → Go online → (prefilled email) Send code → six digits.
  Future<void> goOnline(WidgetTester tester) async {
    await tapWhenReady(tester, find.text('Profile'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Go online'), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 2);
    await tapWhenReady(tester, find.text('Go online'));
    await pumpUntil(tester, find.text('Send code'));
    // Prefilled from the device-only account.
    await pumpUntil(tester, find.widgetWithText(TextField, _email));
    await tapWhenReady(tester, find.text('Send code'));
    await pumpUntil(tester, find.text('Verify and go online'));
    final codeField = find.byWidgetPredicate((w) => w is TextField && w.maxLength == 6);
    await tester.enterText(codeField, '123456');
  }

  /// The medication's owner straight from the encrypted database.
  Future<List<String>> medOwners() async {
    final rows = await container!.read(appDatabaseProvider).customSelect(
        'SELECT user_id FROM medications WHERE name = ?',
        variables: [Variable.withString(_medName)]).get();
    return rows.map((r) => r.read<String>('user_id')).toList();
  }

  testWidgets('device-only → relaunch → unlock → go online (id adopted) keeps the data and the id', (tester) async {
    final auth = _GoOnlineAuthApi(adopt: true);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = await storage.read(key: 'balsm.user_id');
    expect(offlineId, isNotNull);
    expect(AccountMode.fromWire(await storage.read(key: kAccountModeKey)), AccountMode.deviceOnly);

    await addMedication(tester);
    expect(await medOwners(), [offlineId]);

    // ── Relaunch (same keychain, same database) ──
    await shutDown(tester);
    await launch(tester, auth);

    await pumpUntil(tester, find.text('Unlock Balsm'));
    await tester.enterText(find.byKey(const ValueKey('unlockPasswordField')), _password);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
    await tapWhenReady(tester, find.text('Unlock'));
    await pumpUntil(tester, find.text('Meds').hitTestable());
    await settle(tester, 10);

    await goOnline(tester);
    await pumpUntil(tester, find.text("You're online"));
    expect(auth.offeredClientId, offlineId);
    await tapWhenReady(tester, find.text('Done'));
    await settle(tester);

    expect(await storage.read(key: 'balsm.user_id'), offlineId);
    expect(AccountMode.fromWire(await storage.read(key: kAccountModeKey)), AccountMode.online);
    expect(await medOwners(), [offlineId]);

    await tapWhenReady(tester, find.text('Meds'));
    await pumpUntil(tester, find.text(_medName));
    expect(find.text(_medName), findsWidgets);

    await shutDown(tester);
  });

  testWidgets('device-only → Profile → remove from this phone → back to Welcome with nothing left', (tester) async {
    final auth = _GoOnlineAuthApi(adopt: true);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = await storage.read(key: 'balsm.user_id');
    await addMedication(tester);
    expect(await medOwners(), [offlineId]);

    await tapWhenReady(tester, find.text('Profile'));
    await settle(tester);
    // A device-only account has no Sign out: it is removed instead.
    await tester.scrollUntilVisible(find.text('Remove this account from this phone'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Sign out'), findsNothing);
    await settle(tester, 2);
    await tapWhenReady(tester, find.text('Remove this account from this phone'));
    await pumpUntil(tester, find.text('Remove this account and its data?'));
    await tapWhenReady(tester, find.text('Remove'));
    await pumpUntil(tester, find.text('Get started'));

    expect(await storage.read(key: 'balsm.user_id'), isNull);
    expect(await storage.read(key: kAccountModeKey), isNull);
    expect(await storage.read(key: 'balsm.offline.pw_hash'), isNull);
    expect(await storage.read(key: 'balsm.file_key.$offlineId'), isNull);
    expect(await medOwners(), isEmpty);

    // A relaunch lands on Welcome, not Unlock.
    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text('Get started'));
    expect(find.text('Unlock Balsm'), findsNothing);

    await shutDown(tester);
  });

  testWidgets('device-only → go online to an existing account → Merge keeps the data under its id', (tester) async {
    final auth = _GoOnlineAuthApi(adopt: false);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = await storage.read(key: 'balsm.user_id');
    expect(offlineId, isNotNull);
    expect(offlineId, isNot(E2eFixture.userId));

    await addMedication(tester);
    expect(await medOwners(), [offlineId]);

    await goOnline(tester);
    await pumpUntil(tester, find.text('This email already has a Balsm account'));
    expect(auth.offeredClientId, offlineId);

    await tapWhenReady(tester, find.text("Add this phone's data to my account"));
    // The existing account may still need the disclosure accepted on this
    // phone; accept it if the gate appears.
    await pumpUntil(tester, _either(find.text('Meds'), find.text('I agree & continue')));
    if (find.text('I agree & continue').evaluate().isNotEmpty) {
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -2000));
        await settle(tester, 2);
      }
      await tapWhenReady(tester, find.text('I agree & continue'));
      await pumpUntil(tester, find.text('Meds').hitTestable());
      await settle(tester, 10);
    }

    expect(await storage.read(key: 'balsm.user_id'), E2eFixture.userId);
    expect(await storage.read(key: 'balsm.pending_merge'), isNot('true'));
    expect(await medOwners(), [E2eFixture.userId]);

    await tapWhenReady(tester, find.text('Meds'));
    await settle(tester);
    await pumpUntil(tester, find.text(_medName));
    expect(find.text(_medName), findsWidgets);

    await shutDown(tester);
  });
}
