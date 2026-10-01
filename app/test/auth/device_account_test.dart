import 'dart:convert';
import 'dart:typed_data';

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/auth/boot_session.dart';
import 'package:app/balsm_app/auth/device_account_remover.dart';
import 'package:app/balsm_app/prefs.dart';
import 'package:app/balsm_app/routes.dart';
import 'package:auth/auth.dart';
// The adapter is the auth module's transport seam; mocking it is the only way
// to run the real SignInUseCase here.
// ignore: implementation_imports
import 'package:auth/src/infrastructure/api/balsm_auth_adapter.dart';
import 'package:balsm_api/balsm_api.dart' show ApiRoutes;
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdapter extends Mock implements BalsmAuthAdapter {}

class _MockFiles extends Mock implements UserFileStore {}

/// Fast stand-in for Argon2id.
class _PlainHasher implements OfflinePasswordHasher {
  @override
  Future<String> hash(String pw) async => 'h:$pw';
  @override
  Future<bool> verify(String pw, String encoded) async => encoded == 'h:$pw';
}

class _MemoryKV implements GlobalKVDataSource {
  final Map<String, Object?> store = {};
  @override
  Future<T?> get<T>(String key) async => store[key] as T?;
  @override
  Future<bool> exists(String key) async => store.containsKey(key);
  @override
  Future<void> put<T>(String key, T value) async => store[key] = value;
  @override
  Future<void> delete(String key) async => store.remove(key);
  @override
  Future<void> clear() async => store.clear();
}

/// Records every request and answers 200 — so a test can tell whether the
/// interceptor let a request reach the network at all.
class _RecordingHttp implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    requests.add(o);
    return ResponseBody.fromString('{"data":{}}', 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Unsigned JWT that is not about to expire (the interceptor only reads `exp`).
String _jwt() {
  final exp = DateTime.now().toUtc().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  String seg(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg({'exp': exp})}.sig';
}

void main() {
  // Every SecureStorageWrapper and the interceptor share this one mock store,
  // as they share the platform keychain in the app.
  late Map<String, String> keychain;
  late SecureStorageWrapper storage;
  late OfflineAccountService offline;
  late _MemoryKV kv;
  late PatientAppPrefs prefs;

  setUpAll(() => FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.dev));

  setUp(() async {
    keychain = {};
    FlutterSecureStorage.setMockInitialValues(keychain);
    storage = SecureStorageWrapper();
    offline = OfflineAccountService(storage: storage, hasher: _PlainHasher(), eventBus: EventBus());
    kv = _MemoryKV();
    prefs = PatientAppPrefs(kv);
  });

  Future<Map<String, String>> readAll() => SecureStorageWrapper.storage.readAll();

  Future<PatientAppState> boot() async {
    final b = await resolveBootSession(storage: storage, prefs: prefs, offline: offline);
    return PatientAppState.load(prefs,
        hasSession: b.sessionUserId != null,
        accountMode: b.accountMode,
        pendingMerge: b.pendingMerge,
        hasOfflinePassword: b.hasOfflinePassword);
  }

  group('remove a device-only account from this phone', () {
    late AppDatabase db;
    late _MockFiles files;
    late EventBus bus;
    late DeviceAccountRemover remover;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      files = _MockFiles();
      when(() => files.deleteOwnerFiles(owner: any(named: 'owner'))).thenAnswer((_) async {});
      bus = EventBus();
      remover = DeviceAccountRemover(offline: offline, db: db, files: files, storage: storage, eventBus: bus);
    });
    tearDown(() async {
      await db.close();
      bus.dispose();
    });

    Future<void> addProfile(String owner) async {
      await db
          .customStatement("INSERT INTO health_profile (id, user_id, updated_at) VALUES ('p-$owner', '$owner', 't')");
      await db.customStatement('INSERT INTO medications (id, user_id, health_profile_id, name, schedule_type, '
          "schedule_config, start_date) VALUES ('m-$owner','$owner','p-$owner','n','daily','{}','t')");
      await db.customStatement('INSERT INTO dose_events (id, medication_id, scheduled_at, recorded_at, outcome) '
          "VALUES ('d-$owner','m-$owner','t','t','taken')");
    }

    Future<List<String>> owners() async => (await db.customSelect('SELECT user_id FROM health_profile').get())
        .map((r) => r.read<String>('user_id'))
        .toList();

    test('deletes the rows, files, file key and every offline key; announces a sign-out', () async {
      final id = await offline.create(email: 'a@b.co', password: 'correct-horse');
      await addProfile(id);
      await addProfile('someone-else');
      keychain['balsm.offline.disclosure_pending'] = 'true';
      final signedOut = <UserSignedOut>[];
      bus.on<UserSignedOut>().listen(signedOut.add);

      await remover.remove();
      await Future<void>.delayed(Duration.zero);

      expect(await owners(), ['someone-else']);
      final doses = await db.customSelect('SELECT id FROM dose_events').get();
      expect(doses.map((r) => r.read<String>('id')), ['d-someone-else']);
      verify(() => files.deleteOwnerFiles(owner: id)).called(1);
      expect(await readAll(), isEmpty);
      expect(signedOut, hasLength(1));
    });

    test('mid go-online: deletes the pinned device id, never the server account it found', () async {
      final id = await offline.create(email: 'a@b.co', password: 'correct-horse');
      await addProfile(id);
      await addProfile('srv-1');
      keychain['balsm.offline.local_id'] = id;
      keychain['balsm.user_id'] = 'srv-1';
      keychain['balsm.access_token'] = 'at';
      keychain['balsm.refresh_token'] = 'rt';
      keychain['balsm.pending_merge'] = 'true';

      await remover.remove();

      expect(await owners(), ['srv-1']);
      verify(() => files.deleteOwnerFiles(owner: id)).called(1);
      expect(await readAll(), isEmpty);
    });

    test('refuses for an online account', () async {
      keychain['balsm.account_mode'] = 'online';
      keychain['balsm.user_id'] = 'srv-1';
      await expectLater(remover.remove(), throwsStateError);
      expect(keychain['balsm.user_id'], 'srv-1');
    });

    test('then an online sign-in sends requests and the next boot reaches the app', () async {
      await prefs.setWalkthroughSeen(true);
      await offline.create(email: 'a@b.co', password: 'correct-horse');
      await remover.remove();

      // An ordinary password sign-in on the same phone.
      final adapter = _MockAdapter();
      final at = _jwt();
      when(() => adapter.passwordSignIn(any(), any(), any(), any()))
          .thenAnswer((_) async => (accessToken: at, refreshToken: 'rt', userId: 'srv-2', isNewUser: false));
      final signIn = SignInUseCase(adapter: adapter, storage: storage, eventBus: EventBus());
      final r = await signIn.passwordSignIn(email: 'c@d.co', password: 'pw-online-1');
      expect(r.isSuccess, isTrue);
      await prefs.setSignedIn(true); // what s.go(app) persists

      // An authenticated request is not refused locally.
      final api = BalsmApiController.create(storage: SecureStorageWrapper.storage, bus: EventBus());
      final http = _RecordingHttp();
      api.client.dio.httpClientAdapter = http;
      await api.client.dio.get<void>(ApiRoutes.account_self);
      expect(http.requests, hasLength(1));
      expect(http.requests.single.headers['Authorization'], 'Bearer $at');

      final s = await boot();
      expect(s.route, AppRoutes.app);
      expect(s.accountMode, AccountMode.online);
    });

    test('a sign-in over a stale device-only mode still marks the account online', () async {
      // The pre-fix state: Sign out left the device-only mode behind.
      await prefs.setWalkthroughSeen(true);
      await offline.create(email: 'a@b.co', password: 'correct-horse');
      keychain.remove('balsm.user_id');

      final adapter = _MockAdapter();
      when(() => adapter.passwordSignIn(any(), any(), any(), any()))
          .thenAnswer((_) async => (accessToken: _jwt(), refreshToken: 'rt', userId: 'srv-2', isNewUser: false));
      await SignInUseCase(adapter: adapter, storage: storage, eventBus: EventBus())
          .passwordSignIn(email: 'c@d.co', password: 'pw-online-1');
      await prefs.setSignedIn(true);

      expect(keychain['balsm.account_mode'], 'online');
      expect((await boot()).route, AppRoutes.app);
    });
  });

  group('boot', () {
    test('a device-only account left by an uninstalled copy is forgotten on a fresh install', () async {
      final id = await offline.create(email: 'a@b.co', password: 'correct-horse');
      keychain['balsm.file_key.$id'] = 'k';
      keychain['balsm.offline.local_id'] = id;
      keychain['balsm.device_id'] = 'dev-1';
      // Prefs are empty: the app was reinstalled, the keychain survived.

      final s = await boot();

      expect(s.route, AppRoutes.walkthrough);
      expect(s.accountMode, AccountMode.online);
      expect(await readAll(), {'balsm.device_id': 'dev-1'});
    });

    test('the same keychain with this install\'s prefs still boots to Unlock', () async {
      await prefs.setWalkthroughSeen(true);
      final id = await offline.create(email: 'a@b.co', password: 'correct-horse');
      keychain['balsm.file_key.$id'] = 'k';

      final s = await boot();

      expect(s.route, AppRoutes.unlock);
      expect(keychain['balsm.user_id'], id);
      expect(keychain['balsm.file_key.$id'], 'k');
    });

    test('go-online killed after storing the server id: the session keeps the device id', () async {
      await prefs.setWalkthroughSeen(true);
      final id = await offline.create(email: 'a@b.co', password: 'correct-horse');
      // What the go-online flow had written when it was killed.
      keychain['balsm.offline.local_id'] = id;
      keychain['balsm.user_id'] = 'srv-9';
      keychain['balsm.access_token'] = 'at';
      keychain['balsm.refresh_token'] = 'rt';

      final b = await resolveBootSession(storage: storage, prefs: prefs, offline: offline);
      expect(b.sessionUserId?.value, id);
      expect(b.accountMode, AccountMode.deviceOnly);
      final s = await boot();
      expect(s.route, AppRoutes.unlock);
      // Nothing is rewritten: going online again resumes from the pin.
      expect(keychain['balsm.user_id'], 'srv-9');
      expect(keychain['balsm.offline.local_id'], id);
    });

    test('a pending merge goes through Unlock while the device password exists', () async {
      await prefs.setWalkthroughSeen(true);
      final id = await offline.create(email: 'a@b.co', password: 'correct-horse');
      keychain['balsm.offline.local_id'] = id;
      keychain['balsm.user_id'] = 'srv-1';
      keychain['balsm.refresh_token'] = 'rt';
      await offline.setPendingMerge(true);

      expect((await boot()).route, AppRoutes.unlock);
    });

    test('a pending merge with no device password left resumes on the merge screen', () async {
      await prefs.setSignedIn(false);
      keychain['balsm.account_mode'] = 'deviceOnly';
      keychain['balsm.user_id'] = 'srv-1';
      keychain['balsm.refresh_token'] = 'rt';
      keychain['balsm.pending_merge'] = 'true';

      expect((await boot()).route, AppRoutes.mergeOrDiscard);
    });
  });

  group('telemetry identity', () {
    const id = UserId.value('u-1');

    test('a device-only account is never identified', () {
      expect(telemetryUserId(AccountMode.deviceOnly, id), isNull);
      expect(telemetryUserId(AccountMode.online, id), 'u-1');
      expect(telemetryUserId(AccountMode.online, null), isNull);
    });

    test('creating a device-only account is anonymous', () async {
      keychain['balsm.account_mode'] = 'deviceOnly';
      expect(await telemetryUserIdAfterSignIn(storage, const UserSignedIn(userId: id, email: '', provider: 'device')),
          isNull);
    });

    test('a sign-in while the account is still device-only is anonymous', () async {
      keychain['balsm.account_mode'] = 'deviceOnly';
      expect(await telemetryUserIdAfterSignIn(storage, const UserSignedIn(userId: id, email: '', provider: 'email')),
          isNull);
    });

    test('once online, the id is bound', () async {
      keychain['balsm.account_mode'] = 'online';
      expect(await telemetryUserIdAfterSignIn(storage, const UserSignedIn(userId: id, email: '', provider: 'email')),
          'u-1');
    });
  });
}
