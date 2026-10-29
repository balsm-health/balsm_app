import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/auth/device_account_remover.dart';
import 'package:app/balsm_app/routes.dart';
import 'package:app/balsm_app/screens/remove_device_account.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemover extends Mock implements DeviceAccountRemover {}

/// Profile's "Remove this account from this phone" (what a device-only
/// account gets instead of Sign out): one confirmation, then the removal.
void main() {
  late _MockRemover remover;

  setUp(() => remover = _MockRemover());

  Future<PatientAppState> pump(WidgetTester tester, {required void Function(bool) onDone}) async {
    final state = PatientAppState()
      ..route = AppRoutes.app
      ..setAccountMode(AccountMode.deviceOnly);
    await tester.pumpWidget(ProviderScope(
      overrides: [deviceAccountRemoverProvider.overrideWithValue(remover)],
      child: AppScope(
        state: state,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                    onPressed: () async {
                      if (!await confirmRemoveDeviceAccount(context, state)) return onDone(false);
                      onDone(await removeDeviceAccount(ref, state));
                    },
                    child: const Text('remove')),
              ),
            ),
          ),
        ),
      ),
    ));
    return state;
  }

  testWidgets('confirmed: removes the account, resets the account state and returns to Welcome', (tester) async {
    when(() => remover.remove()).thenAnswer((_) async {});
    bool? done;
    final state = await pump(tester, onDone: (v) => done = v);
    state.addFamilyMember(name: 'n', relation: 'r');
    final a = state.strings.auth;

    await tester.tap(find.text('remove'));
    await tester.pumpAndSettle();
    expect(find.text(a.remove_device_confirm_title), findsOneWidget);
    expect(find.text(a.remove_device_confirm_body), findsOneWidget);
    verifyNever(() => remover.remove());

    await tester.tap(find.text(a.remove_device_confirm_btn));
    await tester.pumpAndSettle();

    verify(() => remover.remove()).called(1);
    expect(done, isTrue);
    expect(state.route, AppRoutes.welcome);
    expect(state.accountMode, AccountMode.online);
    expect(state.extraFamily, isEmpty);
  });

  testWidgets('cancelled: nothing is removed', (tester) async {
    bool? done;
    final state = await pump(tester, onDone: (v) => done = v);

    await tester.tap(find.text('remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(state.strings.common.cancel));
    await tester.pumpAndSettle();

    verifyNever(() => remover.remove());
    expect(done, isFalse);
    expect(state.route, AppRoutes.app);
  });

  testWidgets('a failed removal stays put and reports false', (tester) async {
    when(() => remover.remove()).thenThrow(Exception('keychain'));
    bool? done;
    final state = await pump(tester, onDone: (v) => done = v);

    await tester.tap(find.text('remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(state.strings.auth.remove_device_confirm_btn));
    await tester.pumpAndSettle();

    expect(done, isFalse);
    expect(state.route, AppRoutes.app);
    expect(state.accountMode, AccountMode.deviceOnly);
  });

  group('Sign out locks a device-only account (#122)', () {
    PatientAppState signedIn() => PatientAppState()
      ..route = AppRoutes.app
      ..setAccountMode(AccountMode.deviceOnly)
      ..setTab(AppTab.meds);

    test('it returns to Unlock, back on the Home tab', () {
      final state = signedIn();

      lockDeviceAccount(state);

      expect(state.route, AppRoutes.unlock);
      expect(state.tab, AppTab.home);
    });

    test('it keeps the account and what this phone knows about the patient', () {
      final state = signedIn()..addFamilyMember(name: 'n', relation: 'r');

      lockDeviceAccount(state);

      expect(state.accountMode, AccountMode.deviceOnly);
      expect(state.extraFamily, hasLength(1));
      verifyNever(() => remover.remove());
    });
  });
}
