import 'dart:ui' show SemanticsAction;

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/maintenance/maintenance_controller.dart';
import 'package:app/balsm_app/maintenance/maintenance_guard.dart';
import 'package:app/balsm_app/maintenance/maintenance_widgets.dart';
import 'package:app/balsm_app/screens/own_card_screen.dart';
import 'package:app/balsm_app/strings.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A controller pinned to [status]; [check] only counts.
class _Pinned extends MaintenanceController {
  _Pinned(this.status);

  final MaintenanceStatus status;
  int checks = 0;

  @override
  MaintenanceStatus build() => status;

  @override
  Future<void> check() async => checks++;
}

final _en = stringsFor('en').maintenance;
final _now = DateTime(2025, 1, 1, 12);

/// Read-only from 11:00 to 13:45: an hour of 2 h 45 min gone.
final _window = MaintenanceStatus(
  mode: MaintenanceMode.readonly,
  startsAt: DateTime(2025, 1, 1, 11),
  endsAt: DateTime(2025, 1, 1, 13, 45),
);

Future<_Pinned> _pump(WidgetTester tester, MaintenanceStatus status, Widget Function(BuildContext) body,
    {bool reducedMotion = true}) async {
  // The badge pulse and the dot blink repeat for ever, which pumpAndSettle
  // would wait out; reduced motion holds them still.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reducedMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final pinned = _Pinned(status);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      maintenanceProvider.overrideWith(() => pinned),
      maintenanceClockProvider.overrideWithValue(() => _now),
    ],
    child: AppScope(
      state: PatientAppState(),
      // Watching the provider stands in for the shell, which starts the check.
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            ref.watch(maintenanceProvider);
            return body(context);
          }),
        ),
      ),
    ),
  ));
  await tester.pump();
  return pinned;
}

void main() {
  group('guard', () {
    testWidgets('in read-only maintenance it pauses the action and explains why', (tester) async {
      bool? paused;
      await _pump(
        tester,
        const MaintenanceStatus(mode: MaintenanceMode.readonly),
        (context) => TextButton(onPressed: () => paused = maintenancePaused(context), child: const Text('add')),
      );

      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();

      expect(paused, isTrue);
      expect(find.text(_en.paused_title), findsOneWidget);
      expect(find.text(_en.ok_card), findsOneWidget);
    });

    for (final mode in [MaintenanceMode.off, MaintenanceMode.unknown]) {
      testWidgets('with mode $mode the action goes ahead', (tester) async {
        bool? paused;
        await _pump(
          tester,
          MaintenanceStatus(mode: mode),
          (context) => TextButton(onPressed: () => paused = maintenancePaused(context), child: const Text('add')),
        );

        await tester.tap(find.text('add'));
        await tester.pumpAndSettle();

        expect((paused, find.text(_en.paused_title).evaluate().isEmpty), (false, true));
      });
    }

    testWidgets('before the shell has started the check nothing is paused', (tester) async {
      bool? paused;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Builder(
              builder: (context) =>
                  TextButton(onPressed: () => paused = maintenancePaused(context), child: const Text('add'))),
        ),
      ));

      await tester.tap(find.text('add'));

      expect(paused, isFalse);
    });

    testWidgets('outside a ProviderScope nothing is paused', (tester) async {
      bool? paused;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) =>
                TextButton(onPressed: () => paused = maintenancePaused(context), child: const Text('add'))),
      ));

      await tester.tap(find.text('add'));

      expect(paused, isFalse);
    });
  });

  group('strip', () {
    testWidgets('a floating card with the countdown that opens the details', (tester) async {
      await _pump(tester, _window, (_) => const Align(alignment: Alignment.bottomCenter, child: MaintenanceStrip()));

      expect(find.text(_en.strip_title), findsOneWidget);
      expect(find.text(_en.left_hm(1, 45)), findsOneWidget);

      await tester.tap(find.text(_en.strip_details));
      await tester.pumpAndSettle();

      expect(find.text(_en.ro_title), findsOneWidget);
    });

    testWidgets('reads as one button: "Maintenance details. <countdown>"', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _window, (_) => const MaintenanceStrip());

      final node = tester.getSemantics(find.bySemanticsLabel(_en.strip_a11y(_en.left_hm(1, 45))));
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('without an announced end: "Duration not announced yet" and no progress bar', (tester) async {
      await _pump(tester, const MaintenanceStatus(mode: MaintenanceMode.readonly),
          (_) => const Align(alignment: Alignment.bottomCenter, child: MaintenanceStrip()));

      expect(find.text(_en.left_unknown), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsNothing);
    });

    testWidgets('with an end, the bar shows how far through the window we are', (tester) async {
      await _pump(tester, _window, (_) => const Align(alignment: Alignment.bottomCenter, child: MaintenanceStrip()));

      final bar = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(bar.widthFactor, closeTo(1 / 2.75, 0.001));
    });

    testWidgets('the countdown moves on every half minute', (tester) async {
      var now = _now;
      final pinned = _Pinned(_window);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          maintenanceProvider.overrideWith(() => pinned),
          maintenanceClockProvider.overrideWithValue(() => now),
        ],
        child: AppScope(state: PatientAppState(), child: const MaterialApp(home: Scaffold(body: MaintenanceStrip()))),
      ));
      expect(find.text(_en.left_hm(1, 45)), findsOneWidget);

      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 30));

      expect(find.text(_en.left_hm(1, 40)), findsOneWidget);
    });

    testWidgets('the dot blinks, and holds still under reduced motion', (tester) async {
      Future<double> dotOpacity() async {
        final o = find.descendant(of: find.byType(MaintenanceStrip), matching: find.byType(Opacity));
        return tester.widget<Opacity>(o.first).opacity;
      }

      await _pump(tester, _window, (_) => const MaintenanceStrip(), reducedMotion: false);
      final first = await dotOpacity();
      await tester.pump(const Duration(milliseconds: 600));
      expect(await dotOpacity(), isNot(first));
      await tester.pumpWidget(const SizedBox());

      await _pump(tester, _window, (_) => const MaintenanceStrip());
      await tester.pump(const Duration(milliseconds: 600));
      expect(await dotOpacity(), 1);
    });

    for (final mode in [MaintenanceMode.off, MaintenanceMode.block, MaintenanceMode.unknown]) {
      testWidgets('is hidden when mode is $mode', (tester) async {
        await _pump(tester, MaintenanceStatus(mode: mode), (_) => const MaintenanceStrip());

        expect(find.text(_en.strip_title), findsNothing);
      });
    }
  });

  group('details sheet', () {
    Future<void> open(WidgetTester tester, MaintenanceStatus status, {bool paused = false}) async {
      await _pump(
        tester,
        status,
        (context) =>
            TextButton(onPressed: () => showMaintenanceSheet(context, paused: paused), child: const Text('open')),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('hero, countdown, both lists, the safety line and the two buttons', (tester) async {
      await open(tester, _window);

      expect(find.text(_en.sheet_eyebrow.toUpperCase()), findsOneWidget);
      expect(find.text(_en.ro_title), findsOneWidget);
      expect(find.text(_en.ro_body), findsOneWidget);
      expect(find.text(_en.left_hm(1, 45)), findsOneWidget);
      expect(find.text(_en.until('1:45 PM')), findsOneWidget);
      expect(find.bySemanticsLabel(_en.progress_label), findsOneWidget);
      expect(find.text(_en.still_available), findsOneWidget);
      expect(find.text(_en.paused_for_now), findsOneWidget);
      expect(find.text(_en.paused_sync), findsOneWidget);
      expect(find.text(_en.data_safe), findsOneWidget);
      expect(find.text(_en.message_title), findsNothing, reason: 'no admin message');
      expect(find.text(_en.got_it), findsOneWidget);
      expect(find.text(_en.open_card), findsOneWidget);
    });

    testWidgets('an admin message gets its own card and the default copy stays', (tester) async {
      await open(
          tester,
          MaintenanceStatus(
              mode: MaintenanceMode.readonly, message: 'Moving servers', endsAt: DateTime(2025, 1, 1, 13, 45)));

      expect(find.text(_en.message_title), findsOneWidget);
      expect(find.text('Moving servers'), findsOneWidget);
      expect(find.text(_en.ro_body), findsOneWidget);
      expect(tester.widget<Text>(find.text('Moving servers')).textDirection, TextDirection.ltr);
    });

    testWidgets('an Arabic admin message runs right to left', (tester) async {
      await open(tester, const MaintenanceStatus(mode: MaintenanceMode.readonly, message: 'ننقل الخوادم'));

      expect(tester.widget<Text>(find.text('ننقل الخوادم')).textDirection, TextDirection.rtl);
    });

    testWidgets('without an end: not announced, no progress bar', (tester) async {
      await open(tester, const MaintenanceStatus(mode: MaintenanceMode.readonly));

      expect(find.text(_en.left_unknown), findsOneWidget);
      expect(find.text(_en.end_unknown), findsOneWidget);
      expect(find.bySemanticsLabel(_en.progress_label), findsNothing);
    });

    testWidgets('the paused variant shows only what is still available', (tester) async {
      await open(tester, _window, paused: true);

      expect(find.text(_en.paused_title), findsOneWidget);
      expect(find.text(_en.paused_body(Gender.other)), findsOneWidget);
      expect(find.text(_en.still_available), findsOneWidget);
      expect(find.text(_en.paused_for_now), findsNothing);
      expect(find.text(_en.paused_log), findsNothing);
    });

    testWidgets('close and Got it dismiss it', (tester) async {
      await open(tester, _window);
      await tester.tap(find.bySemanticsLabel(_en.close));
      await tester.pumpAndSettle();
      expect(find.text(_en.ro_title), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(_en.got_it));
      await tester.tap(find.text(_en.got_it));
      await tester.pumpAndSettle();
      expect(find.text(_en.ro_title), findsNothing);
    });

    testWidgets('"Open my emergency card" opens the patient\'s own card over the sheet', (tester) async {
      await open(tester, _window);

      await tester.ensureVisible(find.text(_en.open_card));
      await tester.tap(find.text(_en.open_card));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OwnCardScreen), findsOneWidget);
    });
  });

  group('quick-log button', () {
    Widget fab() => MaintenanceFabLock(label: 'Quick log', onTap: () {}, child: const SizedBox(width: 52, height: 52));

    testWidgets('read-only: washed out, a lock badge, and "Adding is paused during maintenance"', (tester) async {
      await _pump(tester, _window, (_) => Center(child: fab()));

      expect(find.byKey(const ValueKey('maintenance-fab-lock')), findsOneWidget);
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.bySemanticsLabel(_en.fab_paused), findsOneWidget);
      expect(find.bySemanticsLabel('Quick log'), findsNothing);
    });

    for (final mode in [MaintenanceMode.off, MaintenanceMode.unknown]) {
      testWidgets('with mode $mode: as normal', (tester) async {
        await _pump(tester, MaintenanceStatus(mode: mode), (_) => Center(child: fab()));

        expect(find.byKey(const ValueKey('maintenance-fab-lock')), findsNothing);
        expect(find.bySemanticsLabel('Quick log'), findsOneWidget);
      });
    }
  });

  group('full-screen page', () {
    testWidgets('block, signed in: emergency card, emergency number and Check again', (tester) async {
      final pinned = await _pump(
        tester,
        const MaintenanceStatus(mode: MaintenanceMode.block, message: 'Upgrading the database'),
        (_) => const MaintenanceScreen(signedIn: true),
      );

      expect(find.text(_en.block_title), findsOneWidget);
      expect(find.text('Upgrading the database'), findsOneWidget);
      expect(find.text(_en.open_card), findsOneWidget);
      expect(find.text(_en.call_emergency(CountryCode.egypt.emergencyNumber, Gender.other)), findsOneWidget);
      expect(find.text(_en.end_unknown), findsOneWidget);

      await tester.tap(find.text(_en.check_again(Gender.other)));

      expect(pinned.checks, 1);
    });

    testWidgets('read-only before sign-in offers "Use on this device only"', (tester) async {
      var chose = false;
      await _pump(
        tester,
        const MaintenanceStatus(mode: MaintenanceMode.readonly),
        (_) => MaintenanceScreen(signedIn: false, onDeviceOnly: () => chose = true),
      );

      expect(find.text(_en.pre_body), findsOneWidget);
      expect(find.text(_en.open_card), findsNothing);

      await tester.tap(find.text(_en.device_only));

      expect(chose, isTrue);
    });

    testWidgets('block before sign-in does not offer device-only use', (tester) async {
      await _pump(
        tester,
        const MaintenanceStatus(mode: MaintenanceMode.block),
        (_) => MaintenanceScreen(signedIn: false, onDeviceOnly: () {}),
      );

      expect(find.text(_en.device_only), findsNothing);
    });

    testWidgets('while checking the button says so and is disabled', (tester) async {
      final pinned = await _pump(
        tester,
        const MaintenanceStatus(mode: MaintenanceMode.block, checking: true),
        (_) => const MaintenanceScreen(signedIn: true),
      );

      await tester.tap(find.text(_en.checking));

      expect(pinned.checks, 0);
    });
  });

  group('end time', () {
    testWidgets('tomorrow, past and unannounced ends', (tester) async {
      late BuildContext ctx;
      await _pump(tester, const MaintenanceStatus(), (context) {
        ctx = context;
        return const SizedBox();
      });
      final s = PatientAppState();

      expect(maintenanceEndText(ctx, s, DateTime(2025, 1, 2, 2), _now), _en.until_tomorrow('2:00 AM'));
      expect(maintenanceEndText(ctx, s, DateTime(2025, 1, 1, 11), _now), _en.end_unknown);
      expect(maintenanceEndText(ctx, s, null, _now), _en.end_unknown);
    });

    test('countdown: hours and minutes, whole hours, minutes, never below one, unannounced', () {
      final s = PatientAppState();

      expect(maintenanceLeftText(s, DateTime(2025, 1, 1, 13, 45), _now), 'Back in about 1 h 45 min');
      expect(maintenanceLeftText(s, DateTime(2025, 1, 1, 14), _now), 'Back in about 2 h');
      expect(maintenanceLeftText(s, DateTime(2025, 1, 1, 12, 40), _now), 'Back in about 40 min');
      expect(maintenanceLeftText(s, DateTime(2025, 1, 1, 12, 0, 10), _now), 'Back in about 1 min');
      expect(maintenanceLeftText(s, null, _now), 'Duration not announced yet');
      expect(maintenanceLeftText(s, DateTime(2025, 1, 1, 11), _now), 'Duration not announced yet');
    });

    test('progress: share of the window gone, clamped 0.04–1, none without an end', () {
      expect(maintenanceProgress(_window, _now), closeTo(1 / 2.75, 0.001));
      expect(
          maintenanceProgress(
              MaintenanceStatus(mode: MaintenanceMode.readonly, endsAt: DateTime(2025, 1, 1, 13)), _now),
          0.04,
          reason: 'no start: the window begins now');
      expect(maintenanceProgress(const MaintenanceStatus(mode: MaintenanceMode.readonly), _now), isNull);
    });
  });

  test('Arabic imperatives follow the patient\'s gender', () {
    final ar = stringsFor('ar').maintenance;

    expect(ar.check_again(Gender.female), 'تحقّقي مرة أخرى');
    expect(ar.check_again(Gender.male), 'تحقّق مرة أخرى');
    expect(ar.call_emergency('123', Gender.female), 'اتصلي بالطوارئ 123');
    expect(ar.call_emergency('123', Gender.other), 'اتصل بالطوارئ 123');
  });

  test('Arabic countdown', () {
    final ar = stringsFor('ar').maintenance;

    expect(ar.left_hm(1, 45), 'يعود خلال 1 س و45 د تقريباً');
    expect(ar.left_m(40), 'يعود خلال 40 دقيقة تقريباً');
    expect(ar.strip_a11y(ar.left_h(2)), 'تفاصيل الصيانة. يعود خلال 2 س تقريباً');
  });
}
