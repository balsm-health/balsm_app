import 'dart:typed_data';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Canned-response adapter: routes by path + Authorization header, records
/// every request for assertion. Mirrors balsm_api's test helper.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    requests.add(o);
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, {int status = 200}) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  setUpAll(() => FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.dev));

  /// A [FlutterSecureStorage] mock backed by [seed] so writes/deletes during
  /// refresh are visible to the replayed request's `onRequest`.
  _MockStorage storageWith(Map<String, String> seed) {
    final store = Map<String, String>.of(seed);
    final s = _MockStorage();
    when(() => s.read(key: any(named: 'key')))
        .thenAnswer((i) async => store[i.namedArguments[#key] as String]);
    when(() => s.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((i) async {
      final k = i.namedArguments[#key] as String;
      final v = i.namedArguments[#value] as String?;
      if (v == null) {
        store.remove(k);
      } else {
        store[k] = v;
      }
    });
    when(() => s.delete(key: any(named: 'key')))
        .thenAnswer((i) async => store.remove(i.namedArguments[#key] as String));
    return s;
  }

  ({BalsmApiController controller, EventBus bus, _FakeAdapter adapter}) harness(
    FlutterSecureStorage storage,
    ResponseBody Function(RequestOptions o) handler,
  ) {
    final bus = EventBus();
    final controller = BalsmApiController.create(storage: storage, bus: bus);
    final adapter = _FakeAdapter(handler);
    controller.client.dio.httpClientAdapter = adapter;
    return (controller: controller, bus: bus, adapter: adapter);
  }

  test('attaches the stored bearer token to an authenticated request', () async {
    final h = harness(
      storageWith({'balsm.access_token': 'AT1'}),
      (o) => _json('{"data":{}}'),
    );

    await h.controller.client.dio.get<Map<String, dynamic>>(ApiRoutes.account_self);

    expect(h.adapter.requests.single.headers['Authorization'], 'Bearer AT1');
  });

  test('401 → refreshes, persists the rotated pair, and replays with the new token',
      () async {
    final storage = storageWith({
      'balsm.access_token': 'ATold',
      'balsm.refresh_token': 'RT1',
      'balsm.device_id': 'DEV1',
    });
    final h = harness(storage, (o) {
      if (o.path == ApiRoutes.auth_refresh) {
        return _json('{"data":{"access_token":"ATnew","refresh_token":"RT2"}}');
      }
      // Protected endpoint: 401 for the stale token, 200 once refreshed.
      return o.headers['Authorization'] == 'Bearer ATnew'
          ? _json('{"data":{"ok":true}}')
          : _json('{"error":"unauthorized"}', status: 401);
    });

    final res =
        await h.controller.client.dio.get<Map<String, dynamic>>(ApiRoutes.account_self);

    expect(res.statusCode, 200);
    // Rotated pair persisted.
    verify(() => storage.write(key: 'balsm.access_token', value: 'ATnew')).called(1);
    verify(() => storage.write(key: 'balsm.refresh_token', value: 'RT2')).called(1);
    // Refresh was actually hit, and the replay carried the new token.
    expect(h.adapter.requests.any((r) => r.path == ApiRoutes.auth_refresh), isTrue);
    expect(h.adapter.requests.last.headers['Authorization'], 'Bearer ATnew');
  });

  test('refresh failure clears tokens and publishes SessionExpired', () async {
    final storage = storageWith({
      'balsm.access_token': 'ATold',
      'balsm.refresh_token': 'RTbad',
      'balsm.device_id': 'DEV1',
    });
    final h = harness(storage, (o) {
      if (o.path == ApiRoutes.auth_refresh) {
        return _json('{"error":"invalid_grant"}', status: 401);
      }
      return _json('{"error":"unauthorized"}', status: 401);
    });

    final expired = expectLater(h.bus.on<SessionExpired>(), emits(isA<SessionExpired>()));

    await expectLater(
      h.controller.client.dio.get<Map<String, dynamic>>(ApiRoutes.account_self),
      throwsA(isA<DioException>()),
    );
    await expired;
    verify(() => storage.delete(key: 'balsm.access_token')).called(1);
    verify(() => storage.delete(key: 'balsm.refresh_token')).called(1);
  });

  test('bootstrap endpoints carry no token and are not refresh-retried', () async {
    final storage = storageWith({
      'balsm.access_token': 'AT1',
      'balsm.refresh_token': 'RT1',
      'balsm.device_id': 'DEV1',
    });
    final h = harness(
      storage,
      (o) => _json('{"error":"bad_code"}', status: 401),
    );

    await expectLater(
      h.controller.client.dio.post<Map<String, dynamic>>(ApiRoutes.auth_otp_verify),
      throwsA(isA<DioException>()),
    );

    // No Authorization header on the bootstrap request, and no refresh attempt.
    expect(h.adapter.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(h.adapter.requests.any((r) => r.path == ApiRoutes.auth_refresh), isFalse);
  });
}
