import 'package:auth/auth.dart';
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

  group('verifyEmailOtp', () {
    test('success persists tokens and publishes UserSignedIn(email)', () async {
      when(() => adapter.verifyOtp('a@b.com', '123456', 'dev-1', _label))
          .thenAnswer((_) async =>
              (accessToken: 'AT', refreshToken: 'RT', userId: 'U1', isNewUser: false));

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

    test('423 account_locked returns SignInLockout + fires LockoutTriggered',
        () async {
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
      when(() => adapter.verifyOtp(any(), any(), any(), any()))
          .thenThrow(Exception('boom'));

      final r = await usecase.verifyEmailOtp(email: 'a@b.com', code: 'xxxxxx');

      expect(r.isFailure, isTrue);
      expect(r.error, isA<NetworkFailure>());
    });
  });

  group('requestEmailOtp', () {
    test('success forwards email + country', () async {
      when(() => adapter.requestOtp('a@b.com', 'EG')).thenAnswer((_) async {});

      final r = await usecase.requestEmailOtp('a@b.com', 'EG');

      expect(r.isSuccess, isTrue);
      verify(() => adapter.requestOtp('a@b.com', 'EG')).called(1);
    });

    test('AuthException maps to NetworkFailure', () async {
      when(() => adapter.requestOtp(any(), any())).thenThrow(
        const AuthException(code: 'rate_limited', message: 'Too many.'),
      );

      final r = await usecase.requestEmailOtp('a@b.com', 'EG');

      expect(r.isFailure, isTrue);
      expect(r.error, isA<NetworkFailure>());
    });
  });

  group('signInWithGoogle', () {
    test('success persists tokens and publishes UserSignedIn(google)', () async {
      when(() => adapter.signInWithGoogle('idtok', 'dev-1', _label)).thenAnswer(
          (_) async =>
              (accessToken: 'AT', refreshToken: 'RT', userId: 'U9', isNewUser: false));

      final r = await usecase.signInWithGoogle(idToken: 'idtok', email: 'g@b.com');
      await flush();

      expect(r.value, isA<SignInSuccess>());
      verify(() => storage.writeToken(_uid, 'U9')).called(1);
      expect(events.whereType<UserSignedIn>().single.provider, 'google');
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
