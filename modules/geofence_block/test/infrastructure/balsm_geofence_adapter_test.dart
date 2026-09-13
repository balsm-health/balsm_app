import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geofence_block/geofence_block.dart';

/// What NetworkManager hands a caller when the request never left the device.
const _offline = ApiException(code: 'network_error', isOffline: true);
const _serverError = ApiException(code: 'server_error', statusCode: 500);

class _FakeGeofenceApi extends Fake implements GeofenceApi {
  _FakeGeofenceApi(this.behaviour);
  Future<DeniedCountriesResponse> Function() behaviour;

  @override
  Future<DeniedCountriesResponse> getDeniedCountries({CancelToken? cancelToken}) => behaviour();
}

class _FakeStorage extends Fake implements SecureStorageWrapper {
  final deleted = <String>[];

  @override
  Future<void> deleteToken(String key) async => deleted.add(key);
}

void main() {
  late AppDatabase db;
  late CacheStore store;
  late _FakeStorage legacy;

  BalsmGeofenceAdapter adapterWith(_FakeGeofenceApi api, {Duration ttl = const Duration(hours: 24)}) =>
      BalsmGeofenceAdapter(
        api: api,
        cache: CachedValue<List<String>>(
          store: store,
          namespace: 'geofence',
          ttl: ttl,
          decode: (j) => (j['codes'] as List).map((e) => e.toString()).toList(growable: false),
          encode: (codes) => {'codes': codes},
        ),
        legacyStorage: legacy,
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftCacheStore(db);
    legacy = _FakeStorage();
  });
  tearDown(() => db.close());

  test('normalises the queried code', () async {
    final a = adapterWith(_FakeGeofenceApi(() async => const DeniedCountriesResponse(deniedCodes: ['il'])));
    expect(await a.isDenied(' il '), isTrue);
    expect(await a.isDenied('EG'), isFalse);
  });

  test('an empty code is never denied', () async {
    final a = adapterWith(_FakeGeofenceApi(() async => const DeniedCountriesResponse(deniedCodes: ['IL'])));
    expect(await a.isDenied('   '), isFalse);
  });

  test('a fresh list is not refetched', () async {
    var calls = 0;
    final a = adapterWith(_FakeGeofenceApi(() async {
      calls++;
      return const DeniedCountriesResponse(deniedCodes: ['IL']);
    }));
    await a.isDenied('IL');
    await a.isDenied('IL');
    expect(calls, 1);
  });

  test('an offline refetch keeps enforcing the stale list', () async {
    final api = _FakeGeofenceApi(() async => const DeniedCountriesResponse(deniedCodes: ['IL']));
    final a = adapterWith(api, ttl: Duration.zero);
    expect(await a.isDenied('IL'), isTrue);

    api.behaviour = () async => throw _offline;
    expect(await a.isDenied('IL'), isTrue, reason: 'a known block must survive losing the network');
  });

  test('a server error does not silently serve stale', () async {
    final api = _FakeGeofenceApi(() async => const DeniedCountriesResponse(deniedCodes: ['IL']));
    final a = adapterWith(api, ttl: Duration.zero);
    await a.isDenied('IL');

    api.behaviour = () async => throw _serverError;
    await expectLater(() => a.isDenied('IL'), throwsA(isA<ApiException>()));
  });

  test('the pre-migration keychain entry is deleted', () async {
    final a = adapterWith(_FakeGeofenceApi(() async => const DeniedCountriesResponse(deniedCodes: [])));
    await a.isDenied('EG');
    expect(legacy.deleted, contains('balsm.denied_countries_cache'));
  });

  test('watchDeniedCountryCodes yields the list', () async {
    final a = adapterWith(_FakeGeofenceApi(() async => const DeniedCountriesResponse(deniedCodes: ['IL', 'xx'])));
    expect(await a.watchDeniedCountryCodes().first, ['IL', 'XX']);
  });
}
