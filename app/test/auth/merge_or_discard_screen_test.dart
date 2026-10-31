import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/auth/go_online_controller.dart';
import 'package:app/balsm_app/prefs.dart';
import 'package:app/balsm_app/routes.dart';
import 'package:app/balsm_app/screens/auth_flow.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart'
    show DisclosureAcceptance, DisclosureDao, DisclosureId, disclosureDaoProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockController extends Mock implements GoOnlineController {}

class _MockDisclosureDao extends Mock implements DisclosureDao {}

class _MemoryKV implements GlobalKVDataSource {
  final Map<String, Object?> store = {};
  @override
  Future<T?> get<T>(String key) async => store[key] as T?;
  @override
  Future<bool> exists(String key) async => store.containsKey(key);
  @override
  Future<void> put<T>(String key, T value) async => store[key] = value;
  @override
  Future<void> delete(String key) async => store.remove(key);
  @override
  Future<void> clear() async => store.clear();
}

void main() {
  late _MockController controller;
  late _MockDisclosureDao dao;

  setUpAll(() => registerFallbackValue(const DisclosureId.value('consolidated')));

  setUp(() {
    // Reaching 'app' re-renders AuthRouter's fallback, which reads the flavor.
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
    );
    controller = _MockController();
    when(() => controller.pendingChoice()).thenAnswer((_) async => null);
    dao = _MockDisclosureDao();
    // The disclosure accepted while offline is already on the device.
    when(() => dao.watchAcceptance(any(), any())).thenAnswer((_) => Stream.value(DisclosureAcceptance(
          disclosureId: const DisclosureId.value('consolidated'),
          version: '1',
          countryCodeAtAccept: 'EG',
          supervisoryAuthorityNameAtAccept: 'x',
          preferredLanguageAtAccept: 'en',
          acceptedAt: DateTime.utc(2026),
        )));
  });

  Future<void> pump(WidgetTester tester, PatientAppState state) async {
    tester.view.physicalSize = const Size(402, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        goOnlineControllerProvider.overrideWithValue(controller),
        disclosureDaoProvider.overrideWithValue(dao),
      ],
      child: MaterialApp(
        home: Material(
          type: MaterialType.transparency,
          child: AppScope(state: state, child: const AuthRouter()),
        ),
      ),
    ));
    await tester.pump();
  }

  PatientAppState atMerge() => PatientAppState()
    ..route = AppRoutes.mergeOrDiscard
    ..setAccountMode(AccountMode.deviceOnly);

  testWidgets('shows both choices and the password note', (tester) async {
    final state = atMerge();
    await pump(tester, state);
    final st = state.strings.offline;
    expect(find.text(st.merge_title), findsOneWidget);
    expect(find.text(st.merge_note), findsOneWidget);
    expect(find.text(st.merge_btn), findsOneWidget);
    expect(find.text(st.discard_btn), findsOneWidget);
  });

  testWidgets('merge runs the merge, marks the account online and enters the app', (tester) async {
    when(() => controller.merge()).thenAnswer((_) async => AppResult.success(null));
    final state = atMerge();
    await pump(tester, state);

    await tester.tap(find.text(state.strings.offline.merge_btn));
    await tester.pumpAndSettle();

    verify(() => controller.merge()).called(1);
    verifyNever(() => controller.discard());
    expect(state.accountMode, AccountMode.online);
    expect(state.route, AppRoutes.app);
  });

  testWidgets('discard needs a second confirmation before anything is deleted', (tester) async {
    when(() => controller.discard()).thenAnswer((_) async => AppResult.success(null));
    final state = atMerge();
    await pump(tester, state);
    final st = state.strings.offline;

    // First tap only asks.
    await tester.tap(find.text(st.discard_btn));
    await tester.pumpAndSettle();
    expect(find.text(st.discard_confirm_title), findsOneWidget);
    verifyNever(() => controller.discard());

    // Cancel: nothing happens, still on the choice.
    await tester.tap(find.text(state.strings.common.cancel));
    await tester.pumpAndSettle();
    verifyNever(() => controller.discard());
    expect(state.route, AppRoutes.mergeOrDiscard);

    // Confirmed: discard runs, then the app.
    await tester.tap(find.text(st.discard_btn));
    await tester.pumpAndSettle();
    await tester.tap(find.text(st.discard_confirm_btn));
    await tester.pumpAndSettle();
    verify(() => controller.discard()).called(1);
    expect(state.accountMode, AccountMode.online);
    expect(state.route, AppRoutes.app);
  });

  testWidgets('a failure stays on the screen with a retry message, and can be retried', (tester) async {
    when(() => controller.merge()).thenAnswer((_) async => AppResult.failure(const StorageFailure()));
    final state = atMerge();
    await pump(tester, state);
    final st = state.strings.offline;

    await tester.tap(find.text(st.merge_btn));
    await tester.pumpAndSettle();
    expect(find.text(st.merge_failed(Gender.other)), findsOneWidget);
    expect(state.route, AppRoutes.mergeOrDiscard);
    expect(state.accountMode, AccountMode.deviceOnly);

    when(() => controller.merge()).thenThrow(Exception('keychain'));
    await tester.tap(find.text(st.merge_btn));
    await tester.pumpAndSettle();
    expect(find.text(st.merge_failed(Gender.other)), findsOneWidget);
    expect(find.textContaining('keychain'), findsNothing);
  });

  testWidgets('a restart with a pending merge boots back onto this screen', (tester) async {
    // A choice interrupted by a crash: the keys are still set at next boot.
    final state = await tester.runAsync(() => PatientAppState.load(PatientAppPrefs(_MemoryKV()),
        hasSession: true, accountMode: AccountMode.deviceOnly, pendingMerge: true));
    expect(state!.route, AppRoutes.mergeOrDiscard);

    await pump(tester, state);
    expect(find.text(state.strings.offline.merge_title), findsOneWidget);
  });

  testWidgets('a merge that failed part-way offers only finishing the merge', (tester) async {
    when(() => controller.merge()).thenAnswer((_) async => AppResult.failure(const StorageFailure()));
    final state = atMerge();
    await pump(tester, state);
    final st = state.strings.offline;

    // The DB half committed; the controller now records the choice.
    when(() => controller.pendingChoice()).thenAnswer((_) async => MergeChoice.merge);
    await tester.tap(find.text(st.merge_btn));
    await tester.pumpAndSettle();
    expect(find.text(st.merge_failed(Gender.other)), findsOneWidget);
    expect(find.text(st.merge_btn), findsOneWidget);
    expect(find.text(st.discard_btn), findsNothing);
  });

  testWidgets('after a restart mid-discard, only Remove is offered', (tester) async {
    when(() => controller.pendingChoice()).thenAnswer((_) async => MergeChoice.discard);
    final state = atMerge();
    await pump(tester, state);
    await tester.pumpAndSettle();
    final st = state.strings.offline;
    expect(find.text(st.discard_btn), findsOneWidget);
    expect(find.text(st.merge_btn), findsNothing);
  });

  testWidgets('after a restart mid-merge, only finishing the merge is offered', (tester) async {
    when(() => controller.pendingChoice()).thenAnswer((_) async => MergeChoice.merge);
    final state = atMerge();
    await pump(tester, state);
    await tester.pumpAndSettle();
    final st = state.strings.offline;
    expect(find.text(st.merge_btn), findsOneWidget);
    expect(find.text(st.discard_btn), findsNothing);
  });
}
