import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/auth/go_online_controller.dart';
import 'package:app/balsm_app/routes.dart';
import 'package:app/balsm_app/screens/go_online_sheet.dart';
import 'package:app/balsm_app/screens/storage_sheet.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockController extends Mock implements GoOnlineController {}

class _MockOffline extends Mock implements OfflineAccountService {}

void main() {
  late _MockController controller;
  late _MockOffline offline;

  setUp(() {
    controller = _MockController();
    offline = _MockOffline();
    when(() => offline.pendingCredentials()).thenAnswer((_) async => (email: 'a@b.co', password: 'correct-horse'));
    when(() => controller.lockedUntil).thenReturn(null);
  });

  /// Pumps a page with one button that runs [onTap] with a live context/ref.
  Future<PatientAppState> pump(
    WidgetTester tester, {
    required AccountMode mode,
    required Future<void> Function(BuildContext context, WidgetRef ref) onTap,
  }) async {
    final state = PatientAppState()..setAccountMode(mode);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        goOnlineControllerProvider.overrideWithValue(controller),
        offlineAccountServiceProvider.overrideWithValue(offline),
      ],
      child: AppScope(
        state: state,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => onTap(context, ref), child: const Text('open')),
              ),
            ),
          ),
        ),
      ),
    ));
    return state;
  }

  testWidgets('walks email → code → done and marks the account online', (tester) async {
    when(() => controller.sendCode('a@b.co')).thenAnswer((_) async => AppResult.success(null));
    when(() => controller.verify(email: 'a@b.co', code: '123456'))
        .thenAnswer((_) async => AppResult.success(GoOnlineOutcome.online));
    final state = await pump(tester, mode: AccountMode.deviceOnly, onTap: (context, _) => showGoOnlineSheet(context));
    final st = state.strings.offline;

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(st.go_title), findsOneWidget);
    // Prefilled from the device-only account's email.
    expect(find.widgetWithText(TextField, 'a@b.co'), findsOneWidget);

    await tester.tap(find.text(st.go_send));
    await tester.pumpAndSettle();
    verify(() => controller.sendCode('a@b.co')).called(1);
    expect(find.textContaining(st.go_code_help, findRichText: true), findsOneWidget);

    // Sixth digit auto-submits.
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
    verify(() => controller.verify(email: 'a@b.co', code: '123456')).called(1);
    expect(find.text(st.go_done_title), findsOneWidget);
    expect(state.accountMode, AccountMode.online);

    await tester.tap(find.text(st.go_done));
    await tester.pumpAndSettle();
    expect(find.text(st.go_done_title), findsNothing);
  });

  testWidgets('existing account closes the sheet and routes to merge-or-discard', (tester) async {
    when(() => controller.sendCode(any())).thenAnswer((_) async => AppResult.success(null));
    when(() => controller.verify(email: any(named: 'email'), code: any(named: 'code')))
        .thenAnswer((_) async => AppResult.success(GoOnlineOutcome.needsMergeChoice));
    final state = await pump(tester, mode: AccountMode.deviceOnly, onTap: (context, _) => showGoOnlineSheet(context));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(state.strings.offline.go_send));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(find.text(state.strings.offline.go_title), findsNothing);
    expect(state.route, AppRoutes.mergeOrDiscard);
    expect(state.accountMode, AccountMode.deviceOnly);
  });

  testWidgets('requireOnline is true at once when already online', (tester) async {
    bool? result;
    final state = await pump(tester,
        mode: AccountMode.online, onTap: (context, ref) async => result = await requireOnline(context, ref));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text(state.strings.offline.go_title), findsNothing);
  });

  testWidgets('requireOnline opens the sheet when device-only, false if dismissed', (tester) async {
    bool? result;
    final state = await pump(tester,
        mode: AccountMode.deviceOnly, onTap: (context, ref) async => result = await requireOnline(context, ref));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(state.strings.offline.go_title), findsOneWidget);

    // Dismissed without going online.
    Navigator.of(tester.element(find.text(state.strings.offline.go_title))).pop();
    await tester.pumpAndSettle();
    expect(find.text(state.strings.offline.go_title), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('storage sheet: device-only offers Go online on Balsm Cloud only', (tester) async {
    final state =
        await pump(tester, mode: AccountMode.deviceOnly, onTap: (context, _) async => showStorageSync(context));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final st = state.strings;

    expect(find.text(st.offline.go_cloud_pill), findsOneWidget);
    expect(find.text(st.storage.store_coming_soon), findsNWidgets(2)); // iCloud + Google Drive

    await tester.tap(find.text(st.offline.go_cloud_pill));
    await tester.pumpAndSettle();
    expect(find.text(st.offline.go_help), findsOneWidget);
  });

  testWidgets('storage sheet: online accounts see no Go online pill', (tester) async {
    final state = await pump(tester, mode: AccountMode.online, onTap: (context, _) async => showStorageSync(context));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(state.strings.offline.go_cloud_pill), findsNothing);
    expect(find.text(state.strings.storage.store_coming_soon), findsNWidgets(3));
  });
}
