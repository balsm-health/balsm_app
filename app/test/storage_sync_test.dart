import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/storage_sheet.dart';
import 'package:app/balsm_app/storage_target.dart';
import 'package:app/balsm_app/widgets/data_loc_pill.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Storage & sync, ported from `storage.jsx`'s per-category multi-cloud model.
///
/// The design offers three connectable clouds. None of them can hold a byte in
/// this build, so the screen must render the model without ever claiming a copy
/// left the phone. These tests guard that gate — not the pixels.
void main() {
  Future<PatientAppState> pumpSheet(WidgetTester tester, {bool ar = false}) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
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
      for (final c in DataCategory.values) {
        expect(syncTargetsFor(c), isEmpty, reason: '${c.id} claims a cloud target');
      }
    });

    test('the summary never names a cloud while none is reachable', () {
      final s = PatientAppState().strings.storage;
      expect(locSummary(s, syncTargetsFor(DataCategory.records)), s.store_device_only_sum);
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
