import 'package:auth/auth.dart';
import 'package:auth/src/infrastructure/api/auth_exception.dart';
import 'package:auth/src/infrastructure/api/balsm_auth_adapter.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements BalsmAuthAdapter {}

class _MockStorage extends Mock implements SecureStorageWrapper {}

const _at = 'balsm.access_token';
const _rt = 'balsm.refresh_token';
const _uid = 'balsm.user_id';

void main() {
  late _MockAdapter adapter;
  late _MockStorage storage;
  late EventBus bus;
  late List<AppEvent> events;
  late SignOutUseCase usecase;

  setUp(() {
    adapter = _MockAdapter();
    storage = _MockStorage();
    bus = EventBus();
    events = [];
    bus.events.listen(events.add);
    usecase = SignOutUseCase(adapter: adapter, storage: storage, eventBus: bus);

    when(() => storage.readToken(_uid)).thenAnswer((_) async => 'U1');
    when(() => storage.deleteToken(any())).thenAnswer((_) async {});
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('success: calls server, clears tokens, publishes UserSignedOut', () async {
    when(() => adapter.signOut()).thenAnswer((_) async {});

    final r = await usecase.call();
    await flush();

    expect(r.isSuccess, isTrue);
    verify(() => adapter.signOut()).called(1);
    verify(() => storage.deleteToken(_at)).called(1);
    verify(() => storage.deleteToken(_rt)).called(1);
    verify(() => storage.deleteToken(_uid)).called(1);
    expect(events.whereType<UserSignedOut>().length, 1);
  });

  test('server sign-out failure is swallowed; tokens still cleared', () async {
    when(() => adapter.signOut()).thenThrow(
      const AuthException(code: 'unauthorized', message: 'stale token'),
    );

    final r = await usecase.call();
    await flush();

    expect(r.isSuccess, isTrue);
    verify(() => storage.deleteToken(_at)).called(1);
    verify(() => storage.deleteToken(_rt)).called(1);
    verify(() => storage.deleteToken(_uid)).called(1);
    expect(events.whereType<UserSignedOut>().length, 1);
  });

  test('local token clear failure maps to StorageFailure', () async {
    when(() => adapter.signOut()).thenAnswer((_) async {});
    when(() => storage.deleteToken(any())).thenThrow(Exception('disk'));

    final r = await usecase.call();

    expect(r.isFailure, isTrue);
    expect(r.error, isA<StorageFailure>());
  });
}
