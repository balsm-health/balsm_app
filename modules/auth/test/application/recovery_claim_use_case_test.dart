import 'dart:convert';

import 'package:auth/auth.dart';
import 'package:auth/src/infrastructure/api/auth_exception.dart';
import 'package:auth/src/infrastructure/api/balsm_auth_adapter.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements BalsmAuthAdapter {}

class _MockStorage extends Mock implements SecureStorageWrapper {}

const _uid = 'balsm.user_id';

/// Build a fake (unsigned) JWT — only the payload segment is read by the
/// use-case (it extracts `sub`), so header/signature are throwaway.
String _jwt(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) => base64Url.encode(utf8.encode(json.encode(m))).replaceAll('=', '');
  return '${seg({'alg': 'none'})}.${seg(claims)}.sig';
}

void main() {
  late _MockAdapter adapter;
  late _MockStorage storage;
  late EventBus bus;
  late List<AppEvent> events;
  late RecoveryClaimUseCase usecase;

  setUp(() {
    adapter = _MockAdapter();
    storage = _MockStorage();
    bus = EventBus();
    events = [];
    bus.events.listen(events.add);
    usecase = RecoveryClaimUseCase(adapter: adapter, storage: storage, eventBus: bus);

    when(() => storage.writeToken(any(), any())).thenAnswer((_) async {});
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('success: derives userId from JWT sub, persists, publishes recovery', () async {
    when(() => adapter.recoveryClaim('rtok', 'n@b.com', 'dev-1', 'Label'))
        .thenAnswer((_) async => (accessToken: _jwt({'sub': 'user-xyz'}), refreshToken: 'RT'));

    final r = await usecase.call(
      recoveryToken: 'rtok',
      newEmail: 'n@b.com',
      deviceId: 'dev-1',
      deviceLabel: 'Label',
    );
    await flush();

    expect(r.isSuccess, isTrue);
    verify(() => storage.writeToken(_uid, 'user-xyz')).called(1);
    final signedIn = events.whereType<UserSignedIn>().single;
    expect(signedIn.provider, 'recovery');
  });

  test('fails closed when access token has no usable user id (no persist)', () async {
    when(() => adapter.recoveryClaim(any(), any(), any(), any()))
        .thenAnswer((_) async => (accessToken: 'not-a-jwt', refreshToken: 'RT'));

    final r = await usecase.call(
      recoveryToken: 'rtok',
      newEmail: 'n@b.com',
      deviceId: 'dev-1',
      deviceLabel: 'Label',
    );

    expect(r.isFailure, isTrue);
    expect(r.error, isA<NetworkFailure>());
    verifyNever(() => storage.writeToken(any(), any()));
  });

  test('AuthException maps to NetworkFailure', () async {
    when(() => adapter.recoveryClaim(any(), any(), any(), any())).thenThrow(
      const AuthException(code: 'unauthorized', message: 'bad token'),
    );

    final r = await usecase.call(
      recoveryToken: 'rtok',
      newEmail: 'n@b.com',
      deviceId: 'dev-1',
      deviceLabel: 'Label',
    );

    expect(r.isFailure, isTrue);
    expect(r.error, isA<NetworkFailure>());
  });
}
