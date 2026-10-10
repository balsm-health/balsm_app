import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/storage_sheet.dart';
import 'package:app/balsm_app/storage_target.dart';
import 'package:app/balsm_app/widgets/badges.dart';
import 'package:app/balsm_app/widgets/data_loc_pill.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Storage & sync, ported from `storage.jsx`'s per-category multi-cloud model.
///
/// The design offers three connectable clouds. None of them can hold a byte in
/// this build, so the screen must render the model without ever claiming a copy
/// left the phone. These tests guard that gate — not the pixels.
///
/// The care team is the exception: it can be mirrored to Balsm Cloud, and the
/// patient can switch that off. The mirror is off in this build
/// ([careCloudSyncAvailable]); the group below turns it on to keep it tested.
void main() {
  Future<PatientAppState> pumpSheet(WidgetTester tester, {bool ar = false, bool deviceOnly = false}) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    if (deviceOnly) state.setAccountMode(AccountMode.deviceOnly);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      child: AppScope(
        state: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => showStorageSync(context), child: const Text('open')),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return state;
  }

  group('availability', () {
    test('only the device can hold a copy today', () {
      expect(StorageTarget.local.isAvailable, isTrue);
      for (final t in StorageTarget.picker.where((t) => !t.isLocal)) {
        expect(t.isAvailable, isFalse, reason: '${t.id} has no working adapter');
      }
    });

    test('a category with no reachable cloud reports the device alone', () {
      final s = PatientAppState();
      for (final c in DataCategory.values.where((c) => c != DataCategory.care)) {
        expect(syncTargetsFor(c, s), isEmpty, reason: '${c.id} claims a cloud target');
      }
    });

    test('the summary never names a cloud while none is reachable', () {
      final s = PatientAppState();
      final st = s.strings.storage;
      expect(locSummary(st, syncTargetsFor(DataCategory.records, s)), st.store_device_only_sum);
    });
  });

  group('care team cloud sync, off in this build', () {
    test('the build ships with the mirror off', () => expect(careCloudSyncAvailable, isFalse));

    test('an online account that left the choice on still reports the device alone', () {
      final s = PatientAppState();
      expect(s.careCloudSync, isTrue, reason: 'the choice itself is untouched');
      expect(careSyncsToCloud(s), isFalse);
      expect(syncTargetsFor(DataCategory.care, s), isEmpty);
      expect(
          locSummary(s.strings.storage, syncTargetsFor(DataCategory.care, s)), s.strings.storage.store_device_only_sum);
    });

    testWidgets('the care editor offers no switch and makes no cloud claim', (tester) async {
      final s = await pumpSheet(tester);
      final st = s.strings.storage;

      final care = find.text(DataCategory.care.label(st)).first;
      await tester.ensureVisible(care);
      await tester.pumpAndSettle();
      await tester.tap(care);
      await tester.pumpAndSettle();

      expect(find.byType(PSwitch), findsNothing);
      expect(find.text(st.store_care_cloud_on), findsNothing);
      expect(find.text(st.store_care_cloud_note), findsNothing);
    });
  });

  group('care team cloud sync, when the build mirrors it', () {
    setUp(() => careCloudSyncAvailable = true);
    tearDown(() => careCloudSyncAvailable = false);

    test('is on by default for an online account', () {
      final s = PatientAppState();
      expect(s.careCloudSync, isTrue);
      expect(syncTargetsFor(DataCategory.care, s), [StorageTarget.balsmCloud]);
    });

    test('switched off, the care team is on the device alone', () async {
      final s = PatientAppState();
      await s.setCareCloudSync(false);
      expect(syncTargetsFor(DataCategory.care, s), isEmpty);
    });

    test('a device-only account never claims the cloud', () {
      final s = PatientAppState()..setAccountMode(AccountMode.deviceOnly);
      expect(s.careCloudSync, isTrue, reason: 'the choice itself is untouched');
      expect(syncTargetsFor(DataCategory.care, s), isEmpty);
    });

    testWidgets('the care editor carries a switch that turns it off', (tester) async {
      final s = await pumpSheet(tester);
      final st = s.strings.storage;

      final care = find.text(DataCategory.care.label(st)).first;
      await tester.ensureVisible(care);
      await tester.pumpAndSettle();
      await tester.tap(care);
      await tester.pumpAndSettle();

      expect(find.text(st.store_care_cloud_on), findsOne);
      expect(find.text(st.store_care_cloud_note), findsOne);
      // Rows leave the phone unencrypted-at-source, so the blob-backup
      // promise must not sit next to this switch.
      expect(find.text(st.store_encrypted_note), findsNothing);

      await tester.tap(find.byType(PSwitch));
      await tester.pumpAndSettle();

      expect(s.careCloudSync, isFalse);
      expect(find.text(st.store_care_cloud_off), findsOne);
    });

    testWidgets('clouds are drawn as their own marks, the device as a glyph', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Row(children: [
          StorageIcon(StorageTarget.local, size: 20),
          StorageIcon(StorageTarget.icloud, size: 20),
          StorageIcon(StorageTarget.gdrive, size: 20),
          StorageIcon(StorageTarget.balsmCloud, size: 20, muted: true),
        ]),
      ));
      // `base.jsx` BRAND_ICONS: three vendor marks, never Lucide stand-ins.
      expect(find.byType(SvgPicture), findsExactly(3));
      expect(find.byType(Icon), findsOne);
      // `muted` is grayscale + 55% opacity, as in the design.
      expect(find.byType(ColorFiltered), findsOne);
    });

    testWidgets('no other category gets a switch', (tester) async {
      final s = await pumpSheet(tester);
      await tester.tap(find.text(DataCategory.records.label(s.strings.storage)).first);
      await tester.pumpAndSettle();
      expect(find.byType(PSwitch), findsNothing);
    });

    testWidgets('a device-only account gets no switch either', (tester) async {
      final s = await pumpSheet(tester, deviceOnly: true);
      final care = find.text(DataCategory.care.label(s.strings.storage)).first;
      await tester.ensureVisible(care);
      await tester.pumpAndSettle();
      await tester.tap(care);
      await tester.pumpAndSettle();
      expect(find.byType(PSwitch), findsNothing);
    });
  });

  group('the map', () {
    testWidgets('lists every data category', (tester) async {
      final s = await pumpSheet(tester);
      final st = s.strings.storage;
      // Nine categories, as `DATA_CATS` has them — a patient asking "where is
      // my X" must find X.
      expect(DataCategory.values.length, 9);
      for (final c in DataCategory.values) {
        expect(find.text(c.label(st)), findsWidgets, reason: '${c.id} missing from the map');
      }
    });

    testWidgets('offers no Connect and no Disconnect for an unreachable cloud', (tester) async {
      final s = await pumpSheet(tester);
      final st = s.strings.storage;
      expect(find.text(st.store_connect), findsNothing);
      expect(find.text(st.store_disconnect), findsNothing);
      // Each of the three clouds says why instead.
      expect(find.text(st.store_coming_soon), findsExactly(3));
    });

    testWidgets('says plainly that cloud sync is not available', (tester) async {
      final s = await pumpSheet(tester);
      expect(find.text(s.strings.storage.store_intro), findsOne);
    });

    testWidgets('never claims a sync happened', (tester) async {
      final s = await pumpSheet(tester);
      final st = s.strings.storage;
      // The design's "Synced N min ago" line has no honest value here.
      expect(find.text(st.store_sync_now), findsNothing);
      expect(find.text(st.store_synced_done), findsNothing);
      expect(find.text(st.store_backed), findsNothing);
    });
  });

  group('the category editor', () {
    testWidgets('opens from a category row and shows the device as locked', (tester) async {
      final s = await pumpSheet(tester);
      final st = s.strings.storage;

      await tester.tap(find.text(DataCategory.records.label(st)).first);
      await tester.pumpAndSettle();

      expect(find.text(st.store_stored_in.toUpperCase()), findsOne);
      expect(find.text(st.store_local_always), findsOne);
      // What will happen when a cloud does arrive, so the empty list reads as
      // "not yet" rather than "never".
      expect(find.text(st.store_whole_journal), findsWidgets);
    });

    testWidgets('backs out to the map', (tester) async {
      final s = await pumpSheet(tester);
      final st = s.strings.storage;

      // The first row, so the tap does not need a scroll to reach it.
      await tester.tap(find.text(DataCategory.records.label(st)).first);
      await tester.pumpAndSettle();
      final back = find.text(st.store_all_data_back);
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(find.text(st.store_accounts.toUpperCase()), findsOne);
    });
  });

  group('the header pill', () {
    testWidgets('reads Device, and opens the category it names', (tester) async {
      final state = PatientAppState();
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(ProviderScope(
        child: AppScope(
          state: state,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: DataLocPill(category: DataCategory.vitals))),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final st = state.strings.storage;
      expect(find.text(st.store_device), findsOne);

      await tester.tap(find.byType(DataLocPill));
      await tester.pumpAndSettle();
      expect(find.text(st.store_where), findsOne);
      expect(find.text(DataCategory.vitals.label(st)), findsOne);
    });
  });

  testWidgets('lays out in Arabic on a phone without overflowing', (tester) async {
    await pumpSheet(tester, ar: true);
    expect(tester.takeException(), isNull);
  });
}
