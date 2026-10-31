import 'package:account/account.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// A device-only account's summary (the Profile header) comes from the
/// device: asking the server could only fail and leave the screen on Retry.
///
/// The details are invented by the test; nothing here is real patient data.
class _MemStorage extends SecureStorageWrapper {
  final Map<String, String> data = {};
  @override
  Future<String?> readToken(String key) async => data[key];
  @override
  Future<void> writeToken(String key, String value) async => data[key] = value;
  @override
  Future<void> deleteToken(String key) async => data.remove(key);
}

class _MockAccountApi extends Mock implements AccountApi {}

class _MockCache extends Mock implements CachedValue<AccountSummary> {}

void main() {
  late _MemStorage storage;
  late _MockAccountApi api;
  late _MockCache cache;
  const local = AccountSummary(
    id: UserId.value('usr-local'),
    displayName: 'Test Person',
    countryCode: 'EG',
    preferredLanguage: 'ar',
    deletionState: 'ACTIVE',
  );

  setUp(() {
    storage = _MemStorage();
    api = _MockAccountApi();
    cache = _MockCache();
  });

  BalsmAccountAdapter adapter() =>
      BalsmAccountAdapter(api, cache, storage: storage, deviceOnlySummary: () async => local);

  test('device-only: built on the device, no request and no cache', () async {
    storage.data[kAccountModeKey] = AccountMode.deviceOnly.wire;
    final s = await adapter().getAccount('self');
    expect(s?.displayName, 'Test Person');
    expect(s?.preferredLanguage, 'ar');
    verifyZeroInteractions(api);
    verifyZeroInteractions(cache);
  });

  test('online: still served through the cache and the API', () async {
    storage.data[kAccountModeKey] = AccountMode.online.wire;
    when(() => cache.read(any(), fetch: any(named: 'fetch'))).thenAnswer((_) async => local);
    await adapter().getAccount('self');
    verify(() => cache.read('self', fetch: any(named: 'fetch'))).called(1);
  });
}
