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
  late SignUpUseCase usecase;

  setUp(() {
    adapter = _MockAdapter();
    storage = _MockStorage();
    bus = EventBus();
    events = [];
    bus.events.listen(events.add);
    usecase = SignUpUseCase(adapter: adapter, storage: storage, eventBus: bus);

    when(() => storage.readToken(_did)).thenAnswer((_) async => 'dev-1');
    when(() => storage.writeToken(any(), any())).thenAnswer((_) async {});
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('verifyEmailOtp', () {
    test('success persists tokens and publishes UserSignedUp(email, country)',
        () async {
      when(() => adapter.verifyOtp('a@b.com', '123456', 'dev-1', _label))
          .thenAnswer((_) async =>
              (accessToken: 'AT', refreshToken: 'RT', userId: 'U1', isNewUser: true));

      final r = await usecase.verifyEmailOtp(
          email: 'a@b.com', code: '123456', countryCode: 'EG');
      await flush();

      expect(r.isSuccess, isTrue);
      verify(() => storage.writeToken(_at, 'AT')).called(1);
      verify(() => storage.writeToken(_rt, 'RT')).called(1);
      verify(() => storage.writeToken(_uid, 'U1')).called(1);
      final signedUp = events.whereType<UserSignedUp>().single;
      expect(signedUp.provider, 'email');
      expect(signedUp.countryCode, 'EG');
    });

    test('AuthException maps to NetworkFailure', () async {
      when(() => adapter.verifyOtp(any(), any(), any(), any())).thenThrow(
        const AuthException(code: 'otp_expired', message: 'Expired.'),
      );

      final r = await usecase.verifyEmailOtp(
          email: 'a@b.com', code: 'xxxxxx', countryCode: 'EG');

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
  });

  group('signUpWithGoogle', () {
    test('success persists tokens and publishes UserSignedUp(google)', () async {
      when(() => adapter.signInWithGoogle('idtok', 'dev-1', _label)).thenAnswer(
          (_) async =>
              (accessToken: 'AT', refreshToken: 'RT', userId: 'U9', isNewUser: true));

      final r = await usecase.signUpWithGoogle(
          idToken: 'idtok', countryCode: 'SA', email: 'g@b.com');
      await flush();

      expect(r.isSuccess, isTrue);
      final signedUp = events.whereType<UserSignedUp>().single;
      expect(signedUp.provider, 'google');
      expect(signedUp.countryCode, 'SA');
    });
  });
}
