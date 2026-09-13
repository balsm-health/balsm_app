import 'dart:io';

import 'package:account/account.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Synthetic identifiers only — never real account data.
AccountSelfResponse _response({String handle = 'sara'}) => AccountSelfResponse(
      id: '00000000-0000-0000-0000-0000000000a1',
      handle: handle,
      displayName: 'Test Person',
      countryCode: 'EG',
      preferredLanguage: 'ar',
    );

/// What NetworkManager hands a caller when the request never left the device.
/// That the dio error maps to this is covered in balsm_api's offline_test.
const _offline = ApiException(code: 'network_error', isOffline: true);

class _FakeAccountApi extends Fake implements AccountApi {
  _FakeAccountApi(this.behaviour);
  Future<AccountSelfResponse?> Function() behaviour;
  int calls = 0;

  @override
  Future<AccountSelfResponse?> getSelf({CancelToken? cancelToken}) {
    calls++;
    return behaviour();
  }
}

void main() {
  late AppDatabase db;
  late CacheStore store;

  CachedValue<AccountSummary> cacheFor(Duration ttl) => CachedValue<AccountSummary>(
        store: store,
        namespace: 'account',
        ttl: ttl,
        decode: AccountSummary.fromJson,
        encode: (s) => s.toJson(),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftCacheStore(db);
  });
  tearDown(() => db.close());

  test('serves the retained summary when offline', () async {
    final api = _FakeAccountApi(() async => _response());
    final adapter = BalsmAccountAdapter(api, cacheFor(Duration.zero));
    addTearDown(adapter.dispose);

    expect((await adapter.getAccount('self'))!.handle, 'sara');

    api.behaviour = () async => throw _offline;
    final second = await adapter.getAccount('self');

    expect(second!.handle, 'sara', reason: 'the offline verdict must survive the ApiException wrapper');
  });

  test('a raw SocketException also falls back', () async {
    final api = _FakeAccountApi(() async => _response());
    final adapter = BalsmAccountAdapter(api, cacheFor(Duration.zero));
    addTearDown(adapter.dispose);
    await adapter.getAccount('self');

    api.behaviour = () async => throw const SocketException('offline');
    expect((await adapter.getAccount('self'))!.handle, 'sara');
  });

  test('a 401 clears the retained row and rethrows', () async {
    final api = _FakeAccountApi(() async => _response());
    final adapter = BalsmAccountAdapter(api, cacheFor(Duration.zero));
    addTearDown(adapter.dispose);
    await adapter.getAccount('self');

    api.behaviour = () async => throw const ApiException(code: 'unauthorized', statusCode: 401);

    await expectLater(() => adapter.getAccount('self'), throwsA(isA<ApiException>()));
    expect(await store.read('account', 'self'), isNull,
        reason: 'a rejected session must not keep serving a cached identity');
  });

  test('a 500 rethrows and does not serve the retained row', () async {
    final api = _FakeAccountApi(() async => _response());
    final adapter = BalsmAccountAdapter(api, cacheFor(Duration.zero));
    addTearDown(adapter.dispose);
    await adapter.getAccount('self');

    api.behaviour = () async => throw const ApiException(code: 'server_error', statusCode: 500);

    await expectLater(() => adapter.getAccount('self'), throwsA(isA<ApiException>()));
    expect(await store.read('account', 'self'), isNotNull,
        reason: 'a server error leaves the row alone — it just does not serve it');
  });

  test('a fresh retained summary does not call the API', () async {
    final api = _FakeAccountApi(() async => _response());
    final adapter = BalsmAccountAdapter(api, cacheFor(const Duration(hours: 1)));
    addTearDown(adapter.dispose);

    await adapter.getAccount('self');
    await adapter.getAccount('self');

    expect(api.calls, 1);
  });

  test('refresh forces the next read to hit the API', () async {
    final api = _FakeAccountApi(() async => _response(handle: 'first'));
    final adapter = BalsmAccountAdapter(api, cacheFor(const Duration(hours: 1)));
    addTearDown(adapter.dispose);

    await adapter.getAccount('self');
    await adapter.refresh('self');
    api.behaviour = () async => _response(handle: 'second');

    expect((await adapter.getAccount('self'))!.handle, 'second');
    expect(api.calls, 2);
  });
}
