import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/maintenance/maintenance_controller.dart';
import 'package:app/balsm_app/maintenance/maintenance_guard.dart';
import 'package:app/balsm_app/maintenance/maintenance_widgets.dart';
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

Future<_Pinned> _pump(WidgetTester tester, MaintenanceStatus status, Widget Function(BuildContext) body) async {
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
      expect(find.text(_en.paused_log), findsOneWidget);
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
    testWidgets('shows in read-only with the end time and opens the details', (tester) async {
      await _pump(
        tester,
        MaintenanceStatus(mode: MaintenanceMode.readonly, endsAt: DateTime(2025, 1, 1, 14)),
        (_) => const Align(alignment: Alignment.bottomCenter, child: MaintenanceStrip()),
      );

      expect(find.text(_en.strip_title), findsOneWidget);
      expect(find.text(_en.until('2:00 PM')), findsOneWidget);

      await tester.tap(find.text(_en.strip_details));
      await tester.pumpAndSettle();

      expect(find.text(_en.ro_title), findsOneWidget);
    });

    for (final mode in [MaintenanceMode.off, MaintenanceMode.block, MaintenanceMode.unknown]) {
      testWidgets('is hidden when mode is $mode', (tester) async {
        await _pump(tester, MaintenanceStatus(mode: mode), (_) => const MaintenanceStrip());

        expect(find.text(_en.strip_title), findsNothing);
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
  });

  test('Arabic imperatives follow the patient\'s gender', () {
    final ar = stringsFor('ar').maintenance;

    expect(ar.check_again(Gender.female), 'تحقّقي مرة أخرى');
    expect(ar.check_again(Gender.male), 'تحقّق مرة أخرى');
    expect(ar.call_emergency('123', Gender.female), 'اتصلي بالطوارئ 123');
    expect(ar.call_emergency('123', Gender.other), 'اتصل بالطوارئ 123');
  });
}
