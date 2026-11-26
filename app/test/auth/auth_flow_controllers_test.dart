import 'dart:async';

import 'package:app/balsm_app/auth/auth_flow_controllers.dart';
import 'package:app/balsm_app/auth/go_online_controller.dart';
import 'package:app/balsm_app/screens/auth_flow.dart' show kDisclosureId, kDisclosureVersion;
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSignIn extends Mock implements SignInUseCase {}

class _MockOffline extends Mock implements OfflineAccountService {}

class _MockGoOnline extends Mock implements GoOnlineController {}

class _MockSocial extends Mock implements SocialCredentialsPort {}

class _MockDisclosure extends Mock implements AcceptDisclosureUseCase {}

/// The auth-flow controllers as plain state transitions, with no widget: what
/// each call leaves in state and what it hands back to the screen. Every value
/// is synthetic (no real address, name or password).
void main() {
  late _MockSignIn signIn;
  late _MockOffline offline;
  late _MockGoOnline goOnline;
  late _MockSocial social;
  late _MockDisclosure disclosure;
  late ProviderContainer container;

  setUp(() {
    signIn = _MockSignIn();
    offline = _MockOffline();
    goOnline = _MockGoOnline();
    social = _MockSocial();
    disclosure = _MockDisclosure();
    container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        signInUseCaseProvider.overrideWithValue(signIn),
        offlineAccountServiceProvider.overrideWithValue(offline),
        goOnlineControllerProvider.overrideWithValue(goOnline),
        googleCredentialsPortProvider.overrideWithValue(social),
        acceptDisclosureUseCaseProvider.overrideWithValue(disclosure),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Keeps an auto-dispose provider alive for the test, as its screen would.
  void keepAlive(ProviderListenable<Object?> p) => container.listen(p, (_, __) {});

  group('Countdown', () {
    test('ticks down once a second and stops at zero', () async {
      final ticks = <int>[];
      final c = Countdown(ticks.add)..start(2);
      addTearDown(c.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      expect(ticks, [1, 0]);
    });

    test('cancel stops it; a zero start never ticks', () async {
      final ticks = <int>[];
      Countdown(ticks.add)
        ..start(5)
        ..cancel()
        ..start(0);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(ticks, isEmpty);
    });
  });

  group('AuthError and state equality', () {
    test('compare by value over every field', () {
      expect(const AuthError.lockout(5), const AuthError.lockout(5));
      expect(const AuthError.lockout(5) == const AuthError.lockout(6), isFalse);
      expect(const AuthError.server('a') == const AuthError.server('b'), isFalse);
      expect(
        const OtpState(error: AuthError.failed()),
        const OtpState().copyWith(error: const AuthError.failed()),
      );
      expect(const OtpState(notice: OtpNotice.passwordNotSet) == const OtpState(), isFalse);
      expect(const UnlockState(lockSecs: 3).locked, isTrue);
    });
  });

  group('GoogleSignInController', () {
    setUp(() => keepAlive(googleSignInControllerProvider));
    GoogleSignInController ctrl() => container.read(googleSignInControllerProvider.notifier);
    GoogleSignInState st() => container.read(googleSignInControllerProvider);

    test('backing out of the provider sheet says nothing', () async {
      when(() => social.obtain()).thenAnswer((_) async => const SocialCredentialsCancelled());
      expect(await ctrl().signIn(countryCode: 'EG'), isNull);
      expect(st(), const GoogleSignInState());
    });

    test('a missing token is "unavailable", any other failure is "failed"', () async {
      when(() => social.obtain()).thenAnswer((_) async => const SocialCredentialsFailure(missingToken: true));
      await ctrl().signIn(countryCode: 'EG');
      expect(st().error, const AuthError.socialUnavailable());

      when(() => social.obtain()).thenAnswer((_) async => const SocialCredentialsFailure());
      await ctrl().signIn(countryCode: 'EG');
      expect(st().error, const AuthError.failed());
    });

    test('a success hands back the new-account flag and the provider names', () async {
      when(() => social.obtain()).thenAnswer(
        (_) async =>
            const SocialCredentials(idToken: 'tok', email: 'x@example.test', givenName: 'Test', familyName: 'User'),
      );
      when(
        () => signIn.signInWithGoogle(idToken: 'tok', email: 'x@example.test', countryCode: 'EG'),
      ).thenAnswer((_) async => AppResult.success(const SignInSuccess(isNewUser: true)));
      final done = await ctrl().signIn(countryCode: 'EG');
      expect(done, (isNewUser: true, givenName: 'Test', familyName: 'User'));
      expect(st(), const GoogleSignInState());
    });

    test('a lockout lands in state', () async {
      when(() => social.obtain()).thenAnswer((_) async => const SocialCredentials(idToken: 'tok'));
      final until = DateTime.now().add(const Duration(minutes: 2));
      when(
        () => signIn.signInWithGoogle(
          idToken: any(named: 'idToken'),
          email: any(named: 'email'),
          countryCode: any(named: 'countryCode'),
        ),
      ).thenAnswer(
        (_) async => AppResult.success(SignInLockout(session: LockedOut(until: until, identifier: 'x'))),
      );
      expect(await ctrl().signIn(countryCode: 'EG'), isNull);
      expect(st().error?.kind, AuthErrorKind.lockout);
      expect(st().busy, isFalse);
    });
  });

  group('CredentialsController.createOnDevice', () {
    setUp(() => keepAlive(credentialsControllerProvider));

    test('creates the account and leaves no error', () async {
      when(() => offline.create(email: 'x@example.test', password: 'synthetic-pw')).thenAnswer((_) async => 'local-1');
      final ok = await container
          .read(credentialsControllerProvider.notifier)
          .createOnDevice(email: 'x@example.test', password: 'synthetic-pw');
      expect(ok, isTrue);
      expect(container.read(credentialsControllerProvider), const CredentialsState());
    });

    test('a storage error is a generic failure, never the exception', () async {
      when(() => offline.create(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(Exception('keychain'));
      final ok = await container
          .read(credentialsControllerProvider.notifier)
          .createOnDevice(email: 'x@example.test', password: 'synthetic-pw');
      expect(ok, isFalse);
      expect(container.read(credentialsControllerProvider), const CredentialsState(error: AuthError.failed()));
    });
  });

  group('OtpController.applyPassword', () {
    setUp(() => keepAlive(otpControllerProvider));

    test('a password that does not stick becomes a notice for its case', () async {
      when(() => signIn.setPassword(password: any(named: 'password')))
          .thenAnswer((_) async => AppResult.failure(const NetworkFailure()));
      final ctrl = container.read(otpControllerProvider.notifier);
      await ctrl.applyPassword('synthetic-pw', isNewUser: true);
      expect(container.read(otpControllerProvider).notice, OtpNotice.passwordNotSet);
      await ctrl.applyPassword('synthetic-pw', isNewUser: false);
      expect(container.read(otpControllerProvider).notice, OtpNotice.passwordNotAdopted);
    });

    test('a saved password leaves no notice', () async {
      when(() => signIn.setPassword(password: any(named: 'password'))).thenAnswer((_) async => AppResult.success(null));
      await container.read(otpControllerProvider.notifier).applyPassword('synthetic-pw', isNewUser: true);
      expect(container.read(otpControllerProvider).notice, isNull);
    });
  });

  group('UnlockController', () {
    setUp(() => when(() => offline.lockout()).thenAnswer((_) async => null));

    Future<UnlockController> ready() async {
      keepAlive(unlockControllerProvider);
      final ctrl = container.read(unlockControllerProvider.notifier);
      await pumpEventQueue();
      return ctrl;
    }

    test('the right password enters the app, or the merge screen when one is pending', () async {
      when(() => offline.unlock('synthetic-pw')).thenAnswer((_) async => const Unlocked());
      when(() => offline.pendingMerge()).thenAnswer((_) async => false);
      final ctrl = await ready();
      expect(await ctrl.unlock('synthetic-pw'), UnlockOutcome.app);
      when(() => offline.pendingMerge()).thenAnswer((_) async => true);
      expect(await ctrl.unlock('synthetic-pw'), UnlockOutcome.mergeOrDiscard);
      expect(container.read(unlockControllerProvider), const UnlockState());
    });

    test('a wrong password is refused with that reason; an error with a generic one', () async {
      final ctrl = await ready();
      when(() => offline.unlock(any())).thenAnswer((_) async => const WrongPassword(1));
      expect(await ctrl.unlock('nope'), UnlockOutcome.refused);
      expect(container.read(unlockControllerProvider).error, const AuthError.invalidCredentials());
      when(() => offline.unlock(any())).thenThrow(Exception('keychain'));
      expect(await ctrl.unlock('nope'), UnlockOutcome.refused);
      expect(container.read(unlockControllerProvider).error, const AuthError.failed());
    });

    test('an empty password is not tried', () async {
      final ctrl = await ready();
      expect(await ctrl.unlock(''), isNull);
      verifyNever(() => offline.unlock(any()));
    });

    test('a lockout found at start counts down, and blocks unlocking meanwhile', () async {
      when(() => offline.lockout())
          .thenAnswer((_) async => LockedUntil(DateTime.now().toUtc().add(const Duration(milliseconds: 1500))));
      final ctrl = await ready();
      expect(container.read(unlockControllerProvider).lockSecs, 2, reason: 'rounds up, never less than is left');
      expect(await ctrl.unlock('synthetic-pw'), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(container.read(unlockControllerProvider).lockSecs, 1);
    });

    test('start over: a failed removal says so and frees the screen', () async {
      final ctrl = await ready();
      expect(await ctrl.startOver(() async => false), isFalse);
      expect(container.read(unlockControllerProvider), const UnlockState(error: AuthError.removeFailed()));
    });
  });

  group('MergeOrDiscardController', () {
    test('loads the choice already started', () async {
      when(() => goOnline.pendingChoice()).thenAnswer((_) async => MergeChoice.merge);
      keepAlive(mergeOrDiscardControllerProvider);
      await pumpEventQueue();
      expect(container.read(mergeOrDiscardControllerProvider).started, MergeChoice.merge);
    });

    test('success stays busy until the caller settles; failure says so and reloads the choice', () async {
      when(() => goOnline.pendingChoice()).thenAnswer((_) async => null);
      keepAlive(mergeOrDiscardControllerProvider);
      final ctrl = container.read(mergeOrDiscardControllerProvider.notifier);
      await pumpEventQueue();

      when(() => goOnline.merge()).thenAnswer((_) async => AppResult.success(null));
      expect(await ctrl.run(MergeChoice.merge), isTrue);
      expect(container.read(mergeOrDiscardControllerProvider).busy, isTrue);
      ctrl.settle();
      expect(container.read(mergeOrDiscardControllerProvider).busy, isFalse);

      when(() => goOnline.discard()).thenAnswer((_) async => AppResult.failure(const StorageFailure()));
      when(() => goOnline.pendingChoice()).thenAnswer((_) async => MergeChoice.discard);
      expect(await ctrl.run(MergeChoice.discard), isFalse);
      expect(
        container.read(mergeOrDiscardControllerProvider),
        const MergeChoiceState(error: AuthError.failed(), started: MergeChoice.discard),
      );
    });
  });

  group('DisclosureAcceptController', () {
    setUp(() => keepAlive(disclosureAcceptControllerProvider));

    Future<AppResult<void>> Function() accept() => () => disclosure.execute(
          disclosureId: const DisclosureId.value(kDisclosureId),
          version: kDisclosureVersion,
          countryCode: 'EG',
          supervisoryAuthority: 'Authority',
          preferredLanguage: 'en',
        );

    Future<bool> run() => container
        .read(disclosureAcceptControllerProvider.notifier)
        .accept(countryCode: 'EG', supervisoryAuthority: 'Authority', preferredLanguage: 'en');

    test('a persisted acceptance stays busy while the gate closes', () async {
      when(accept()).thenAnswer((_) async => AppResult.success(null));
      expect(await run(), isTrue);
      expect(container.read(disclosureAcceptControllerProvider), const DisclosureAcceptState(submitting: true));
    });

    test('a failure shows its message and frees the button', () async {
      when(accept()).thenAnswer((_) async => AppResult.failure(const StorageFailure('disk')));
      expect(await run(), isFalse);
      expect(
        container.read(disclosureAcceptControllerProvider),
        const DisclosureAcceptState(error: AuthError.server('disk')),
      );
    });
  });

  group('GoOnlineSheetController', () {
    setUp(() {
      when(() => offline.pendingCredentials())
          .thenAnswer((_) async => (email: 'x@example.test', password: 'synthetic-pw'));
    });

    Future<GoOnlineSheetController> ready() async {
      keepAlive(goOnlineSheetControllerProvider);
      final ctrl = container.read(goOnlineSheetControllerProvider.notifier);
      await pumpEventQueue();
      return ctrl;
    }

    GoOnlineSheetState st() => container.read(goOnlineSheetControllerProvider);

    test("prefills the device-only account's email", () async {
      await ready();
      expect(st().email, 'x@example.test');
    });

    test('a sent code moves to the code step and starts the resend countdown', () async {
      when(() => goOnline.sendCode('x@example.test')).thenAnswer((_) async => AppResult.success(null));
      final ctrl = await ready();
      expect(await ctrl.sendCode('x@example.test'), isTrue);
      expect((st().step, st().secs, st().busy), (GoOnlineStep.code, kResendSecs, false));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(st().secs, kResendSecs - 1);
    });

    test('a refused send keeps the email step with the server text', () async {
      when(() => goOnline.sendCode(any())).thenAnswer((_) async => AppResult.failure(const NetworkFailure('nope')));
      final ctrl = await ready();
      expect(await ctrl.sendCode('x@example.test'), isFalse);
      expect((st().step, st().error), (GoOnlineStep.email, const AuthError.server('nope')));
    });

    test('verify: online, merge choice, lockout', () async {
      final ctrl = await ready();
      when(() => goOnline.verify(email: any(named: 'email'), code: any(named: 'code')))
          .thenAnswer((_) async => AppResult.success(GoOnlineOutcome.needsMergeChoice));
      expect(await ctrl.verify(email: 'x@example.test', code: '123456'), GoOnlineVerifyResult.needsMergeChoice);

      final until = DateTime.now().add(const Duration(minutes: 5));
      when(() => goOnline.verify(email: any(named: 'email'), code: any(named: 'code')))
          .thenAnswer((_) async => AppResult.success(GoOnlineLockedOut(until)));
      expect(await ctrl.verify(email: 'x@example.test', code: '123456'), GoOnlineVerifyResult.refused);
      expect(st().error?.kind, AuthErrorKind.lockout);

      when(() => goOnline.verify(email: any(named: 'email'), code: any(named: 'code')))
          .thenAnswer((_) async => AppResult.success(GoOnlineOutcome.online));
      expect(await ctrl.verify(email: 'x@example.test', code: '123456'), GoOnlineVerifyResult.online);
      expect((st().step, st().busy, st().error), (GoOnlineStep.done, false, null));
    });

    test('an unexpected error reports whether storage already went online', () async {
      final ctrl = await ready();
      when(() => goOnline.verify(email: any(named: 'email'), code: any(named: 'code'))).thenThrow(Exception('x'));
      when(() => offline.mode()).thenAnswer((_) async => AccountMode.online);
      expect(await ctrl.verify(email: 'x@example.test', code: '123456'), GoOnlineVerifyResult.failedButOnline);
      expect((st().busy, st().error), (false, const AuthError.failed()));
      when(() => offline.mode()).thenAnswer((_) async => AccountMode.deviceOnly);
      expect(await ctrl.verify(email: 'x@example.test', code: '123456'), GoOnlineVerifyResult.failed);
    });

    test('a verify answered after the sheet closed still returns its result', () async {
      final answer = Completer<AppResult<GoOnlineOutcome>>();
      when(() => goOnline.verify(email: any(named: 'email'), code: any(named: 'code')))
          .thenAnswer((_) => answer.future);
      final sub = container.listen(goOnlineSheetControllerProvider, (_, __) {});
      final ctrl = container.read(goOnlineSheetControllerProvider.notifier);
      await pumpEventQueue();
      final pending = ctrl.verify(email: 'x@example.test', code: '123456');
      sub.close(); // the sheet is dismissed
      await pumpEventQueue();
      answer.complete(AppResult.success(GoOnlineOutcome.online));
      expect(await pending, GoOnlineVerifyResult.online);
    });
  });
}
