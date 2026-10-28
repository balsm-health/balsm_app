import 'dart:async';

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/auth/device_account_remover.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/routes.dart';
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

class _MockSignUpUseCase extends Mock implements SignUpUseCase {}

class _MockDisclosureDao extends Mock implements DisclosureDao {}

class _MockOfflineAccountService extends Mock implements OfflineAccountService {}

class _MockRemover extends Mock implements DeviceAccountRemover {}

/// Basic auth (design: auth.jsx). Welcome offers three ways in — create an
/// account, sign in, or use the app on this device only — and the credential
/// screen follows the one that was tapped.
///
/// The screens still never say whether an address has an account. The server
/// answers one uniform failure for "no account", "no password set" and "wrong
/// password", and sends a sign-up code whether or not the address is taken, so
/// nothing on screen can depend on which.
void main() {
  late PatientAppState state;
  late _MockSignInUseCase signIn;
  late _MockSignUpUseCase signUp;
  late _MockDisclosureDao disclosure;
  late _MockOfflineAccountService offline;
  late _MockRemover remover;

  setUpAll(() => registerFallbackValue(const DisclosureId.value('consolidated')));

  setUp(() {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
    );
    state = PatientAppState();
    signIn = _MockSignInUseCase();
    signUp = _MockSignUpUseCase();
    disclosure = _MockDisclosureDao();
    offline = _MockOfflineAccountService();
    remover = _MockRemover();
    when(() => offline.pendingMerge()).thenAnswer((_) async => false);
    when(() => disclosure.watchAcceptance(any(), any())).thenAnswer((_) => Stream<DisclosureAcceptance?>.value(null));
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        signInUseCaseProvider.overrideWithValue(signIn),
        signUpUseCaseProvider.overrideWithValue(signUp),
        disclosureDaoProvider.overrideWithValue(disclosure),
        offlineAccountServiceProvider.overrideWithValue(offline),
        deviceAccountRemoverProvider.overrideWithValue(remover),
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

  /// Lands directly on [route] via the state machine — for screens reached
  /// by routing logic (cold-start boot) rather than a tap chain from Welcome.
  Future<void> pumpAtRoute(WidgetTester tester, String route) async {
    state.route = route;
    await pump(tester);
  }

  /// Welcome → the credential screen through [button], with nothing typed.
  Future<void> open(WidgetTester tester, String button) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(PButton, button));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester,
      {String email = 'patient@example.test', String password = 'a-real-password'}) async {
    await tester.enterText(find.byType(TextField).first, email);
    await tester.enterText(find.byType(TextField).last, password);
    await tester.pump();
  }

  void refusePassword() =>
      when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => AppResult.failure(const NetworkFailure('invalid')));

  void sendCodes() => when(() => signUp.requestEmailOtp(any(), any())).thenAnswer((_) async => AppResult.success(null));

  testWidgets('welcome offers three ways in', (tester) async {
    await pump(tester);

    expect(find.widgetWithText(PButton, 'Create an account'), findsOneWidget);
    expect(find.widgetWithText(PButton, 'Sign in'), findsOneWidget);
    expect(find.widgetWithText(PButton, 'Use on this device only'), findsOneWidget);
  });

  group('Sign in', () {
    testWidgets('asks for email and password, with recovery', (tester) async {
      await open(tester, 'Sign in');

      expect(find.text('Enter your email and password.'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.textContaining('New to Balsm?', findRichText: true), findsOneWidget);
    });

    testWidgets('a refused password says so, and never sends a code', (tester) async {
      refusePassword();

      await open(tester, 'Sign in');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
      verifyNever(() => signUp.requestEmailOtp(any(), any()));
    });

    testWidgets('the refusal does not say whether the account exists', (tester) async {
      refusePassword();

      await open(tester, 'Sign in');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no account', findRichText: true), findsNothing);
      expect(find.textContaining('already', findRichText: true), findsNothing);
    });

    testWidgets('a lockout shows the wait, and never sends a code', (tester) async {
      when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password'))).thenAnswer(
        (_) async => AppResult.success(SignInLockout(
          session: LockedOut(
            until: DateTime.now().toUtc().add(const Duration(minutes: 5)),
            identifier: 'patient@example.test',
          ),
        )),
      );

      await open(tester, 'Sign in');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Sign in'));
      await tester.pumpAndSettle();

      verifyNever(() => signUp.requestEmailOtp(any(), any()));
      expect(find.textContaining('Invalid email or password'), findsNothing);
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
      refusePassword();

      await open(tester, 'Sign in');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(haptics, isNotEmpty, reason: 'the refusal should be felt');
    });

    testWidgets('"Create an account" switches to sign-up and keeps what was typed', (tester) async {
      await open(tester, 'Sign in');
      await type(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(state.authIntent, AuthIntent.signUp);
      expect(find.widgetWithText(PButton, 'Send code'), findsOneWidget);
      expect(find.text('patient@example.test'), findsOneWidget);
    });

    testWidgets('the switch is inert while a sign-in is in flight', (tester) async {
      // A switch mid-sign-in would orphan the in-flight request's UI state.
      final pending = Completer<AppResult<SignInResult>>();
      when(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) => pending.future);

      await open(tester, 'Sign in');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Sign in'));
      await tester.pump(); // submitting flips true; passwordSignIn is still pending

      await tester.tap(find.text('Create an account'));
      await tester.pump();

      expect(state.authIntent, AuthIntent.signIn, reason: 'mode must not switch while submitting');
    });
  });

  group('Create an account', () {
    testWidgets('asks for a new password, with no recovery link', (tester) async {
      await open(tester, 'Create an account');

      expect(find.text('Forgot password?'), findsNothing);
      expect(find.textContaining('Have an account?', findRichText: true), findsOneWidget);
    });

    testWidgets('send code asks for the code and never tries the password', (tester) async {
      sendCodes();

      await open(tester, 'Create an account');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Send code'));
      await tester.pumpAndSettle();

      verify(() => signUp.requestEmailOtp('patient@example.test', any())).called(1);
      verifyNever(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')));
      expect(state.route, AppRoutes.otp);
      expect(state.authPassword, 'a-real-password', reason: 'set once the code proves the address');
    });

    testWidgets('the code step confirms the email and says nothing about whether it was taken', (tester) async {
      sendCodes();

      await open(tester, 'Create an account');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Send code'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.textContaining('Enter the 6-digit code we sent to', findRichText: true), findsOneWidget);
      // One note for everyone, so it cannot tell a new address from a known one.
      expect(find.text("If this email already has an account, you'll be signed in to it."), findsOneWidget);
      expect(find.textContaining('no account', findRichText: true), findsNothing);
    });

    testWidgets('an address the server calls registered stays on the screen and points to sign in', (tester) async {
      // Only while the server holds sign-up strict (email quota or abuse).
      when(() => signUp.requestEmailOtp(any(), any()))
          .thenAnswer((_) async => AppResult.failure(const ConflictFailure()));

      await open(tester, 'Create an account');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Send code'));
      await tester.pumpAndSettle();

      expect(state.route, AppRoutes.phone);
      expect(find.text('This email already has an account. Sign in instead.'), findsOneWidget);
      expect(find.textContaining('Have an account?', findRichText: true), findsOneWidget);
      expect(state.authPassword, isNull);
    });

    testWidgets('backing out of the code step keeps what was typed', (tester) async {
      // The code did not arrive, or it went to the wrong address. Going back to
      // fix one character should not mean retyping an email and a password.
      sendCodes();

      await open(tester, 'Create an account');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Send code'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pumpAndSettle();

      expect(find.text('patient@example.test'), findsOneWidget);
      final password = tester.widget<TextField>(find.byType(TextField).last);
      expect(password.controller?.text, 'a-real-password');
    });

    testWidgets('a failed send stays on the screen', (tester) async {
      when(() => signUp.requestEmailOtp(any(), any()))
          .thenAnswer((_) async => AppResult.failure(const NetworkFailure('Connection refused')));

      await open(tester, 'Create an account');
      await type(tester);
      await tester.tap(find.widgetWithText(PButton, 'Send code'));
      await tester.pumpAndSettle();

      expect(state.route, AppRoutes.phone);
      expect(state.authPassword, isNull);
    });
  });

  group('Device only', () {
    testWidgets('hides forgot-password and sign-up, shows warning, enforces 8 chars', (tester) async {
      await open(tester, 'Use on this device only');
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.textContaining('New to Balsm?', findRichText: true), findsNothing);
      expect(find.textContaining("can't be recovered"), findsOneWidget);

      await type(tester, email: 'layla@example.com', password: '1234567');
      expect(
        tester.widget<PButton>(find.widgetWithText(PButton, 'Create account on device')).onTap,
        isNull,
      );
    });

    testWidgets('creates the account locally and never calls the API', (tester) async {
      when(() => offline.create(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => 'off-1');
      await open(tester, 'Use on this device only');
      await type(tester, email: 'layla@example.com', password: 'correct-horse');
      await tester.tap(find.text('Create account on device'));
      await tester.pumpAndSettle();

      verify(() => offline.create(email: 'layla@example.com', password: 'correct-horse')).called(1);
      verifyNever(() => signUp.requestEmailOtp(any(), any()));
      verifyNever(() => signIn.passwordSignIn(email: any(named: 'email'), password: any(named: 'password')));
      expect(state.accountMode, AccountMode.deviceOnly);
    });

    testWidgets('a create failure shows a retry message, never the exception', (tester) async {
      when(() => offline.create(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(Exception('secure storage unavailable'));

      await open(tester, 'Use on this device only');
      await type(tester, email: 'layla@example.com', password: 'correct-horse');
      await tester.tap(find.text('Create account on device'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't create the account on this device"), findsOneWidget);
      expect(find.textContaining('secure storage unavailable'), findsNothing,
          reason: 'the exception text must never reach the screen');
      expect(state.accountMode, isNot(AccountMode.deviceOnly));
    });
  });

  group('Unlock', () {
    testWidgets('right password enters the app', (tester) async {
      when(() => offline.lockout()).thenAnswer((_) async => null);
      when(() => offline.unlock('correct-horse')).thenAnswer((_) async => const Unlocked());

      await pumpAtRoute(tester, AppRoutes.unlock);
      await tester.enterText(find.byType(TextField), 'correct-horse');
      await tester.pump();
      // Captured before the tap — the screen unmounts once the route moves
      // to 'app', but the controller object itself survives disposal, so
      // this is still how to prove the password didn't linger in it.
      final pwCtrl = tester.widget<TextField>(find.byType(TextField)).controller!;
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(state.route, AppRoutes.app);
      expect(pwCtrl.text, '', reason: 'the password must not linger in the controller after unlocking');
    });

    testWidgets('right password with a merge still pending goes to the merge screen', (tester) async {
      when(() => offline.lockout()).thenAnswer((_) async => null);
      when(() => offline.unlock('correct-horse')).thenAnswer((_) async => const Unlocked());
      when(() => offline.pendingMerge()).thenAnswer((_) async => true);

      await pumpAtRoute(tester, AppRoutes.unlock);
      await tester.enterText(find.byType(TextField), 'correct-horse');
      await tester.pump();
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      await tester.pump();

      expect(state.route, AppRoutes.mergeOrDiscard);
    });

    testWidgets('the title is announced as a heading', (tester) async {
      when(() => offline.lockout()).thenAnswer((_) async => null);
      await pumpAtRoute(tester, AppRoutes.unlock);
      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.text('Unlock Balsm')), matchesSemantics(isHeader: true, label: 'Unlock Balsm'));
      handle.dispose();
    });

    testWidgets('forgot password: two confirmations, then the account is removed and Welcome shows', (tester) async {
      when(() => offline.lockout()).thenAnswer((_) async => null);
      when(() => remover.remove()).thenAnswer((_) async {});
      state.setAccountMode(AccountMode.deviceOnly);
      await pumpAtRoute(tester, AppRoutes.unlock);
      final a = state.strings.auth;

      await tester.tap(find.text(a.unlock_forgot));
      await tester.pumpAndSettle();
      expect(find.text(a.unlock_forgot_confirm_body), findsOneWidget);
      verifyNever(() => remover.remove());

      // First confirmation only leads to the second.
      await tester.tap(find.text(a.remove_device_confirm_btn));
      await tester.pumpAndSettle();
      expect(find.text(a.remove_device_confirm_body), findsOneWidget);
      verifyNever(() => remover.remove());

      await tester.tap(find.text(a.remove_device_confirm_btn));
      await tester.pumpAndSettle();
      verify(() => remover.remove()).called(1);
      expect(state.route, AppRoutes.welcome);
      expect(state.accountMode, AccountMode.online);
    });

    testWidgets('forgot password: cancelling either step removes nothing', (tester) async {
      when(() => offline.lockout()).thenAnswer((_) async => null);
      await pumpAtRoute(tester, AppRoutes.unlock);
      final a = state.strings.auth;

      await tester.tap(find.text(a.unlock_forgot));
      await tester.pumpAndSettle();
      await tester.tap(find.text(state.strings.common.cancel));
      await tester.pumpAndSettle();

      await tester.tap(find.text(a.unlock_forgot));
      await tester.pumpAndSettle();
      await tester.tap(find.text(a.remove_device_confirm_btn));
      await tester.pumpAndSettle();
      await tester.tap(find.text(state.strings.common.cancel));
      await tester.pumpAndSettle();

      verifyNever(() => remover.remove());
      expect(state.route, AppRoutes.unlock);
    });

    testWidgets('an unlock failure shows a retry message, never the exception', (tester) async {
      when(() => offline.lockout()).thenAnswer((_) async => null);
      when(() => offline.unlock('correct-horse')).thenThrow(Exception('secure storage unavailable'));

      await pumpAtRoute(tester, AppRoutes.unlock);
      await tester.enterText(find.byType(TextField), 'correct-horse');
      await tester.pump();
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't unlock right now. Try again."), findsOneWidget);
      expect(find.textContaining('secure storage unavailable'), findsNothing,
          reason: 'the exception text must never reach the screen');
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
      expect(state.route, isNot(AppRoutes.app));
    });

    testWidgets('lockout disables the button and counts down', (tester) async {
      final until = DateTime.now().toUtc().add(const Duration(seconds: 30));
      when(() => offline.lockout()).thenAnswer((_) async => LockedUntil(until));

      await pumpAtRoute(tester, AppRoutes.unlock);
      await tester.pump();

      expect(find.textContaining('Try again in'), findsOneWidget);
      expect(
        tester.widget<PButton>(find.widgetWithText(PButton, 'Unlock')).onTap,
        isNull,
      );
    });

    testWidgets('the countdown ticks down once a second', (tester) async {
      final until = DateTime.now().toUtc().add(const Duration(seconds: 3));
      when(() => offline.lockout()).thenAnswer((_) async => LockedUntil(until));

      await pumpAtRoute(tester, AppRoutes.unlock);
      await tester.pump();
      expect(find.textContaining('Try again in 3s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Try again in 2s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Try again in 1s'), findsOneWidget);
    });

    testWidgets('a wrong password shows the retry message and clears the field', (tester) async {
      when(() => offline.lockout()).thenAnswer((_) async => null);
      when(() => offline.unlock('nope')).thenAnswer((_) async => const WrongPassword(1));

      await pumpAtRoute(tester, AppRoutes.unlock);
      await tester.enterText(find.byType(TextField), 'nope');
      await tester.pump();
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('Wrong password.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
      expect(state.route, isNot(AppRoutes.app));
    });
  });
}
