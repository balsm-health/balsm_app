// Offline (device-only) account, end to end — the real app boot
// (`bootstrap()` in main_balsm.dart) with the API layer swapped for in-memory
// fakes through its `extraOverrides` seam, the same seam the Patrol suite uses.
// Every launch also replaces the shared Dio client's HTTP adapter with a
// recorder that answers 503, so nothing reaches a real server and a test can
// see exactly which requests left the interceptor.
//
// Scenario matrix (one testWidgets each, numbered as in the matrix):
//    1. create → add a med → relaunch → unlock → the med is listed.
//    2. 5 wrong passwords → lockout countdown; the right password is refused
//       while locked (also across a relaunch); after the real 30 s wait it
//       unlocks.
//    3. a password shorter than 8 → the create button is disabled; nothing is
//       created.
//    4. go online, the server ADOPTS the id → same user_id, med listed, mode
//       online, SetPassword got the offline password, plaintext deleted, a
//       relaunch goes straight to the app.
//    5. go online, NEW account under a different id → rows and a vault file
//       re-keyed to the new id, both readable after a relaunch.
//    6. go online, email already has an account → Merge → med + file under the
//       target id, SetPassword never called, relaunch lands in the app.
//    7. same, Discard (second confirmation, Cancel first) → med, dose history
//       and file deleted, signed in to the target, relaunch lands in the app.
//    8. go online (existing account) → "killed" on the merge screen → relaunch
//       → Unlock first → merge screen → Merge finishes.
//    9. go online (new id) where the file re-key throws once → "killed" →
//       relaunch → offline data still visible → retry completes.
//   10. remove the device-only account from Profile → online sign-in on the
//       same install → authenticated requests really go out → relaunch lands
//       in the app.
//   11. Unlock → "Forgot password? Start over": Cancel at either confirmation
//       keeps everything; confirming both wipes it and lands on Welcome.
//   12. fresh install: offline keys in the keychain, app prefs empty → boot
//       wipes them and shows the walkthrough/welcome, not Unlock.
//   13. server-feature gate while device-only: QR share opens the Go-online
//       sheet, the care team opens normally, the Storage sheet shows
//       iCloud/Drive "Coming soon" and Balsm Cloud "Go online".
//   14. scenario 1's create + unlock screens in Arabic (RTL).
//
// Emulations (no real process exists to kill inside `flutter test`):
// "Relaunch" / "kill" — the first app's widget tree is torn down, its database
// closed and its ProviderContainer disposed, then `bootstrap()` runs again
// against the same keychain and the same on-disk SQLCipher database.
// "Fresh install" (12) — the same, with SharedPreferences cleared and the DB +
// vault files deleted while the keychain is kept (what an iOS uninstall does).
// "Re-key throws once" (9) — an empty `<vault>/<new id>/` directory is planted
// before going online, which makes `rekeyOwnerFiles` refuse
// ('target owner already has files'); it is removed before the retry.
// Attachments (5–7, 9, 11) are written straight through the app's own
// `userFileStoreProvider` and the dose event (7) straight into `dose_events`:
// neither has a UI path a test can drive without a camera / file picker.
//
// Fixtures are deliberately fake (example.com email, "Test med"); nothing here
// is PHI.
//
// Run (from app/):
//   iOS simulator:
//     fvm flutter test integration_test/offline_account_test.dart \
//       -d <simulator-udid> --flavor balsm \
//       --dart-define-from-file=env/balsm/dev.json \
//       --dart-define-from-file=env/shared.json
//   Android emulator:
//     fvm flutter test integration_test/offline_account_test.dart \
//       -d emulator-5554 --flavor balsm \
//       --dart-define-from-file=env/balsm/dev.json \
//       --dart-define-from-file=env/shared.json

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/balsm_app/i18n/strings.i69n.dart' as en;
import 'package:app/balsm_app/i18n/strings_ar.i69n.dart' as ar;
import 'package:app/balsm_app/kit.dart' show PButton, RoundBtn;
import 'package:app/balsm_app/prefs.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart' show CareTeamScreen;
import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:auth/auth.dart' show LockedUntil, offlineAccountServiceProvider;
import 'package:balsm_api/balsm_api.dart'
    show AuthTokensResponse, CancelToken, PasswordSignInRequest, SetPasswordRequest, VerifyOtpRequest;
import 'package:core/core.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
// The app's TextField is material_ui's, not Flutter's — match the same class.
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = 'offline.e2e@example.com';
const _password = 'offline-e2e-pass';
const _medName = 'Test med';

/// The id the fake server assigns in the "new account under a different id"
/// outcome (5, 9). Distinct from [E2eFixture.userId] (the existing account).
const _newServerId = '00000000-0000-0000-0000-0000000000b5';

final _attachment = Uint8List.fromList(utf8.encode('offline e2e attachment (not PHI)'));

const _en = en.Strings();
const _ar = ar.Strings_ar();

enum _Outcome { adopt, newId, existing }

/// Verify-OTP answers the go-online outcome under test and records what the
/// client sent; every other call is the shared [FakeAuthApi].
class _GoOnlineAuthApi extends FakeAuthApi {
  _GoOnlineAuthApi(this.outcome);

  final _Outcome outcome;

  /// The id the client offered on verify — must be the device's own id.
  String? offeredClientId;

  /// Every password SetPassword received, in order.
  final setPasswords = <String>[];

  /// Password sign-ins (scenario 10's online sign-in).
  int passwordSignIns = 0;

  @override
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request, {CancelToken? cancelToken}) async {
    offeredClientId = request.clientAccountId;
    switch (outcome) {
      case _Outcome.adopt:
        return AuthTokensResponse(
          accessToken: E2eFixture.accessToken,
          refreshToken: E2eFixture.refreshToken,
          userId: request.clientAccountId!,
          isNewUser: true,
          adoptedClientId: true,
        );
      case _Outcome.newId:
        return const AuthTokensResponse(
          accessToken: E2eFixture.accessToken,
          refreshToken: E2eFixture.refreshToken,
          userId: _newServerId,
          isNewUser: true,
          adoptedClientId: false,
        );
      case _Outcome.existing:
        return const AuthTokensResponse(
          accessToken: E2eFixture.accessToken,
          refreshToken: E2eFixture.refreshToken,
          userId: E2eFixture.userId,
          isNewUser: false,
        );
    }
  }

  @override
  Future<void> setPassword(SetPasswordRequest request, {CancelToken? cancelToken}) async {
    setPasswords.add(request.password);
  }

  @override
  Future<AuthTokensResponse> passwordSignIn(PasswordSignInRequest request, {CancelToken? cancelToken}) {
    passwordSignIns++;
    return super.passwordSignIn(request, cancelToken: cancelToken);
  }
}

/// Stands in for the network under the real Dio client (after its
/// interceptors): records each request and answers 503, so nothing reaches a
/// real server and the app sees an ordinary server outage.
class _RecordingAdapter implements dio.HttpClientAdapter {
  final requests = <dio.RequestOptions>[];

  @override
  Future<dio.ResponseBody> fetch(
      dio.RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return dio.ResponseBody.fromString('', 503);
  }

  @override
  void close({bool force = false}) {}
}

/// Matches when either finder does.
Finder _either(Finder a, Finder b) =>
    find.byElementPredicate((e) => a.evaluate().contains(e) || b.evaluate().contains(e));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The container of the app currently running, captured through
  /// bootstrap's `onContainerReady` seam.
  ProviderContainer? container;

  /// The recorder under the running app's Dio client.
  var network = _RecordingAdapter();

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

  /// Same, for an async condition (keychain / database state).
  Future<void> pumpUntilTrue(WidgetTester tester, Future<bool> Function() cond, String what,
      {Duration timeout = const Duration(seconds: 30), Future<String> Function()? diag}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (await cond()) return;
    }
    throw TestFailure('Timed out waiting for $what ${diag == null ? '' : await diag()}');
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
    network = _RecordingAdapter();
    await app.bootstrap(
      extraOverrides: e2eApiOverrides(auth: auth),
      onContainerReady: (c) async {
        container = c;
        c.read(balsmApiClientProvider).dio.httpClientAdapter = network;
      },
    );
    FlutterError.onError = onError;
    debugPrint = print;
    await settle(tester);
  }

  Future<Directory> vaultDir() async => Directory('${(await getApplicationDocumentsDirectory()).path}/vault');

  /// A first-install device: no keychain entries (so no session and no DB
  /// key), no prefs, no database file, no vault files.
  Future<void> wipeDevice(WidgetTester tester) async {
    await shutDown(tester);
    await storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final docs = await getApplicationDocumentsDirectory();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${docs.path}/balsm.db$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    final vault = await vaultDir();
    if (vault.existsSync()) vault.deleteSync(recursive: true);
  }

  /// Welcome (after the walkthrough, if shown) → Get started → Device only.
  Future<void> openDeviceOnlyForm(WidgetTester tester, {en.Strings t = _en}) async {
    final skip = find.text(t.walkthrough.wt_skip);
    final start = find.text(t.walkthrough.wt_start);
    await pumpUntil(tester, _either(skip.hitTestable(), start));
    if (skip.hitTestable().evaluate().isNotEmpty) {
      await tapWhenReady(tester, skip.hitTestable());
      await pumpUntil(tester, start);
    }
    await tapWhenReady(tester, start);
    await pumpUntil(tester, find.text(t.auth.mode_device));
    await tapWhenReady(tester, find.text(t.auth.mode_device));
    await pumpUntil(tester, find.text(t.auth.device_title));
  }

  Future<void> fillCredentials(WidgetTester tester, String password) async {
    await tester.enterText(find.byKey(const ValueKey('emailField')).hitTestable().first, _email);
    await tester.enterText(find.byKey(const ValueKey('passwordField')).hitTestable().first, password);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
  }

  /// Same disclosure gate as every sign-in: scroll the notice to the end,
  /// then accept.
  Future<void> acceptDisclosure(WidgetTester tester, {en.Strings t = _en}) async {
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -2000));
      await settle(tester, 2);
    }
    await tapWhenReady(tester, find.text(t.privacy.pv_agree));
  }

  /// Waits for the signed-in shell, accepting the disclosure gate on the way
  /// if this account has not accepted it on this phone yet.
  Future<void> enterAppAcceptingDisclosure(WidgetTester tester) async {
    await pumpUntil(tester, _either(find.text('Meds'), find.text('I agree & continue')));
    if (find.text('I agree & continue').evaluate().isNotEmpty) {
      await acceptDisclosure(tester);
    }
    await pumpUntil(tester, find.text('Meds').hitTestable());
    await settle(tester, 10);
  }

  Future<void> createDeviceOnlyAccount(WidgetTester tester, {en.Strings t = _en}) async {
    await openDeviceOnlyForm(tester, t: t);
    await fillCredentials(tester, _password);
    await tapWhenReady(tester, find.text(t.auth.device_create));
    await pumpUntil(tester, find.text(t.privacy.pv_agree));
    await acceptDisclosure(tester, t: t);
    await pumpUntil(tester, find.text(t.nav.tab_meds).hitTestable());
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

  /// The Meds tab lists the test medication.
  Future<void> expectMedListed(WidgetTester tester) async {
    await tapWhenReady(tester, find.text('Meds'));
    await settle(tester);
    await pumpUntil(tester, find.text(_medName));
    expect(find.text(_medName), findsWidgets);
  }

  /// Relaunch → Unlock → [password] → Unlock tapped.
  Future<void> submitUnlock(WidgetTester tester, String password, {en.Strings t = _en}) async {
    await pumpUntil(tester, find.text(t.auth.unlock_title));
    final editable =
        find.descendant(of: find.byKey(const ValueKey('unlockPasswordField')), matching: find.byType(EditableText));
    // A second entry into the same field after a refusal has been seen to
    // land nowhere; check the text actually arrived, and retype if not.
    for (var attempt = 0; attempt < 3; attempt++) {
      // Focus the field directly: after a refusal, showKeyboard's tap no
      // longer focuses it on the simulator and the typed text goes nowhere.
      tester.widget<EditableText>(editable).focusNode.requestFocus();
      await settle(tester, 3);
      await tester.enterText(editable, password);
      await settle(tester, 3);
      if (tester.widget<EditableText>(editable).controller.text == password) break;
    }
    expect(tester.widget<EditableText>(editable).controller.text.length, password.length,
        reason: 'password did not reach the unlock field');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
    await tapWhenReady(tester, find.text(t.auth.unlock_btn));
  }

  Future<void> unlock(WidgetTester tester) async {
    await submitUnlock(tester, _password);
    await pumpUntil(tester, find.text('Meds').hitTestable());
    await settle(tester, 10);
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

  AppDatabase db() => container!.read(appDatabaseProvider);

  /// The medication's owners straight from the encrypted database.
  Future<List<String>> medOwners() async {
    final rows = await db().customSelect('SELECT user_id FROM medications WHERE name = ?',
        variables: [Variable.withString(_medName)]).get();
    return rows.map((r) => r.read<String>('user_id')).toList();
  }

  Future<String> medId() async {
    final rows = await db()
        .customSelect('SELECT id FROM medications WHERE name = ?', variables: [Variable.withString(_medName)]).get();
    return rows.single.read<String>('id');
  }

  /// One dose-history row under the test medication.
  Future<void> addDoseEvent() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db().customStatement(
      'INSERT INTO dose_events (id, medication_id, scheduled_at, recorded_at, outcome) VALUES (?, ?, ?, ?, ?)',
      ['e2e-dose-1', await medId(), now, now, 'taken'],
    );
  }

  Future<int> doseEventCount() async {
    final rows = await db().customSelect("SELECT COUNT(*) AS n FROM dose_events WHERE id = 'e2e-dose-1'").get();
    return rows.single.read<int>('n');
  }

  UserFileStore files() => container!.read(userFileStoreProvider);

  Future<String> saveAttachment(String owner) =>
      files().save('e2e-attachment', _attachment, scope: UserId.value(owner));

  Future<Uint8List?> readAttachment(String path, {String? owner}) =>
      files().read(path, scope: owner == null ? null : UserId.value(owner));

  Future<bool> partitionExists(String owner) async => Directory('${(await vaultDir()).path}/$owner').exists();

  Future<String?> key(String k) => storage.read(key: k);

  Future<AccountMode> mode() async => AccountMode.fromWire(await key(kAccountModeKey));

  Future<int> lockoutFailures() async {
    final raw = await key('balsm.offline.lockout');
    if (raw == null) return 0;
    return (jsonDecode(raw) as Map<String, dynamic>)['failures'] as int;
  }

  Finder pButton(String label) => find.widgetWithText(PButton, label);

  // ── 1 ─────────────────────────────────────────────────────────────────────
  testWidgets('1. device-only create → med → relaunch → unlock → med listed', (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.adopt);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = await key('balsm.user_id');
    expect(offlineId, isNotNull);
    expect(await mode(), AccountMode.deviceOnly);

    await addMedication(tester);
    expect(await medOwners(), [offlineId]);

    // ── Relaunch (same keychain, same database) ──
    await shutDown(tester);
    await launch(tester, auth);
    await unlock(tester);
    await expectMedListed(tester);
    expect(await medOwners(), [offlineId]);
    // Device-only: nothing may have left the interceptor.
    expect(network.requests, isEmpty);

    await shutDown(tester);
  });

  // ── 2 ─────────────────────────────────────────────────────────────────────
  testWidgets('2. five wrong passwords lock out; right password refused while locked; unlocks after the wait',
      (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.adopt);
    await wipeDevice(tester);
    await launch(tester, auth);
    await createDeviceOnlyAccount(tester);
    await addMedication(tester);

    await shutDown(tester);
    await launch(tester, auth);

    Future<String> diag() async {
      final field = find.byKey(const ValueKey('unlockPasswordField'));
      final editable = find.descendant(of: field, matching: find.byType(EditableText));
      return '[failures=${await lockoutFailures()}, '
          'unlockEnabled=${tester.widget<PButton>(pButton('Unlock')).onTap != null}, '
          'fieldLen=${editable.evaluate().isEmpty ? 'n/a' : tester.widget<EditableText>(editable.first).controller.text.length}, '
          'wrongShown=${find.text('Wrong password.').evaluate().isNotEmpty}]';
    }

    for (var i = 1; i <= 4; i++) {
      await submitUnlock(tester, 'wrong-password-$i');
      await pumpUntilTrue(tester, () async => await lockoutFailures() >= i, 'failure $i recorded', diag: diag);
      expect(await lockoutFailures(), i);
      await pumpUntil(tester, find.text('Wrong password.'));
      // The screen clears the field after the keychain write lands; wait for
      // that (button disabled again) so the next entry is not wiped.
      await pumpUntilTrue(tester, () async => tester.widget<PButton>(pButton('Unlock')).onTap == null,
          'field cleared after attempt $i');
      await settle(tester, 3);
      expect(find.textContaining('Too many attempts'), findsNothing);
    }
    await submitUnlock(tester, 'wrong-password-5');
    await pumpUntil(tester, find.textContaining('Too many attempts. Try again in'));

    // Right password while locked: the button is disabled and the service
    // refuses it too.
    await tester.enterText(find.byKey(const ValueKey('unlockPasswordField')), _password);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
    expect(tester.widget<PButton>(pButton('Unlock')).onTap, isNull);
    await tester.tap(find.text('Unlock'), warnIfMissed: false);
    await settle(tester, 10);
    expect(find.text('Unlock Balsm'), findsOneWidget);
    expect(find.text('Meds').hitTestable(), findsNothing);
    expect(await container!.read(offlineAccountServiceProvider).unlock(_password), isA<LockedUntil>());

    // The lockout survives a relaunch: the countdown shows at once.
    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text('Unlock Balsm'));
    await pumpUntil(tester, find.textContaining('Too many attempts. Try again in'));

    // The real (first, 30 s) wait — the smallest the product allows.
    final gone = find.textContaining('Too many attempts');
    final end = DateTime.now().add(const Duration(seconds: 45));
    while (gone.evaluate().isNotEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(gone, findsNothing, reason: 'countdown did not end within 45 s');

    await unlock(tester);
    expect(await key('balsm.offline.lockout'), isNull);
    await expectMedListed(tester);

    await shutDown(tester);
  });

  // ── 3 ─────────────────────────────────────────────────────────────────────
  testWidgets('3. password shorter than 8 → create disabled, nothing created', (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.adopt);
    await wipeDevice(tester);
    await launch(tester, auth);

    await openDeviceOnlyForm(tester);
    await fillCredentials(tester, 'short7!');
    expect(tester.widget<PButton>(pButton('Create account on device')).onTap, isNull);
    await tester.tap(find.text('Create account on device'), warnIfMissed: false);
    await settle(tester, 10);
    expect(find.text('Account on this device'), findsOneWidget);
    expect(find.text('I agree & continue'), findsNothing);
    expect(await key('balsm.user_id'), isNull);
    expect(await key(kAccountModeKey), isNull);
    expect(await key('balsm.offline.pw_hash'), isNull);

    // 8 characters is the boundary: enabled (not tapped).
    await fillCredentials(tester, 'eight8ch');
    expect(tester.widget<PButton>(pButton('Create account on device')).onTap, isNotNull);

    await shutDown(tester);
  });

  // ── 4 ─────────────────────────────────────────────────────────────────────
  testWidgets('4. go online, id adopted → same id, med kept, online, SetPassword sent, no Unlock on relaunch',
      (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.adopt);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = await key('balsm.user_id');
    await addMedication(tester);

    await shutDown(tester);
    await launch(tester, auth);
    await unlock(tester);

    await goOnline(tester);
    await pumpUntil(tester, find.text("You're online"));
    expect(auth.offeredClientId, offlineId);
    await tapWhenReady(tester, find.text('Done'));
    await settle(tester);

    expect(await key('balsm.user_id'), offlineId);
    expect(await mode(), AccountMode.online);
    expect(auth.setPasswords, [_password]);
    expect(await key('balsm.offline.pw_plain'), isNull);
    expect(await key('balsm.offline.pw_hash'), isNull);
    expect(await medOwners(), [offlineId]);
    await expectMedListed(tester);

    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text('Meds').hitTestable());
    expect(find.text('Unlock Balsm'), findsNothing);
    await expectMedListed(tester);

    await shutDown(tester);
  });

  // ── 5 ─────────────────────────────────────────────────────────────────────
  testWidgets('5. go online, new account under a different id → rows and vault file re-keyed', (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.newId);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = (await key('balsm.user_id'))!;
    expect(offlineId, isNot(_newServerId));
    await addMedication(tester);
    final path = await saveAttachment(offlineId);
    expect(await readAttachment(path, owner: offlineId), _attachment);

    await goOnline(tester);
    await pumpUntil(tester, find.text("You're online"));
    expect(auth.offeredClientId, offlineId);
    await tapWhenReady(tester, find.text('Done'));
    await settle(tester);

    expect(await key('balsm.user_id'), _newServerId);
    expect(await mode(), AccountMode.online);
    expect(await key('balsm.offline.local_id'), isNull);
    expect(await medOwners(), [_newServerId]);
    expect(await key('balsm.file_key.$offlineId'), isNull);
    expect(await key('balsm.file_key.$_newServerId'), isNotNull);
    expect(await partitionExists(offlineId), isFalse);
    expect(await readAttachment(path, owner: _newServerId), _attachment);
    expect(auth.setPasswords, [_password]);
    await expectMedListed(tester);

    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text('Meds').hitTestable());
    expect(find.text('Unlock Balsm'), findsNothing);
    await expectMedListed(tester);
    // Read as the active (boot-session) user, no explicit scope.
    expect(container!.read(currentUserIdProvider)?.value, _newServerId);
    expect(await readAttachment(path), _attachment);

    await shutDown(tester);
  });

  // ── 6 ─────────────────────────────────────────────────────────────────────
  testWidgets('6. go online to an existing account → Merge keeps med + file under its id, no SetPassword',
      (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.existing);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = (await key('balsm.user_id'))!;
    expect(offlineId, isNot(E2eFixture.userId));
    await addMedication(tester);
    final path = await saveAttachment(offlineId);

    await goOnline(tester);
    await pumpUntil(tester, find.text('This email already has a Balsm account'));
    expect(auth.offeredClientId, offlineId);

    await tapWhenReady(tester, find.text("Add this phone's data to my account"));
    await enterAppAcceptingDisclosure(tester);

    expect(await key('balsm.user_id'), E2eFixture.userId);
    expect(await mode(), AccountMode.online);
    expect(await key('balsm.pending_merge'), isNot('true'));
    expect(await medOwners(), [E2eFixture.userId]);
    expect(await readAttachment(path, owner: E2eFixture.userId), _attachment);
    expect(await key('balsm.file_key.$offlineId'), isNull);
    expect(await partitionExists(offlineId), isFalse);
    expect(auth.setPasswords, isEmpty, reason: 'the existing account keeps its own password');
    expect(await key('balsm.offline.pw_plain'), isNull);
    await expectMedListed(tester);

    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text('Meds').hitTestable());
    expect(find.text('Unlock Balsm'), findsNothing);
    expect(find.text('This email already has a Balsm account'), findsNothing);
    await expectMedListed(tester);
    expect(await readAttachment(path), _attachment);
    expect(auth.setPasswords, isEmpty);

    await shutDown(tester);
  });

  // ── 7 ─────────────────────────────────────────────────────────────────────
  testWidgets('7. go online to an existing account → Discard (confirmed) deletes med, dose history and file',
      (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.existing);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = (await key('balsm.user_id'))!;
    await addMedication(tester);
    await addDoseEvent();
    expect(await doseEventCount(), 1);
    final path = await saveAttachment(offlineId);

    await goOnline(tester);
    await pumpUntil(tester, find.text('This email already has a Balsm account'));

    // Cancel at the confirmation removes nothing.
    await tapWhenReady(tester, find.text("Remove this phone's data"));
    await pumpUntil(tester, find.text('Remove the data on this phone?'));
    await tapWhenReady(tester, find.text('Cancel'));
    await settle(tester, 5);
    expect(find.text('This email already has a Balsm account'), findsOneWidget);
    expect(await medOwners(), [offlineId]);
    expect(await doseEventCount(), 1);
    expect(await readAttachment(path, owner: offlineId), _attachment);

    await tapWhenReady(tester, find.text("Remove this phone's data"));
    await pumpUntil(tester, find.text('Remove the data on this phone?'));
    await tapWhenReady(tester, find.text('Remove'));
    await enterAppAcceptingDisclosure(tester);

    expect(await key('balsm.user_id'), E2eFixture.userId);
    expect(await mode(), AccountMode.online);
    expect(await medOwners(), isEmpty);
    expect(await doseEventCount(), 0);
    expect(await key('balsm.file_key.$offlineId'), isNull);
    expect(await partitionExists(offlineId), isFalse);
    expect(auth.setPasswords, isEmpty);

    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text('Meds').hitTestable());
    expect(find.text('Unlock Balsm'), findsNothing);
    expect(find.text('This email already has a Balsm account'), findsNothing);
    expect(await medOwners(), isEmpty);

    await shutDown(tester);
  });

  // ── 8 ─────────────────────────────────────────────────────────────────────
  testWidgets('8. killed on the merge screen → relaunch → Unlock first → merge screen → Merge', (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.existing);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = (await key('balsm.user_id'))!;
    await addMedication(tester);

    await goOnline(tester);
    await pumpUntil(tester, find.text('This email already has a Balsm account'));
    expect(await key('balsm.pending_merge'), 'true');

    // ── "Kill" before choosing ──
    await shutDown(tester);
    await launch(tester, auth);

    await pumpUntil(tester, find.text('Unlock Balsm'));
    expect(find.text('This email already has a Balsm account'), findsNothing);
    await submitUnlock(tester, _password);
    await pumpUntil(tester, find.text('This email already has a Balsm account'));
    // Before the choice the offline rows are still the device's.
    expect(await medOwners(), [offlineId]);

    await tapWhenReady(tester, find.text("Add this phone's data to my account"));
    await enterAppAcceptingDisclosure(tester);

    expect(await key('balsm.user_id'), E2eFixture.userId);
    expect(await mode(), AccountMode.online);
    expect(await key('balsm.pending_merge'), isNot('true'));
    expect(await medOwners(), [E2eFixture.userId]);
    expect(auth.setPasswords, isEmpty);
    await expectMedListed(tester);

    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text('Meds').hitTestable());
    expect(find.text('Unlock Balsm'), findsNothing);

    await shutDown(tester);
  });

  // ── 9 ─────────────────────────────────────────────────────────────────────
  testWidgets('9. go online (new id) fails at the file re-key → relaunch shows the offline data → retry completes',
      (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.newId);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = (await key('balsm.user_id'))!;
    await addMedication(tester);
    final path = await saveAttachment(offlineId);

    // Make the vault re-key throw once: the target partition already exists.
    final blocker = Directory('${(await vaultDir()).path}/$_newServerId');
    await blocker.create(recursive: true);

    await goOnline(tester);
    await pumpUntil(tester, find.text("Couldn't go online right now. Try again."));
    // The server session was stored, the local data was not finished moving.
    expect(await key('balsm.user_id'), _newServerId);
    expect(await key('balsm.offline.local_id'), offlineId);
    expect(await mode(), AccountMode.deviceOnly);
    await blocker.delete(recursive: true);

    // Soft checks from here: report every broken expectation, not only the
    // first, so the whole resume path is visible.
    final problems = <String>[];
    void check(bool ok, String what) {
      if (!ok) problems.add(what);
    }

    // ── "Kill" mid go-online ──
    await shutDown(tester);
    await launch(tester, auth);
    await unlock(tester);
    check(container!.read(currentUserIdProvider)?.value == offlineId,
        'session id after relaunch is ${container!.read(currentUserIdProvider)?.value == _newServerId ? 'the server id' : 'not the pinned local id'}');
    final owners = await medOwners();
    check(
        owners.length == 1 && owners.single == offlineId,
        'after the failed attempt the med is owned by ${owners.isEmpty ? 'nobody' : owners.single == _newServerId ? 'the NEW server id' : 'another id'}, not the pinned local id');
    await tapWhenReady(tester, find.text('Meds'));
    await settle(tester, 20);
    check(find.text(_medName).evaluate().isNotEmpty, 'med NOT visible in Meds after relaunch (offline data hidden)');
    Uint8List? fileNow;
    try {
      fileNow = await readAttachment(path);
    } catch (_) {}
    check(fileNow != null && listEquals(fileNow, _attachment),
        'attachment not readable as the active user after relaunch');

    // ── Retry going online ──
    await goOnline(tester);
    await pumpUntil(tester, find.text("You're online"));
    await tapWhenReady(tester, find.text('Done'));
    await settle(tester);
    check(await key('balsm.user_id') == _newServerId, 'user_id after retry is not the server id');
    check(await mode() == AccountMode.online, 'mode after retry is not online');
    check(await key('balsm.offline.local_id') == null, 'local_id pin left behind after retry');
    final ownersAfter = await medOwners();
    check(ownersAfter.length == 1 && ownersAfter.single == _newServerId, 'med not owned by the server id after retry');
    check(await key('balsm.file_key.$offlineId') == null, 'offline file key left after retry');
    Uint8List? fileAfter;
    try {
      fileAfter = await readAttachment(path, owner: _newServerId);
    } catch (_) {}
    check(fileAfter != null && listEquals(fileAfter, _attachment),
        'attachment not readable under the server id after retry');
    await tapWhenReady(tester, find.text('Meds'));
    await settle(tester, 20);
    check(find.text(_medName).evaluate().isNotEmpty, 'med not visible after retry');

    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, _either(find.text('Meds').hitTestable(), find.text('Unlock Balsm')));
    check(find.text('Unlock Balsm').evaluate().isEmpty, 'relaunch after retry asks to Unlock');

    await shutDown(tester);
    expect(problems, isEmpty);
  });

  // ── 10 ────────────────────────────────────────────────────────────────────
  testWidgets('10. remove device-only account → online sign-in on the same install → requests go out', (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.adopt);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = (await key('balsm.user_id'))!;
    await addMedication(tester);
    expect(await medOwners(), [offlineId]);

    // While device-only an authenticated call is refused before the network.
    Object? deviceOnlyError;
    try {
      await container!.read(careTeamApiProvider).pull(healthProfileId: 'e2e-profile');
    } catch (e) {
      deviceOnlyError = e;
    }
    expect(deviceOnlyError, isNotNull);
    expect(network.requests, isEmpty);

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

    expect(await key('balsm.user_id'), isNull);
    expect(await key(kAccountModeKey), isNull);
    expect(await key('balsm.offline.pw_hash'), isNull);
    expect(await key('balsm.file_key.$offlineId'), isNull);
    expect(await medOwners(), isEmpty);

    // ── Online sign-in on the same install ──
    await tapWhenReady(tester, find.text('Get started'));
    await pumpUntil(tester, find.text('Device only'));
    await fillCredentials(tester, 'online-e2e-pass');
    await tapWhenReady(tester, find.text('Continue'));
    await enterAppAcceptingDisclosure(tester);
    expect(auth.passwordSignIns, 1);
    expect(await key('balsm.user_id'), E2eFixture.userId);
    expect(await mode(), AccountMode.online);

    network.requests.clear();
    try {
      await container!.read(careTeamApiProvider).pull(healthProfileId: 'e2e-profile');
    } catch (_) {
      // The recorder answers 503; only the request matters.
    }
    final sent = network.requests.where((r) => r.path.contains('care-team') || r.path.contains('care_team')).toList();
    expect(sent, isNotEmpty, reason: 'the care-team request never reached the network layer');
    expect(
        sent.first.headers['Authorization'] ?? sent.first.headers['authorization'], 'Bearer ${E2eFixture.accessToken}');

    // A relaunch reaches the app, not Unlock.
    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, _either(find.text('Meds').hitTestable(), find.text('Unlock Balsm')));
    expect(find.text('Unlock Balsm'), findsNothing);
    expect(find.text('Get started'), findsNothing);

    await shutDown(tester);
  });

  // ── 11 ────────────────────────────────────────────────────────────────────
  testWidgets('11. Unlock → Forgot password → Start over: Cancel keeps everything, two confirmations wipe it',
      (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.adopt);
    await wipeDevice(tester);
    await launch(tester, auth);

    await createDeviceOnlyAccount(tester);
    final offlineId = (await key('balsm.user_id'))!;
    await addMedication(tester);
    final path = await saveAttachment(offlineId);

    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text('Unlock Balsm'));

    Future<void> expectIntact() async {
      expect(find.text('Unlock Balsm'), findsOneWidget);
      expect(await key('balsm.user_id'), offlineId);
      expect(await key('balsm.offline.pw_hash'), isNotNull);
      expect(await mode(), AccountMode.deviceOnly);
      expect(await medOwners(), [offlineId]);
      expect(await readAttachment(path, owner: offlineId), _attachment);
    }

    // Cancel at the first confirmation.
    await tapWhenReady(tester, find.text('Forgot password? Start over'));
    await pumpUntil(tester, find.text(_en.auth.unlock_forgot_confirm_body));
    await tapWhenReady(tester, find.text('Cancel'));
    await settle(tester, 5);
    expect(find.text(_en.auth.unlock_forgot_confirm_body), findsNothing);
    await expectIntact();

    // Confirm the first, cancel the second.
    await tapWhenReady(tester, find.text('Forgot password? Start over'));
    await pumpUntil(tester, find.text(_en.auth.unlock_forgot_confirm_body));
    await tapWhenReady(tester, find.text('Remove'));
    await pumpUntil(tester, find.text('Remove this account and its data?'));
    await tapWhenReady(tester, find.text('Cancel'));
    await settle(tester, 5);
    expect(find.text('Remove this account and its data?'), findsNothing);
    await expectIntact();

    // Confirm both.
    await tapWhenReady(tester, find.text('Forgot password? Start over'));
    await pumpUntil(tester, find.text(_en.auth.unlock_forgot_confirm_body));
    await tapWhenReady(tester, find.text('Remove'));
    await pumpUntil(tester, find.text('Remove this account and its data?'));
    await tapWhenReady(tester, find.text('Remove'));
    await pumpUntil(tester, find.text('Get started'));

    expect(await key('balsm.user_id'), isNull);
    expect(await key(kAccountModeKey), isNull);
    expect(await key('balsm.offline.pw_hash'), isNull);
    expect(await key('balsm.offline.pw_plain'), isNull);
    expect(await key('balsm.offline.email'), isNull);
    expect(await key('balsm.file_key.$offlineId'), isNull);
    expect(await partitionExists(offlineId), isFalse);
    expect(await medOwners(), isEmpty);

    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text('Get started'));
    expect(find.text('Unlock Balsm'), findsNothing);

    await shutDown(tester);
  });

  // ── 12 ────────────────────────────────────────────────────────────────────
  testWidgets('12. fresh install with offline keys left in the keychain → wiped, Welcome not Unlock', (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.adopt);
    await wipeDevice(tester);
    await launch(tester, auth);
    await createDeviceOnlyAccount(tester);
    final offlineId = (await key('balsm.user_id'))!;
    await addMedication(tester);
    await saveAttachment(offlineId);
    await shutDown(tester);

    // "Uninstall + reinstall" on iOS: the keychain survives, the app's prefs,
    // database and files do not.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final docs = await getApplicationDocumentsDirectory();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final f = File('${docs.path}/balsm.db$suffix');
      if (f.existsSync()) f.deleteSync();
    }
    final vault = await vaultDir();
    if (vault.existsSync()) vault.deleteSync(recursive: true);
    expect(await key('balsm.offline.pw_hash'), isNotNull);
    expect(await mode(), AccountMode.deviceOnly);

    await launch(tester, auth);
    await pumpUntil(tester, _either(find.text('Skip').hitTestable(), find.text('Get started')));
    expect(find.text('Unlock Balsm'), findsNothing);

    expect(await key('balsm.user_id'), isNull);
    expect(await key(kAccountModeKey), isNull);
    expect(await key('balsm.offline.pw_hash'), isNull);
    expect(await key('balsm.offline.pw_plain'), isNull);
    expect(await key('balsm.offline.email'), isNull);
    expect(await key('balsm.file_key.$offlineId'), isNull);

    await shutDown(tester);
  });

  // ── 13 ────────────────────────────────────────────────────────────────────
  testWidgets('13. device-only gate: QR share → Go online sheet; care team opens; Storage shows the cloud rows',
      (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.adopt);
    await wipeDevice(tester);
    await launch(tester, auth);
    await createDeviceOnlyAccount(tester);

    await tapWhenReady(tester, find.text('Profile'));
    await settle(tester);

    // QR share (app-bar button) → the Go-online sheet, not the QR.
    final qr = find.byWidgetPredicate((w) => w is RoundBtn && w.icon == LucideIcons.qrCode);
    await tapWhenReady(tester, qr);
    await pumpUntil(tester, find.text('Send code'));
    expect(find.text('Go online'), findsWidgets);
    Navigator.of(tester.element(find.text('Send code'))).pop();
    await settle(tester, 10);
    expect(find.text('Send code'), findsNothing);
    expect(await mode(), AccountMode.deviceOnly);

    // Care team stays open to a device-only account.
    await tester.scrollUntilVisible(find.text('Care team'), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 2);
    await tapWhenReady(tester, find.text('Care team'));
    await pumpUntil(tester, find.byType(CareTeamScreen));
    await settle(tester, 5);
    expect(find.text('Send code'), findsNothing);
    Navigator.of(tester.element(find.byType(CareTeamScreen))).pop();
    await settle(tester, 10);

    // Storage & sync: iCloud / Google Drive "Coming soon", Balsm Cloud "Go online".
    await tester.scrollUntilVisible(find.text('Storage & sync'), -200, scrollable: find.byType(Scrollable).first);
    await settle(tester, 2);
    await tapWhenReady(tester, find.text('Storage & sync'));
    await pumpUntil(tester, find.text('Balsm Cloud'));
    await settle(tester, 5);
    Finder rowOf(String label) => find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    for (final label in ['iCloud', 'Google Drive']) {
      expect(find.descendant(of: rowOf(label), matching: find.text('Coming soon')), findsOneWidget, reason: label);
    }
    expect(find.descendant(of: rowOf('Balsm Cloud'), matching: find.text('Go online')), findsOneWidget);
    await tester.ensureVisible(find.text('Balsm Cloud'));
    await settle(tester, 2);
    await tapWhenReady(tester, find.text('Balsm Cloud'));
    await pumpUntil(tester, find.text('Send code'));

    await shutDown(tester);
  });

  // ── 14 ────────────────────────────────────────────────────────────────────
  testWidgets('14. Arabic (RTL): device-only create and unlock screens render Arabic strings', (tester) async {
    final auth = _GoOnlineAuthApi(_Outcome.adopt);
    await wipeDevice(tester);
    await PatientAppPrefs(await SharedPrefsKVDataSource.create()).setLang('ar');
    await launch(tester, auth);

    final a = _ar.auth;
    final e = _en.auth;
    // No key falls back to English (Strings_ar extends Strings).
    for (final (arText, enText) in [
      (a.mode_device, e.mode_device),
      (a.mode_online, e.mode_online),
      (a.device_title, e.device_title),
      (a.device_help, e.device_help),
      (a.device_pw_label, e.device_pw_label),
      (a.device_warning, e.device_warning),
      (a.device_create, e.device_create),
      (a.unlock_title, e.unlock_title),
      (a.unlock_help, e.unlock_help),
      (a.unlock_btn, e.unlock_btn),
      (a.unlock_forgot, e.unlock_forgot),
      (a.pw_label, e.pw_label),
    ]) {
      expect(arText, isNot(enText));
    }

    await openDeviceOnlyForm(tester, t: _ar);
    for (final s in [a.device_title, a.device_help, a.device_pw_label, a.device_warning, a.device_create]) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(Directionality.of(tester.element(find.text(a.device_title))), TextDirection.rtl);
    expect(find.text(e.device_title), findsNothing);

    await fillCredentials(tester, _password);
    await tapWhenReady(tester, find.text(a.device_create));
    await pumpUntil(tester, find.text(_ar.privacy.pv_agree));
    await acceptDisclosure(tester, t: _ar);
    await pumpUntil(tester, find.text(_ar.nav.tab_meds).hitTestable());
    expect(await mode(), AccountMode.deviceOnly);

    await shutDown(tester);
    await launch(tester, auth);
    await pumpUntil(tester, find.text(a.unlock_title));
    for (final s in [a.unlock_title, a.unlock_help, a.unlock_btn, a.unlock_forgot, a.device_warning, a.pw_label]) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    expect(Directionality.of(tester.element(find.text(a.unlock_title))), TextDirection.rtl);
    expect(find.text(e.unlock_title), findsNothing);

    await submitUnlock(tester, _password, t: _ar);
    await pumpUntil(tester, find.text(_ar.nav.tab_meds).hitTestable());

    await shutDown(tester);
  });
}
