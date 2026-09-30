import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/auth_flow.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart'
    show DisclosureAcceptance, DisclosureDao, DisclosureId, disclosureDaoProvider;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockDisclosureDao extends Mock implements DisclosureDao {}

class _MockOfflineAccountService extends Mock implements OfflineAccountService {}

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
  late _MockOfflineAccountService offline;

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
    offline = _MockOfflineAccountService();
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
        offlineAccountServiceProvider.overrideWithValue(offline),
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

  /// Welcome → the credential screen, with nothing typed in yet.
  Future<void> pumpPhoneScreen(WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
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

  testWidgets('a refusal is felt, not only shown', (tester) async {
    // The error line is visible and announced, which covers sight and screen
    // readers. A patient who is deaf and not using one gets neither a sound
    // nor speech, so the phone buzzes: a failure should register without
    // looking at the exact spot the message appears.
    final haptics = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments as String? ?? 'vibrate');
        return null;
      },
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AppResult.failure(const NetworkFailure('invalid')));

    await pump(tester);
    await enterCredentials(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(haptics, isNotEmpty, reason: 'the refusal should be felt');
  });

  testWidgets('backing out of the code step keeps what was typed', (tester) async {
    // The code did not arrive, or it went to the wrong address. Going back to
    // fix one character should not mean retyping an email and a password —
    // and a blank password field invites a different one, which then fails.
    when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => AppResult.failure(const NetworkFailure('invalid')));
    when(() => signIn.requestContinueOtp(any(), any())).thenAnswer((_) async => AppResult.success(null));

    await pump(tester);
    await enterCredentials(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.arrowLeft));
    await tester.pumpAndSettle();

    expect(find.text('patient@example.test'), findsOneWidget);
    final password = tester.widget<TextField>(find.byType(TextField).last);
    expect(password.controller?.text, 'a-real-password');
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

  group('Device only', () {
    testWidgets('hides forgot-password, shows warning, enforces 8 chars', (tester) async {
      await pumpPhoneScreen(tester);
      await tester.tap(find.text('Device only'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.textContaining("can't be recovered"), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'layla@example.com');
      await tester.enterText(find.byType(TextField).last, '1234567');
      await tester.pump();
      expect(
        tester.widget<PButton>(find.widgetWithText(PButton, 'Create account on device')).onTap,
        isNull,
      );
    });

    testWidgets('creates the account locally and never calls the API', (tester) async {
      when(() => offline.create(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => 'off-1');
      await pumpPhoneScreen(tester);
      await tester.tap(find.text('Device only'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'layla@example.com');
      await tester.enterText(find.byType(TextField).last, 'correct-horse');
      await tester.pump();
      await tester.tap(find.text('Create account on device'));
      await tester.pumpAndSettle();

      verify(() => offline.create(email: 'layla@example.com', password: 'correct-horse')).called(1);
      verifyNever(() => signIn.requestContinueOtp(any(), any()));
      expect(state.accountMode, AccountMode.deviceOnly);
    });

    testWidgets('switching away from an online refusal clears its send-code offer', (tester) async {
      // Review finding: the offer (and its network-hitting button) survived a
      // mode switch, because only `_mode` was reset, not `_offerCode`.
      when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => AppResult.failure(const NetworkFailure('invalid')));

      await pumpPhoneScreen(tester);
      await tester.enterText(find.byType(TextField).first, 'patient@example.test');
      await tester.enterText(find.byType(TextField).last, 'a-real-password');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Send me a code'), findsOneWidget, reason: 'setup: the refusal must offer a code first');

      await tester.tap(find.text('Device only'));
      await tester.pumpAndSettle();

      expect(find.text('Send me a code'), findsNothing);
      expect(
        tester.widget<PButton>(find.widgetWithText(PButton, 'Create account on device')).variant,
        BtnVariant.primary,
      );

      // And the button drives account creation, never the leftover OTP path.
      when(() => offline.create(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => 'off-1');
      await tester.enterText(find.byType(TextField).first, 'layla@example.com');
      await tester.enterText(find.byType(TextField).last, 'correct-horse');
      await tester.pump();
      await tester.tap(find.text('Create account on device'));
      await tester.pumpAndSettle();

      verify(() => offline.create(email: 'layla@example.com', password: 'correct-horse')).called(1);
      verifyNever(() => signIn.requestContinueOtp(any(), any()));
    });

    testWidgets('a create failure shows a retry message, never the exception', (tester) async {
      when(() => offline.create(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(Exception('secure storage unavailable'));

      await pumpPhoneScreen(tester);
      await tester.tap(find.text('Device only'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'layla@example.com');
      await tester.enterText(find.byType(TextField).last, 'correct-horse');
      await tester.pump();
      await tester.tap(find.text('Create account on device'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't create the account on this device"), findsOneWidget);
      expect(find.textContaining('secure storage unavailable'), findsNothing,
          reason: 'the exception text must never reach the screen');
      expect(state.accountMode, isNot(AccountMode.deviceOnly));
    });
  });
}
