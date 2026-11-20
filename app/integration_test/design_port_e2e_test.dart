// Design-port features (PRs #161–#164), end to end — the real app boot
// (`bootstrap()` in main_balsm.dart) with the API layer swapped for in-memory
// fakes through its `extraOverrides` seam, exactly as offline_account_test.dart
// does. Every launch also puts a recorder under the shared Dio client that
// answers 503, so nothing reaches a real server.
//
// Scenario matrix (one testWidgets each):
//   1. Edit a logged reading (#161): device-only account → quick-log a blood
//      pressure → that day's records → tap it → "Edit · Blood pressure",
//      prefilled → change → Save → the day shows the new values; the ⋮ menu
//      has Edit above Delete; "Delete this entry" asks before deleting.
//   2. Edit a record (#161): add a lab record (no file) → open it → pencil →
//      "Edit · Lab test" prefilled (title, type, date, time, tags) → change the
//      title and a tag → "Save changes" → "Changes saved" → the detail shows
//      it; the records list row has the date on its own line. Arabic (RTL)
//      screenshots of the detail and the edit sheet.
//   3. Family member health (#163): add a wife (adult, consent step) →
//      member screen → Medical profile: blood type, an allergy, a condition,
//      save, reopen → persisted → Trends tile → member Trends → Pregnancy tile
//      → start tracking → her pregnancy screen. Arabic (RTL) screenshots of the
//      member screen and the medical profile.
//   4. Attribution (#162): a record and a medication whose history holds an
//      event by a family member, written straight through the app's data
//      sources (no UI creates such entries yet) → "By …" chip on the records
//      list, the record detail and the Meds list → tap → "Edit history" sheet
//      with the lock line → edit the record in the UI → "You edited this".
//   5. Maintenance (#164), the maintenance API faked through the same override
//      seam: readonly → strip above the tab bar, Details sheet, quick log and
//      add record say "This is paused during maintenance"; block → full-screen
//      page with only the emergency card, the emergency call and Check again,
//      and the emergency card opens; off → the normal app. An erroring
//      maintenance endpoint pauses nothing.
//
// Mother & Child (scenario 3) is off by default; the dev flavour allows a
// Dev Config override, which the test sets through `FeatureFlags.current` —
// the same switch a tester flips by hand.
//
// Device location is overridden to "denied" so Home's Nearby never raises the
// native iOS location prompt, which would cover the screen.
//
// Fixtures are deliberately fake ("Test record", "Test Spouse", "Test
// allergen", example.com); nothing here is PHI.
//
// Run (from app/), iOS simulator, screenshots as <dir>/NN-step.png:
//   integration_test/simctl_shot_watcher.sh <simulator-udid> <dir> &
//   fvm flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/design_port_e2e_test.dart \
//     -d <simulator-udid> --flavor balsm \
//     --dart-define-from-file=env/balsm/dev.json \
//     --dart-define-from-file=env/shared.json
//   kill %1
// The watcher takes each picture with `xcrun simctl io screenshot` (see
// `snap` below). Without it the binding's own capture is used and
// SCREENSHOT_DIR=<dir> on `flutter drive` saves those — on the iOS simulator
// they have come back blank, hence the watcher.
// `fvm flutter test integration_test/design_port_e2e_test.dart -d <udid> …`
// with the same defines runs it too. `--dart-define=E2E_ONLY=3` runs one
// scenario.

import 'dart:io';
import 'dart:typed_data';

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/i18n/strings.i69n.dart' as en;
import 'package:app/balsm_app/i18n/strings_ar.i69n.dart' as ar;
import 'package:app/balsm_app/kit.dart' show PButton, PCard, RoundBtn;
import 'package:app/balsm_app/maintenance/maintenance_controller.dart';
import 'package:app/balsm_app/maintenance/maintenance_widgets.dart';
import 'package:app/balsm_app/screens/checkin_shared.dart' show CheckInDayRow;
import 'package:app/balsm_app/screens/day_records_screen.dart';
import 'package:app/balsm_app/screens/family/family_kit.dart' show FamilyTile;
import 'package:app/balsm_app/care/care_entity.dart' show DeviceLocationIssue, deviceLocationProvider;
import 'package:app/balsm_app/screens/family/member_medical_screen.dart';
import 'package:app/balsm_app/screens/pregnancy/pregnancy_screen.dart';
import 'package:app/balsm_app/screens/own_card_screen.dart' show OwnCardScreen;
import 'package:app/balsm_app/screens/records_detail.dart' show RecordDetailScreen;
import 'package:app/balsm_app/screens/records_screen.dart' show RecordsScreen, formatRecordDate;
import 'package:app/balsm_app/screens/trends_screen.dart';
import 'package:app/balsm_app/widgets/entry_attribution.dart';
import 'package:app/balsm_app/widgets/num_pad.dart';
import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:balsm_api/balsm_api.dart' show ApiException;
import 'package:core/core.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
// The app's TextField is material_ui's, not Flutter's — match the same class.
import 'package:material_ui/material_ui.dart';
import 'package:medications/medications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = 'design.e2e@example.com';
const _password = 'design-e2e-pass';
const _medName = 'Test med';
const _recordTitle = 'Test record';
const _recordEdited = 'Test record edited';
const _memberName = 'Test Spouse';
const _memberShort = 'Test';
const _allergen = 'Test allergen';
const _condition = 'Test condition';
const _relative = 'Test Relative';

const _en = en.Strings();
const _ar = ar.Strings_ar();

/// `--dart-define=E2E_ONLY=<n>` runs scenario n alone.
const _only = int.fromEnvironment('E2E_ONLY');
bool _skip(int n) => _only != 0 && _only != n;

/// Stands in for the network under the real Dio client: records each request
/// and answers 503 (see offline_account_test.dart).
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

Finder _roundBtn(String label) => find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == label);

Finder _pButton(String label) => find.widgetWithText(PButton, label);

/// The tab bar's centre "+" (the shell's private `_QuickLog`).
final _quickLogFab = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_QuickLog');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer? container;
  var network = _RecordingAdapter();
  const storage = SecureStorageWrapper.storage;

  /// What is on screen, for a timeout message (test fixtures only — no PHI).
  String visibleTexts() {
    final texts = find
        .byType(Text)
        .hitTestable()
        .evaluate()
        .map((e) => (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText())
        .whereType<String>()
        .where((t) => t.trim().isNotEmpty)
        .toSet()
        .take(60)
        .toList();
    return texts.join(' | ');
  }

  /// Pumps frame by frame until [finder] matches (the shell has looping
  /// animations, so pumpAndSettle never returns).
  Future<void> pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $finder\nOn screen: ${visibleTexts()}');
  }

  Future<void> pumpUntilGone(WidgetTester tester, Finder finder,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isEmpty) return;
    }
    throw TestFailure('Still showing $finder after $timeout\nOn screen: ${visibleTexts()}');
  }

  Future<void> pumpUntilTrue(WidgetTester tester, Future<bool> Function() cond, String what,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (await cond()) return;
    }
    throw TestFailure('Timed out waiting for $what\nOn screen: ${visibleTexts()}');
  }

  Future<void> settle(WidgetTester tester, [int frames = 10]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Waits until [finder] is hit-testable, then taps it.
  Future<void> tapWhenReady(WidgetTester tester, Finder finder) async {
    await pumpUntil(tester, finder.hitTestable());
    await settle(tester, 3);
    await tester.tap(finder.hitTestable().last);
    await settle(tester, 3);
  }

  /// Scrolls the topmost match of [finder] (a sheet over a screen) on screen.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await pumpUntil(tester, finder);
    await tester.ensureVisible(finder.last);
    await settle(tester, 3);
  }

  /// Saves a screenshot as `<name>.png`.
  ///
  /// On the iOS simulator the binding's own capture came back blank white
  /// once some screens had been shown, so a host-side watcher takes the
  /// picture with `xcrun simctl io <udid> screenshot`: the test writes the
  /// name to `Documents/e2e_shot/request` (the simulator's Documents folder is
  /// a host folder) and waits for the watcher's `done-<name>`. Without a
  /// watcher (no `watching` file) it falls back to the binding, whose images
  /// `flutter drive` hands to test_driver/integration_test.dart.
  Future<void> snap(WidgetTester tester, String name) async {
    await settle(tester, 4);
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/e2e_shot');
    if (File('${dir.path}/watching').existsSync()) {
      final done = File('${dir.path}/done-$name');
      if (done.existsSync()) done.deleteSync();
      File('${dir.path}/request').writeAsStringSync(name);
      final end = DateTime.now().add(const Duration(seconds: 15));
      while (!done.existsSync() && DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (done.existsSync()) return;
      debugPrint('screenshot $name: host watcher did not answer');
      return;
    }
    try {
      await binding.takeScreenshot(name);
    } catch (e) {
      debugPrint('screenshot $name not taken: $e');
    }
    await settle(tester, 1);
  }

  Future<void> shutDown(WidgetTester tester) async {
    final c = container;
    if (c == null) return;
    await tester.pumpWidget(const SizedBox.shrink());
    await c.read(appDatabaseProvider).close();
    c.dispose();
    container = null;
  }

  Future<void> launch(WidgetTester tester, {FakeMaintenanceApi? maintenance}) async {
    final onError = FlutterError.onError;
    final print = debugPrint;
    network = _RecordingAdapter();
    await app.bootstrap(
      extraOverrides: [
        ...e2eApiOverrides(auth: FakeAuthApi(), maintenance: maintenance),
        // Hermetic: the release manifest is not fetched from the web host.
        maintenanceNoticeSourceProvider.overrideWithValue(FakeManifestMaintenanceSource()),
        // No device location: Home's "Nearby" would otherwise raise the iOS
        // location prompt, a native alert that covers every screenshot.
        deviceLocationProvider.overrideWith((ref) async => (position: null, issue: DeviceLocationIssue.denied)),
      ],
      onContainerReady: (c) async {
        container = c;
        c.read(balsmApiClientProvider).dio.httpClientAdapter = network;
      },
    );
    FlutterError.onError = onError;
    debugPrint = print;
    await settle(tester);
  }

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
    final vault = Directory('${docs.path}/vault');
    if (vault.existsSync()) vault.deleteSync(recursive: true);
  }

  PatientAppState appState() => container!.read(patientAppStateProvider);

  Future<void> acceptDisclosure(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, -2000));
      await settle(tester, 2);
    }
    await tapWhenReady(tester, find.text(_en.privacy.pv_agree));
  }

  /// Walkthrough → Get started → Device only → create → disclosure → app.
  Future<void> createDeviceOnlyAccount(WidgetTester tester) async {
    final skip = find.text(_en.walkthrough.wt_skip);
    // This design's Welcome offers "Use on this device only" directly; the
    // older one went Get started → Device only.
    final device = find.text(_en.onboarding.w_device);
    final start = find.text(_en.walkthrough.wt_start);
    final welcome = _either(device, start);
    await pumpUntil(tester, _either(skip.hitTestable(), welcome));
    if (skip.hitTestable().evaluate().isNotEmpty) {
      await tapWhenReady(tester, skip.hitTestable());
      await pumpUntil(tester, welcome);
    }
    if (device.evaluate().isNotEmpty) {
      await tapWhenReady(tester, device);
    } else {
      await tapWhenReady(tester, start);
      await tapWhenReady(tester, find.text(_en.auth.mode_device));
    }
    await pumpUntil(tester, find.text(_en.auth.device_title));
    await tester.enterText(find.byKey(const ValueKey('emailField')).hitTestable().first, _email);
    await tester.enterText(find.byKey(const ValueKey('passwordField')).hitTestable().first, _password);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
    await tapWhenReady(tester, find.text(_en.auth.device_create));
    await pumpUntil(tester, find.text(_en.privacy.pv_agree));
    await acceptDisclosure(tester);
    await pumpUntil(tester, find.text(_en.nav.tab_meds).hitTestable());
    await settle(tester, 10);
    expect(await storage.read(key: kAccountModeKey), AccountMode.deviceOnly.wire);
  }

  /// A fresh device with a device-only account, signed in, on Home.
  Future<void> freshAccount(WidgetTester tester, {FakeMaintenanceApi? maintenance, bool motherChild = false}) async {
    await wipeDevice(tester);
    await launch(tester, maintenance: maintenance);
    final flags = FeatureFlags.current!;
    expect(flags.allowOverrides, isTrue, reason: 'the dev flavour must allow Dev Config flag overrides');
    await flags.setOverride(AppFlags.maintenance, true);
    if (motherChild) await flags.setOverride(AppFlags.motherChild, true);
    await createDeviceOnlyAccount(tester);
  }

  Future<void> goHome(WidgetTester tester) async {
    await tapWhenReady(tester, find.text(_en.nav.tab_home));
    await settle(tester, 5);
  }

  /// Home → "Health records" shortcut → the records list.
  Future<void> openRecords(WidgetTester tester) async {
    await goHome(tester);
    final tile = find.text(_en.home.sc_records);
    await reveal(tester, tile);
    await tapWhenReady(tester, tile);
    await pumpUntil(tester, find.byType(RecordsScreen));
    await settle(tester, 5);
  }

  /// Meds → + → name → Add medication (as offline_account_test.dart).
  Future<void> addMedication(WidgetTester tester) async {
    await tapWhenReady(tester, find.text(_en.nav.tab_meds));
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
    await pumpUntil(tester, find.text(_medName));
  }

  Future<void> key(WidgetTester tester, String label) async {
    final k = find.descendant(of: find.byType(NumPad), matching: find.text(label));
    await tester.ensureVisible(k);
    await tester.tap(k);
    await tester.pump(const Duration(milliseconds: 60));
  }

  Future<void> backspace(WidgetTester tester, int times) async {
    final del = find.descendant(of: find.byType(NumPad), matching: find.byIcon(LucideIcons.delete));
    await tester.ensureVisible(del);
    for (var i = 0; i < times; i++) {
      await tester.tap(del);
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> typeDigits(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await key(tester, d);
    }
  }

  /// Text that may be a plain Text or part of a RichText.
  Finder value(String text) => find.textContaining(text, findRichText: true);

  Future<List<CheckIn>> storedCheckIns() => container!.read(checkInsDataSourceProvider).findAll();

  // ── 1 ─────────────────────────────────────────────────────────────────────
  testWidgets('1. edit a logged reading: tap it → prefilled form → save → the day shows it; ⋮ Edit above Delete',
      skip: _skip(1), (tester) async {
    await freshAccount(tester);
    final c = _en.checkin;
    final bp = _en.profile.m_bp;

    // Quick-log 124/82.
    await tapWhenReady(tester, _quickLogFab);
    await pumpUntil(tester, find.text(c.ql_title).hitTestable());
    await tapWhenReady(tester, find.text(bp));
    await pumpUntil(tester, find.byType(NumPad));
    await typeDigits(tester, '12482');
    expect(value('124'), findsWidgets);
    await snap(tester, '01-quicklog-bp-entered');
    await tapWhenReady(tester, find.widgetWithIcon(RoundBtn, LucideIcons.check));
    await pumpUntil(tester, find.text(c.ql_saved));
    await pumpUntilTrue(tester, () async => (await storedCheckIns()).length == 1, 'the reading stored');
    expect((await storedCheckIns()).single.vitals, const Vitals(systolic: 124, diastolic: 82));
    await tapWhenReady(tester, _roundBtn(_en.common.a11y_close));
    await pumpUntilGone(tester, find.text(c.ql_title));

    // Home → the day's records.
    await goHome(tester);
    await reveal(tester, find.byType(CheckInDayRow));
    await tapWhenReady(tester, find.byType(CheckInDayRow).first);
    await pumpUntil(tester, find.byType(DayRecordsScreen));
    await pumpUntil(tester, value('124/82'));
    await snap(tester, '02-day-records-before-edit');

    // Tap the reading → its form, titled and prefilled.
    await tapWhenReady(tester, find.text(bp));
    await pumpUntil(tester, find.text(c.ql_edit_title(bp)));
    expect(find.text('124'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text(c.ql_delete_entry), findsOneWidget);
    await snap(tester, '03-edit-reading-prefilled');

    // Systolic → 132, diastolic → 88.
    await tapWhenReady(tester, find.text('124'));
    await backspace(tester, 3);
    await typeDigits(tester, '132'); // three digits move on to diastolic
    await backspace(tester, 2);
    await typeDigits(tester, '88');
    expect(find.text('132'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    await tapWhenReady(tester, find.widgetWithIcon(RoundBtn, LucideIcons.check));
    await pumpUntilGone(tester, find.text(c.ql_edit_title(bp)));
    await pumpUntil(tester, value('132/88'));
    expect(value('124/82'), findsNothing);
    final stored = await storedCheckIns();
    expect(stored, hasLength(1), reason: 'the edit replaces the reading');
    expect(stored.single.vitals, const Vitals(systolic: 132, diastolic: 88));
    await snap(tester, '04-day-records-after-edit');

    // ⋮ menu: Edit above Delete.
    await tapWhenReady(tester, _roundBtn(_en.common.del_options(bp)));
    await pumpUntil(tester, find.text(c.rec_delete));
    final editItem = find.text(_en.common.a11y_edit).hitTestable();
    expect(editItem, findsOneWidget);
    expect(tester.getTopLeft(editItem).dy, lessThan(tester.getTopLeft(find.text(c.rec_delete)).dy),
        reason: 'Edit sits above Delete');
    await snap(tester, '05-row-menu-edit-above-delete');

    // Edit from the menu → the form again → "Delete this entry" → it asks.
    await tapWhenReady(tester, editItem);
    await pumpUntil(tester, find.text(c.ql_edit_title(bp)));
    final del = find.text(c.ql_delete_entry);
    await reveal(tester, del);
    await tapWhenReady(tester, del);
    final confirmTitle = find.text(_en.common.del_title(bp.toLowerCase()));
    await pumpUntil(tester, confirmTitle);
    expect(await storedCheckIns(), hasLength(1), reason: 'nothing is deleted before the answer');
    await snap(tester, '06-delete-entry-asks-first');

    // Cancel keeps it; confirming deletes it.
    await tapWhenReady(tester, _pButton(_en.common.cancel));
    await pumpUntilGone(tester, confirmTitle);
    expect(value('132/88'), findsWidgets);
    expect((await storedCheckIns()).single.vitals.systolic, 132);
    await tapWhenReady(tester, find.text(bp));
    await pumpUntil(tester, find.text(c.ql_edit_title(bp)));
    await reveal(tester, del);
    await tapWhenReady(tester, del);
    await pumpUntil(tester, confirmTitle);
    await tapWhenReady(tester, _pButton(_en.common.del));
    await pumpUntilTrue(tester, () async => (await storedCheckIns()).isEmpty, 'the reading deleted');
    await pumpUntilGone(tester, value('132/88'));

    await shutDown(tester);
  });

  // ── 2 ─────────────────────────────────────────────────────────────────────
  testWidgets('2. edit a record: pencil → prefilled sheet → Save changes → detail shows it; date on its own line',
      skip: _skip(2), (tester) async {
    await freshAccount(tester);
    final r = _en.records;
    final tagA = r.tag_diabetes;
    final tagB = r.tag_kidney;

    // Add a lab record, no file.
    await openRecords(tester);
    await tapWhenReady(tester, _pButton(_en.settings.add_record));
    await pumpUntil(tester, find.text(r.rec_pick_type));
    await tapWhenReady(tester, find.text(r.rec_lab_one));
    await pumpUntil(tester, find.widgetWithText(TextField, r.rec_title_ph));
    await tester.enterText(find.widgetWithText(TextField, r.rec_title_ph), _recordTitle);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
    await tapWhenReady(tester, find.text(tagA));
    await snap(tester, '07-add-record-form');
    final add = _pButton(_en.settings.add_record);
    await reveal(tester, add);
    await tapWhenReady(tester, add);
    await pumpUntil(tester, find.text(r.rec_added));
    await pumpUntilGone(tester, find.text(r.rec_added));

    final records = await container!.read(recordsDataSourceProvider).findAll();
    expect(records, hasLength(1));
    final record = records.single;
    expect((record.title, record.type, record.filePath), (_recordTitle, RecordType.lab, null));
    expect(record.tags, [tagA]);

    // The list row: title, then the date on its own line under a calendar.
    await pumpUntil(tester, find.text(_recordTitle));
    final card = find.ancestor(of: find.text(_recordTitle), matching: find.byType(PCard)).first;
    final dateText = formatRecordDate(record.takenAt, appState());
    final dateRow = find.ancestor(of: find.byIcon(LucideIcons.calendar), matching: find.byType(Row));
    expect(find.descendant(of: card, matching: find.byIcon(LucideIcons.calendar)), findsOneWidget);
    expect(find.descendant(of: find.descendant(of: card, matching: dateRow).first, matching: find.text(dateText)),
        findsOneWidget,
        reason: 'the date is its own line, next to the calendar');
    expect(find.descendant(of: card, matching: find.text(r.rec_self)), findsOneWidget,
        reason: '"You uploaded" is its own line, not joined to the date');
    expect(tester.getTopLeft(find.descendant(of: card, matching: find.text(dateText))).dy,
        lessThan(tester.getTopLeft(find.descendant(of: card, matching: find.text(r.rec_self))).dy));
    await snap(tester, '08-records-list-date-line');

    // Open → pencil → the edit sheet, filled in.
    await tapWhenReady(tester, find.text(_recordTitle));
    await pumpUntil(tester, find.byType(RecordDetailScreen));
    await tapWhenReady(tester, _roundBtn(_en.common.a11y_edit));
    await pumpUntil(tester, find.text(r.rec_edit_title(r.rec_lab_one)));
    expect(find.widgetWithText(TextField, _recordTitle), findsOneWidget);
    expect(find.text(tagA).hitTestable(), findsOneWidget);
    expect(find.text(r.rec_save_changes), findsOneWidget);
    expect(find.text(_en.settings.add_record).hitTestable(), findsNothing);
    final local = record.takenAt.toLocal();
    final hm = '${local.hour % 12 == 0 ? 12 : local.hour % 12}:${local.minute.toString().padLeft(2, '0')}';
    expect(find.textContaining(hm, findRichText: true), findsWidgets, reason: 'the time is filled in');
    await snap(tester, '09-edit-record-prefilled');

    // New title; swap tag A for tag B.
    await tester.enterText(find.widgetWithText(TextField, _recordTitle), _recordEdited);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
    final tagRow = find.ancestor(of: find.text(tagA).last, matching: find.byType(Row)).first;
    await tapWhenReady(tester, find.descendant(of: tagRow, matching: find.byIcon(LucideIcons.x)));
    await tapWhenReady(tester, find.text(tagB));
    final save = _pButton(r.rec_save_changes);
    await reveal(tester, save);
    await tapWhenReady(tester, save);
    await pumpUntil(tester, find.text(r.rec_changes_saved));
    await snap(tester, '10-record-changes-saved');
    await pumpUntilGone(tester, find.text(r.rec_changes_saved));

    await pumpUntil(tester, find.text(_recordEdited));
    expect(find.text(_recordTitle), findsNothing);
    expect(find.text(tagB), findsWidgets);
    expect(find.text(tagA), findsNothing);
    final stored = (await container!.read(recordsDataSourceProvider).find(record.id))!;
    expect((stored.title, stored.takenAt), (_recordEdited, record.takenAt));
    expect(stored.tags, [tagB]);
    await snap(tester, '11-record-detail-after-edit');

    // Arabic (RTL): the detail and the edit sheet.
    appState().setLang(LanguageCode.ar);
    await settle(tester, 10);
    expect(Directionality.of(tester.element(find.text(_recordEdited))), TextDirection.rtl);
    await snap(tester, '12-ar-record-detail');
    await tapWhenReady(tester, _roundBtn(_ar.common.a11y_edit));
    await pumpUntil(tester, find.text(_ar.records.rec_edit_title(_ar.records.rec_lab_one)));
    expect(find.text(_ar.records.rec_save_changes), findsOneWidget);
    await snap(tester, '13-ar-edit-record-sheet');
    expect(tester.takeException(), isNull);

    await shutDown(tester);
  });

  // ── 3 ─────────────────────────────────────────────────────────────────────
  testWidgets('3. family member: medical profile persists, Trends opens, pregnancy tracking starts', skip: _skip(3),
      (tester) async {
    await freshAccount(tester, motherChild: true);
    final f = _en.family;
    final p = _en.pregnancy;

    // Home → Family → Add family member → Enter details manually.
    await goHome(tester);
    await reveal(tester, find.text(f.title));
    await tapWhenReady(tester, find.text(f.title));
    await tapWhenReady(tester, _pButton(f.add_member));
    await tapWhenReady(tester, find.text(f.manual_t));
    await pumpUntil(tester, find.text(f.f_relation));

    await tapWhenReady(tester, find.text(f.pick_spouse));
    await tester.enterText(find.widgetWithText(TextField, f.f_name_ph(Gender.other)), _memberName);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);

    // Date of birth: 15 <this month> 1990, through the year grid.
    final dobField = find.text(f.f_dob_ph);
    await reveal(tester, dobField);
    await tapWhenReady(tester, dobField);
    final now = DateTime.now();
    final months = _en.settings.cal_months.split('|');
    await tapWhenReady(tester, find.text('${months[now.month - 1]} ${now.year - 5}'));
    final year = find.text('1990');
    await reveal(tester, year);
    await tapWhenReady(tester, year);
    await tapWhenReady(tester, find.text('15'));
    await tapWhenReady(tester, find.text(_en.onboarding.dob_confirm));
    await pumpUntilGone(tester, find.text(_en.onboarding.dob_confirm));

    final female = find.text(f.sex_female);
    await reveal(tester, female);
    await tapWhenReady(tester, female);
    await snap(tester, '14-add-member-form');

    // An adult: the consent step.
    await tapWhenReady(tester, _pButton(f.next));
    await pumpUntil(tester, find.text(f.consent_check_f(_memberShort)));
    await tapWhenReady(tester, find.text(f.consent_check_f(_memberShort)));
    await tapWhenReady(tester, _pButton(f.add_cta(_memberShort)));
    await pumpUntil(tester, find.text(_memberName));

    // Family → the member's screen.
    await tapWhenReady(tester, find.text(_memberName));
    await pumpUntil(tester, find.text(f.tile_medical));
    expect(find.textContaining(f.rel_wife), findsWidgets);
    expect(find.text(f.tile_trends), findsOneWidget);
    expect(find.text(p.title), findsOneWidget, reason: 'a woman of childbearing age is offered pregnancy tracking');
    await snap(tester, '15-member-screen');

    // Medical profile: B+, an allergy, a condition; save.
    await tapWhenReady(tester, find.text(f.tile_medical));
    await pumpUntil(tester, find.byType(MemberMedicalScreen));
    await pumpUntil(tester, find.text(f.medical_intro(_memberShort)));
    expect(find.text(f.medical_allergies_none), findsOneWidget);
    await tapWhenReady(tester, find.text('B+'));
    // The two chip cards, allergies first, then conditions.
    Finder card(int i) => find.byType(ChipListCard).at(i);
    Future<void> addTo(int i, String text) async {
      final field = find.descendant(of: card(i), matching: find.byType(TextField));
      await reveal(tester, field);
      await tester.enterText(field, text);
      await settle(tester, 2);
      await tapWhenReady(tester, find.descendant(of: card(i), matching: _roundBtn(f.medical_add)));
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, 3);
    }

    void expectLists() {
      expect(find.descendant(of: card(0), matching: find.text(_allergen)), findsOneWidget, reason: 'allergies card');
      expect(find.descendant(of: card(1), matching: find.text(_condition)), findsOneWidget, reason: 'conditions card');
      // On this screen (the member screen underneath also names them).
      expect(find.text(_allergen).hitTestable(), findsOneWidget,
          reason: 'the allergen is listed once, under allergies');
      expect(find.text(_condition).hitTestable(), findsOneWidget,
          reason: 'the condition is listed once, under conditions');
    }

    await pumpUntil(tester, card(1));
    await addTo(0, _allergen);
    await addTo(1, _condition);
    expectLists();
    await tapWhenReady(tester, _pButton(f.save));
    await pumpUntil(tester, find.text(_en.profile.pd_saved));
    await snap(tester, '16-member-medical-saved');

    // Leave and reopen: still there.
    await tapWhenReady(tester, _roundBtn(_en.common.a11y_back));
    await pumpUntilGone(tester, find.byType(MemberMedicalScreen));
    await pumpUntil(tester, find.text('B+ · ${f.allergies_n(1)} · ${f.conditions_n(1)}'));
    await tapWhenReady(tester, find.text(f.tile_medical));
    await pumpUntil(tester, find.text(_allergen));
    expectLists();
    expect(find.text(f.medical_allergies_none), findsNothing);
    await snap(tester, '17-member-medical-reopened');

    // Arabic (RTL): the medical profile and the member screen.
    appState().setLang(LanguageCode.ar);
    await settle(tester, 10);
    await pumpUntil(tester, find.text(_ar.family.tile_medical));
    expect(Directionality.of(tester.element(find.text(_allergen))), TextDirection.rtl);
    await snap(tester, '18-ar-member-medical');
    await tapWhenReady(tester, _roundBtn(_ar.common.a11y_back));
    await pumpUntilGone(tester, find.byType(MemberMedicalScreen));
    await pumpUntil(tester, find.text(_ar.family.tile_trends));
    await snap(tester, '19-ar-member-screen');
    expect(tester.takeException(), isNull);
    appState().setLang(LanguageCode.en);
    await settle(tester, 10);

    // Trends tile → the member's Trends.
    await tapWhenReady(tester, find.text(f.tile_trends));
    await pumpUntil(tester, find.byType(TrendsScreen));
    await pumpUntil(tester, _either(find.text(f.trends_empty_t), find.text(f.trends_nothing(_memberShort))));
    await snap(tester, '20-member-trends');
    await tapWhenReady(tester, _roundBtn(_en.common.a11y_back));
    await pumpUntilGone(tester, find.byType(TrendsScreen));

    // Pregnancy tile → start tracking for her.
    final pregTile = find.ancestor(of: find.text(p.title), matching: find.byType(FamilyTile));
    await reveal(tester, pregTile);
    expect(find.descendant(of: pregTile, matching: find.text(f.tile_preg_off(Gender.other))), findsOneWidget);
    await tapWhenReady(tester, pregTile);
    await pumpUntil(tester, find.text(p.title_of(_memberShort)));
    await tapWhenReady(tester, find.text(p.pick_date));
    // Due date: the 15th of next month.
    await tapWhenReady(tester, find.byIcon(Icons.chevron_right));
    await tapWhenReady(tester, find.text('15'));
    await tapWhenReady(tester, find.text(_en.onboarding.dob_confirm));
    await pumpUntilGone(tester, find.text(_en.onboarding.dob_confirm));
    await snap(tester, '21-pregnancy-start');
    await tapWhenReady(tester, _pButton(p.start_cta_of(Gender.other)));
    await pumpUntil(tester, find.byType(PregnancyScreen));
    await pumpUntil(tester, find.textContaining(p.week_n(1).split(' ').first));
    expect(find.text(p.title_of(_memberShort)), findsWidgets);
    await snap(tester, '22-member-pregnancy-screen');

    await shutDown(tester);
  });

  // ── 4 ─────────────────────────────────────────────────────────────────────
  testWidgets('4. attribution: "By …" chip → Edit history → editing it adds "You edited this"', skip: _skip(4),
      (tester) async {
    await freshAccount(tester);
    final a = _en.attribution;
    final c = container!;
    final user = c.read(currentUserIdProvider)!;
    await c.read(activeProfileProvider.future);
    final byFamily = ProvenanceActor.other(ProvenanceActorKind.family, displayName: _relative);
    final addedAt = DateTime(2026, 1, 5, 9);

    // A record a family member added — through the records data source.
    const recordId = RecordDocumentId.value('rec-e2e-attributed');
    await c.read(recordsDataSourceProvider).put(
          recordId,
          RecordDocument(
            id: recordId,
            userId: user,
            type: RecordType.report,
            title: _recordTitle,
            takenAt: DateTime(2026, 1, 5, 9),
            createdAt: DateTime(2026, 1, 5, 9),
            history: EntryHistory(
                [ProvenanceEvent(id: 'e2e-prov-rec', actor: byFamily, action: ProvenanceAction.added, at: addedAt)]),
          ),
        );

    // A medication added in the UI, then marked as a family member's.
    await addMedication(tester);
    final meds = c.read(medicationsDataSourceProvider);
    final med = (await meds.findAll()).singleWhere((m) => m.name == _medName);
    await meds.put(
        med.id,
        med.copyWith(
            history: EntryHistory(
                [ProvenanceEvent(id: 'e2e-prov-med', actor: byFamily, action: ProvenanceAction.added, at: addedAt)])));
    expect((await meds.find(med.id))!.history.isAttributed, isTrue, reason: 'the history was stored');
    // The medications watch streams declare no `readsFrom`, so a write that
    // bypasses the use cases does not reach the Meds screen by itself; the
    // screen's own writers invalidate these, as the test does here.
    c.invalidate(medicationListProvider);
    c.invalidate(todayDosesProvider);

    // Meds list carries the chip.
    final chip = find.byType(EntryAttributionChip);
    await pumpUntil(tester, chip);
    expect(find.descendant(of: chip, matching: find.text(_relative)), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(a.chip_a11y(a.by(_relative)))}')), findsOneWidget);
    await snap(tester, '23-meds-by-chip');

    // Records list: the chip, and no "You uploaded".
    await openRecords(tester);
    await pumpUntil(tester, find.text(_recordTitle));
    final card = find.ancestor(of: find.text(_recordTitle), matching: find.byType(PCard)).first;
    expect(find.descendant(of: card, matching: chip), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(_relative)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(_en.records.rec_self)), findsNothing);
    await snap(tester, '24-records-list-by-chip');

    // Detail: the chip → Edit history.
    await tapWhenReady(tester, find.text(_recordTitle));
    await pumpUntil(tester, find.byType(RecordDetailScreen));
    await pumpUntil(tester, chip);
    await tapWhenReady(tester, chip);
    await pumpUntil(tester, find.text(a.history_title));
    expect(find.text(a.added_this(_relative)), findsOneWidget);
    expect(find.text('${a.role_family} · 5 January 2026'), findsOneWidget);
    expect(find.text(a.locked), findsOneWidget);
    expect(find.text(a.you_edited(Gender.other)), findsNothing);
    await snap(tester, '25-edit-history-sheet');
    Navigator.of(tester.element(find.text(a.history_title))).pop();
    await pumpUntilGone(tester, find.text(a.history_title));

    // Edit the record in the UI.
    await tapWhenReady(tester, _roundBtn(_en.common.a11y_edit));
    await pumpUntil(tester, find.text(_en.records.rec_edit_title(_en.records.rec_report_one)));
    await tester.enterText(find.widgetWithText(TextField, _recordTitle), _recordEdited);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
    final save = _pButton(_en.records.rec_save_changes);
    await reveal(tester, save);
    await tapWhenReady(tester, save);
    await pumpUntil(tester, find.text(_en.records.rec_changes_saved));
    await pumpUntilGone(tester, find.text(_en.records.rec_changes_saved));
    await pumpUntil(tester, find.text(_recordEdited));

    // Still attributed to the family member, marked edited; the history has both.
    expect(find.descendant(of: chip, matching: find.text(_relative)), findsOneWidget);
    expect(find.descendant(of: chip, matching: find.byIcon(LucideIcons.pencil)), findsOneWidget);
    await tapWhenReady(tester, chip);
    await pumpUntil(tester, find.text(a.history_title));
    expect(find.text(a.you_edited(Gender.other)), findsOneWidget);
    expect(find.text(a.added_this(_relative)), findsOneWidget);
    expect(tester.getTopLeft(find.text(a.you_edited(Gender.other))).dy,
        lessThan(tester.getTopLeft(find.text(a.added_this(_relative))).dy),
        reason: 'newest first');
    final history = (await c.read(recordsDataSourceProvider).find(recordId))!.history;
    expect(history.events.map((e) => (e.actor.kind, e.action)).toList(), [
      (ProvenanceActorKind.family, ProvenanceAction.added),
      (ProvenanceActorKind.self, ProvenanceAction.edited),
    ]);
    await snap(tester, '26-edit-history-after-own-edit');

    await shutDown(tester);
  });

  // ── 5 ─────────────────────────────────────────────────────────────────────
  testWidgets('5. maintenance: readonly strip + paused actions; block page; off; an erroring endpoint pauses nothing',
      skip: _skip(5), (tester) async {
    final api = FakeMaintenanceApi(mode: 'off');
    await freshAccount(tester, maintenance: api);
    final m = _en.maintenance;
    Future<void> setMode(String mode) async {
      api.mode = mode;
      await container!.read(maintenanceProvider.notifier).check();
      await settle(tester, 5);
    }

    final strip = find.text(m.strip_title);
    final paused = find.text(m.paused_title);
    expect(strip, findsNothing);
    final before = api.calls;

    // ── readonly ──
    await setMode('readonly');
    expect(api.calls, greaterThan(before), reason: 'the app asked the (fake) maintenance API');
    await goHome(tester);
    await pumpUntil(tester, strip.hitTestable());
    final stripTop = tester.getTopLeft(find.byType(MaintenanceStrip)).dy;
    final tabBarTop = tester.getTopLeft(_quickLogFab).dy;
    expect(stripTop, lessThan(tabBarTop), reason: 'the strip sits above the tab bar');
    expect(find.text(_en.nav.tab_meds).hitTestable(), findsOneWidget, reason: 'the app stays usable');
    await snap(tester, '27-maintenance-readonly-strip');

    await tapWhenReady(tester, find.text(m.strip_details));
    await pumpUntil(tester, find.text(m.ro_title));
    expect(find.text(m.paused_log), findsOneWidget);
    expect(find.text(m.ok_card), findsOneWidget);
    await snap(tester, '28-maintenance-details-sheet');
    await tapWhenReady(tester, _pButton(m.got_it));
    await pumpUntilGone(tester, find.text(m.ro_title));

    // Quick log is paused.
    await tapWhenReady(tester, _quickLogFab);
    await pumpUntil(tester, paused);
    expect(find.text(_en.checkin.ql_title).hitTestable(), findsNothing);
    await snap(tester, '29-maintenance-quicklog-paused');
    await tapWhenReady(tester, _pButton(m.got_it));
    await pumpUntilGone(tester, paused);

    // Add record is paused.
    await openRecords(tester);
    await tapWhenReady(tester, _pButton(_en.settings.add_record));
    await pumpUntil(tester, paused);
    expect(find.text(_en.records.rec_pick_type), findsNothing);
    await snap(tester, '30-maintenance-add-record-paused');
    await tapWhenReady(tester, _pButton(m.got_it));
    await pumpUntilGone(tester, paused);
    await tapWhenReady(tester, _roundBtn(_en.common.a11y_back));
    await pumpUntilGone(tester, find.byType(RecordsScreen));

    // ── block ──
    await setMode('block');
    final page = find.byType(MaintenanceScreen);
    await pumpUntil(tester, page);
    await pumpUntil(tester, find.text(m.block_title).hitTestable());
    final s = appState();
    final call = m.call_emergency(s.country.emergencyNumber, s.gender);
    final buttons = find.descendant(of: page, matching: find.byType(PButton));
    expect(
        tester.widgetList<PButton>(buttons).map((b) => b.label).toSet(), {m.open_card, call, m.check_again(s.gender)},
        reason: 'only the emergency card, the emergency call and Check again');
    expect(find.text(_en.nav.tab_meds).hitTestable(), findsNothing, reason: 'the app is covered');
    expect(strip.hitTestable(), findsNothing);
    await snap(tester, '31-maintenance-block-page');

    // The patient's own emergency card opens from the block page, read from the
    // phone (design MCCardScreen id="self"), not the emergency numbers.
    await tapWhenReady(tester, find.text(m.open_card));
    await pumpUntil(tester, find.byType(OwnCardScreen));
    await pumpUntil(tester, find.byType(OwnCardScreen).hitTestable(),
        timeout: const Duration(seconds: 5)); // must not open under the page
    expect(find.text(_en.family.own_card_note).hitTestable(), findsOneWidget);
    await snap(tester, '32-maintenance-block-emergency-card');
    Navigator.of(tester.element(find.byType(OwnCardScreen))).pop();
    await pumpUntilGone(tester, find.byType(OwnCardScreen));

    // Check again while still blocked keeps the page.
    final callsBefore = api.calls;
    await tapWhenReady(tester, find.text(m.check_again(s.gender)));
    await pumpUntilTrue(tester, () async => api.calls > callsBefore, 'Check again asked the API');
    expect(page, findsOneWidget);

    // ── off ──
    api.mode = 'off';
    await tapWhenReady(tester, find.text(m.check_again(s.gender)));
    await pumpUntilGone(tester, page);
    await pumpUntil(tester, find.text(_en.nav.tab_meds).hitTestable());
    expect(strip, findsNothing);
    await tapWhenReady(tester, _quickLogFab);
    await pumpUntil(tester, find.text(_en.checkin.ql_title).hitTestable());
    expect(paused, findsNothing);
    await snap(tester, '33-maintenance-off-quicklog-opens');
    await tapWhenReady(tester, _roundBtn(_en.common.a11y_close));
    await pumpUntilGone(tester, find.text(_en.checkin.ql_title));

    // ── an erroring endpoint: after a block, then failing — nothing paused ──
    await setMode('block');
    await pumpUntil(tester, page);
    for (final failure in [
      const ApiException(code: 'network_error', isOffline: true),
      const ApiException(code: 'server_error', statusCode: 503),
    ]) {
      api.failWith = failure;
      await container!.read(maintenanceProvider.notifier).check();
      await settle(tester, 5);
      expect(container!.read(maintenanceProvider).mode, MaintenanceMode.unknown, reason: failure.code);
      await pumpUntilGone(tester, page);
      expect(strip, findsNothing);
      await tapWhenReady(tester, _quickLogFab);
      await pumpUntil(tester, find.text(_en.checkin.ql_title).hitTestable());
      expect(paused, findsNothing, reason: failure.code);
      await tapWhenReady(tester, _roundBtn(_en.common.a11y_close));
      await pumpUntilGone(tester, find.text(_en.checkin.ql_title));
    }
    await snap(tester, '34-maintenance-endpoint-error-nothing-paused');

    await shutDown(tester);
  });
}
