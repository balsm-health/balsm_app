import 'package:account/account.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// A device-only account keeps its profile details on the device: it may not
/// call the account API, and before this its saves failed as "offline".
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

void main() {
  late _MemStorage storage;
  late _MockAccountApi api;
  late AccountProfileUseCase profile;

  setUp(() {
    storage = _MemStorage()..data[kAccountModeKey] = AccountMode.deviceOnly.wire;
    api = _MockAccountApi();
    profile = AccountProfileUseCase(api, storage);
  });

  test('a new device-only account loads an empty profile, so the screen can save', () async {
    final p = await profile.load();
    expect(p, isNotNull);
    expect(p!.firstName, isNull);
    verifyZeroInteractions(api);
  });

  test('saves and reloads on the device without calling the API', () async {
    final r = await profile.update(const UpdateProfileInput(
      firstName: 'Test',
      lastName: 'Person',
      gender: Gender.male,
      nationality: 'EG',
      dateOfBirth: '1990-01-15',
    ));
    expect(r.isSuccess, isTrue);

    final p = (await profile.load())!;
    expect(p.displayName, 'Test Person');
    expect(p.gender, Gender.male);
    expect(p.dateOfBirth, '1990-01-15');
    verifyZeroInteractions(api);
  });

  test('keeps the handle on the device, since it cannot be claimed offline', () async {
    await profile.update(const UpdateProfileInput(handle: 'test_person'));
    expect((await profile.load())!.handle, 'test_person');
    verifyZeroInteractions(api);
  });

  test('a null field stays, an empty one clears', () async {
    await profile.update(const UpdateProfileInput(firstName: 'Test', phone: '+20 100 000 0000'));
    await profile.update(const UpdateProfileInput(phone: ''));
    final p = (await profile.load())!;
    expect(p.firstName, 'Test');
    expect(p.phone, isNull);
  });

  test('an under-18 date of birth is refused, as the server does', () async {
    final now = DateTime.now();
    final r = await profile.update(UpdateProfileInput(dateOfBirth: '${now.year - 10}-01-01'.padLeft(10, '0')));
    expect(r.isFailure, isTrue);
    expect(r.error, isA<ValidationFailure>());
    expect(storage.data.containsKey(AccountProfileUseCase.kLocalProfileKey), isFalse);
  });

  test('online accounts still use the API', () async {
    storage.data[kAccountModeKey] = AccountMode.online.wire;
    registerFallbackValue(const UpdateProfileRequest());
    when(() => api.updateProfile(any())).thenAnswer((_) async {});
    await profile.update(const UpdateProfileInput(firstName: 'Test'));
    verify(() => api.updateProfile(any())).called(1);
    expect(storage.data.containsKey(AccountProfileUseCase.kLocalProfileKey), isFalse);
  });

  test('dropLocal forgets the details without sending them', () async {
    await profile.update(const UpdateProfileInput(firstName: 'Test'));
    await profile.dropLocal();
    expect((await profile.load())!.firstName, isNull);
    verifyZeroInteractions(api);
  });
}
