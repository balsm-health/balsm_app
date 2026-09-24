import 'package:auth/auth.dart';
import 'package:balsm_api/balsm_api.dart' show OtpPurpose;
import 'package:auth/src/infrastructure/api/auth_exception.dart';
import 'package:auth/src/infrastructure/api/balsm_auth_adapter.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements BalsmAuthAdapter {}

class _MockStorage extends Mock implements SecureStorageWrapper {}

const _label = 'Balsm Flutter App';
const _at = 'balsm.access_token';
const _rt = 'balsm.refresh_token';
const _uid = 'balsm.user_id';
const _did = 'balsm.device_id';

void main() {
  // mocktail needs a concrete value before `any(named: 'purpose')` can stand
  // in for an enum argument.
  setUpAll(() => registerFallbackValue(OtpPurpose.reset));

  late _MockAdapter adapter;
  late _MockStorage storage;
  late EventBus bus;
  late List<AppEvent> events;
  late SignInUseCase usecase;

  setUp(() {
    adapter = _MockAdapter();
    storage = _MockStorage();
    bus = EventBus();
    events = [];
    bus.events.listen(events.add);
    usecase = SignInUseCase(adapter: adapter, storage: storage, eventBus: bus);

    // Device id already provisioned — avoids the UuidV7 write path.
    when(() => storage.readToken(_did)).thenAnswer((_) async => 'dev-1');
    when(() => storage.writeToken(any(), any())).thenAnswer((_) async {});
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('requestContinueOtp', () {
    test('asks for the merged-entry purpose, not reset', () async {
      // The code that follows a failed email+password attempt. The address may
      // or may not have an account; the server sends either way and says
      // nothing about which, which is the only reason the merged screen is
      // safe. Reset is a different purpose with a different rule.
      when(() => adapter.requestOtp('a@b.com', 'EG', purpose: OtpPurpose.continueFlow)).thenAnswer((_) async {});

      final r = await usecase.requestContinueOtp('a@b.com', 'EG');

      expect(r.isSuccess, isTrue);
      verify(() => adapter.requestOtp('a@b.com', 'EG', purpose: OtpPurpose.continueFlow)).called(1);
    });

    test('a transport failure is reported, not swallowed', () async {
      when(() => adapter.requestOtp('a@b.com', 'EG', purpose: OtpPurpose.continueFlow))
          .thenThrow(const AuthException(code: 'network', message: 'no route'));

      final r = await usecase.requestContinueOtp('a@b.com', 'EG');

      expect(r.isFailure, isTrue);
    });
  });

  group('verifyEmailOtp', () {
    test('success persists tokens and publishes UserSignedIn(email)', () async {
      when(() => adapter.verifyOtp('a@b.com', '123456', 'dev-1', _label))
          .thenAnswer((_) async => (accessToken: 'AT', refreshToken: 'RT', userId: 'U1', isNewUser: false));

      final r = await usecase.verifyEmailOtp(email: 'a@b.com', code: '123456');
      await flush();

      expect(r.isSuccess, isTrue);
      expect(r.value, isA<SignInSuccess>());
      verify(() => storage.writeToken(_at, 'AT')).called(1);
      verify(() => storage.writeToken(_rt, 'RT')).called(1);
      verify(() => storage.writeToken(_uid, 'U1')).called(1);
      final signedIn = events.whereType<UserSignedIn>().single;
      expect(signedIn.provider, 'email');
    });

    test('423 account_locked returns SignInLockout + fires LockoutTriggered', () async {
      when(() => adapter.verifyOtp(any(), any(), any(), any())).thenThrow(
        const AuthException(
          code: 'account_locked',
          message: 'Account temporarily locked. Try again in 90 seconds.',
        ),
      );

      final r = await usecase.verifyEmailOtp(email: 'a@b.com', code: '000000');
      await flush();

      expect(r.isSuccess, isTrue);
      final res = r.value;
      expect(res, isA<SignInLockout>());
      final until = (res as SignInLockout).session.until;
      final now = DateTime.now().toUtc();
      expect(until.isAfter(now.add(const Duration(seconds: 80))), isTrue);
      expect(until.isBefore(now.add(const Duration(seconds: 100))), isTrue);
      expect(events.whereType<LockoutTriggered>().length, 1);
      // No session persisted on lockout.
      verifyNever(() => storage.writeToken(_at, any()));
    });

    test('other AuthException maps to NetworkFailure', () async {
      when(() => adapter.verifyOtp(any(), any(), any(), any())).thenThrow(
        const AuthException(code: 'otp_invalid', message: 'Incorrect code.'),
      );

      final r = await usecase.verifyEmailOtp(email: 'a@b.com', code: 'xxxxxx');

      expect(r.isFailure, isTrue);
      expect(r.error, isA<NetworkFailure>());
    });

    test('unexpected error maps to NetworkFailure', () async {
      when(() => adapter.verifyOtp(any(), any(), any(), any())).thenThrow(Exception('boom'));

      final r = await usecase.verifyEmailOtp(email: 'a@b.com', code: 'xxxxxx');

      expect(r.isFailure, isTrue);
      expect(r.error, isA<NetworkFailure>());
    });
  });

  group('requestEmailOtp', () {
    test('success forwards email + country with reset purpose', () async {
      when(() => adapter.requestOtp('a@b.com', 'EG', purpose: OtpPurpose.reset)).thenAnswer((_) async {});

      final r = await usecase.requestEmailOtp('a@b.com', 'EG');

      expect(r.isSuccess, isTrue);
      verify(() => adapter.requestOtp('a@b.com', 'EG', purpose: OtpPurpose.reset)).called(1);
    });

    test('AuthException maps to NetworkFailure', () async {
      when(() => adapter.requestOtp('a@b.com', 'EG', purpose: OtpPurpose.reset)).thenThrow(
        const AuthException(code: 'rate_limited', message: 'Too many.'),
      );

      final r = await usecase.requestEmailOtp('a@b.com', 'EG');

      expect(r.isFailure, isTrue);
      expect(r.error, isA<NetworkFailure>());
    });
  });

  group('signInWithGoogle', () {
    test('success persists tokens and publishes UserSignedIn(google)', () async {
      when(() => adapter.signInWithGoogle('idtok', 'dev-1', _label, 'EG'))
          .thenAnswer((_) async => (accessToken: 'AT', refreshToken: 'RT', userId: 'U9', isNewUser: false));

      final r = await usecase.signInWithGoogle(idToken: 'idtok', email: 'g@b.com', countryCode: 'EG');
      await flush();

      expect(r.value, isA<SignInSuccess>());
      verify(() => storage.writeToken(_uid, 'U9')).called(1);
      expect(events.whereType<UserSignedIn>().single.provider, 'google');
    });

    test('forwards the account country to the adapter', () async {
      when(() => adapter.signInWithGoogle(any(), any(), any(), any()))
          .thenAnswer((_) async => (accessToken: 'AT', refreshToken: 'RT', userId: 'U9', isNewUser: true));

      await usecase.signInWithGoogle(idToken: 'idtok', email: 'g@b.com', countryCode: 'SA');
      await flush();

      verify(() => adapter.signInWithGoogle('idtok', 'dev-1', _label, 'SA')).called(1);
    });
  });

  group('signInWithApple', () {
    test('success persists tokens and publishes UserSignedIn(apple)', () async {
      when(() => adapter.signInWithApple('idtok', 'authcode', 'dev-1', _label, 'EG'))
          .thenAnswer((_) async => (accessToken: 'AT', refreshToken: 'RT', userId: 'U7', isNewUser: true));

      final r = await usecase.signInWithApple(
        idToken: 'idtok',
        authCode: 'authcode',
        email: 'a@privaterelay.appleid.com',
        countryCode: 'EG',
      );
      await flush();

      expect(r.value, isA<SignInSuccess>());
      expect((r.value as SignInSuccess).isNewUser, isTrue);
      verify(() => storage.writeToken(_uid, 'U7')).called(1);
      expect(events.whereType<UserSignedIn>().single.provider, 'apple');
    });

    test('forwards the account country to the adapter', () async {
      when(() => adapter.signInWithApple(any(), any(), any(), any(), any()))
          .thenAnswer((_) async => (accessToken: 'AT', refreshToken: 'RT', userId: 'U7', isNewUser: false));

      await usecase.signInWithApple(idToken: 'idtok', authCode: 'authcode', email: '', countryCode: 'SA');
      await flush();

      verify(() => adapter.signInWithApple('idtok', 'authcode', 'dev-1', _label, 'SA')).called(1);
    });
  });

  group('setPassword', () {
    test('success forwards the password', () async {
      when(() => adapter.setPassword('secret123')).thenAnswer((_) async {});

      final r = await usecase.setPassword(password: 'secret123');

      expect(r.isSuccess, isTrue);
      verify(() => adapter.setPassword('secret123')).called(1);
    });

    test('AuthException maps to NetworkFailure', () async {
      when(() => adapter.setPassword(any())).thenThrow(
        const AuthException(code: 'unauthorized', message: 'x'),
      );

      final r = await usecase.setPassword(password: 'secret123');

      expect(r.isFailure, isTrue);
      expect(r.error, isA<NetworkFailure>());
    });
  });
}
