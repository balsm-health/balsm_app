import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/auth_flow.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart'
    show DisclosureAcceptance, DisclosureDao, DisclosureId, disclosureDaoProvider;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockDisclosureDao extends Mock implements DisclosureDao {}

/// One entry for everyone: email + password, and a code when that is refused.
///
/// The screens must never say whether an address has an account. The server
/// answers one uniform failure for "no account", "no password set" and "wrong
/// password", so the app branches on the failure — never on existence — and
/// the code step reads identically in every case.
void main() {
  late PatientAppState state;
  late _MockSignInUseCase signIn;
  late _MockDisclosureDao disclosure;

  setUpAll(() => registerFallbackValue(const DisclosureId.value('consolidated')));

  setUp(() {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
    );
    state = PatientAppState();
    signIn = _MockSignInUseCase();
    disclosure = _MockDisclosureDao();
    when(() => disclosure.watchAcceptance(any(), any())).thenAnswer((_) => Stream<DisclosureAcceptance?>.value(null));
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        signInUseCaseProvider.overrideWithValue(signIn),
        disclosureDaoProvider.overrideWithValue(disclosure),
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

  /// Welcome → the one credential screen, with credentials typed in.
  Future<void> enterCredentials(WidgetTester tester) async {
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'patient@example.test');
    await tester.enterText(find.byType(TextField).last, 'a-real-password');
    await tester.pump();
  }

  testWidgets('welcome offers one way in', (tester) async {
    await pump(tester);

    expect(find.text('Get started'), findsOneWidget);
    // The separate sign-in route is gone: one screen serves both.
    expect(find.textContaining('I already have an account', findRichText: true), findsNothing);
  });

  testWidgets('the credential screen names neither audience', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(find.text('Create your account'), findsNothing);
    expect(find.text('Welcome back'), findsNothing);
    // Recovery is offered to everyone — the screen does not know who has a
    // password to forget.
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('a refused password offers a code, and sends nothing until asked', (tester) async {
    when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AppResult.failure(const NetworkFailure('invalid')));

    await pump(tester);
    await enterCredentials(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Send a code to'), findsOneWidget);
    expect(find.text('Send me a code'), findsOneWidget);
    verifyNever(() => signIn.requestContinueOtp(any(), any()));
  });

  testWidgets('tapping send asks for the merged-entry code', (tester) async {
    when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AppResult.failure(const NetworkFailure('invalid')));
    when(() => signIn.requestContinueOtp(any(), any())).thenAnswer((_) async => AppResult.success(null));

    await pump(tester);
    await enterCredentials(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();

    verify(() => signIn.requestContinueOtp('patient@example.test', any())).called(1);
  });

  testWidgets('a lockout is not a way around the lockout', (tester) async {
    when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password'))).thenAnswer(
      (_) async => AppResult.success(SignInLockout(
        session: LockedOut(
          until: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          identifier: 'patient@example.test',
        ),
      )),
    );

    await pump(tester);
    await enterCredentials(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Send me a code'), findsNothing, reason: 'a locked account must not be offered a code');
  });

  testWidgets('an unreachable server does not email anyone', (tester) async {
    // A connection failure is not an invalid credential. Falling through would
    // send a code because the Wi-Fi dropped.
    when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AppResult.failure(const NetworkFailure('Connection refused')));

    await pump(tester);
    await enterCredentials(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    verifyNever(() => signIn.requestContinueOtp(any(), any()));
  });

  testWidgets('the code step says nothing about whether the account existed', (tester) async {
    when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AppResult.failure(const NetworkFailure('invalid')));
    when(() => signIn.requestContinueOtp(any(), any())).thenAnswer((_) async => AppResult.success(null));

    await pump(tester);
    await enterCredentials(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enter the 6-digit code we sent to', findRichText: true), findsOneWidget);
    expect(find.textContaining('no account', findRichText: true), findsNothing);
    expect(find.textContaining('already', findRichText: true), findsNothing);
  });
}
