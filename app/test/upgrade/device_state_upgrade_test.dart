import 'dart:convert';
import 'dart:io';

import 'package:app/balsm_app/auth/boot_session.dart';
import 'package:app/balsm_app/prefs.dart';
import 'package:app/balsm_app/storage_target.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
// Not exported: only the database opener needs it, and this test.
// ignore: implementation_imports
import 'package:core/src/db/db_key.dart' show kDbKeyStorageKey;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-update tests for what a phone keeps outside the database: settings
/// (SharedPreferences) and the session (keychain).
///
/// `fixtures/device_<version>.json` is what a shipped version left behind.
/// Each test puts that state on a simulated phone, starts today's code on it
/// the way the first launch after a store update does, and checks that
/// nothing reset to its default, nobody was signed out, and no key the old
/// version wrote is left unread.
///
/// The database itself is covered by packages/core/test/upgrade/.
void main() {
  setUpAll(() => FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.dev));

  final fixtures = Directory('test/upgrade/fixtures')
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'device_[\d.]+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('at least one shipped device state is frozen', () => expect(fixtures, isNotEmpty));

  for (final fixture in fixtures) {
    final version = RegExp(r'device_([\d.]+)\.json$').firstMatch(fixture.path)!.group(1)!;
    final json = jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
    final prefs = (json['prefs'] as Map<String, dynamic>).cast<String, Object>();
    final keychains = (json['keychain'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as Map<String, dynamic>).cast<String, String>()));

    group('updating from $version', () {
      late _RecordingKV kv;

      setUp(() async {
        SharedPreferences.setMockInitialValues(prefs);
        kv = _RecordingKV(SharedPrefsKVDataSource(await SharedPreferences.getInstance()));
      });

      test('preference migrations run without throwing', () async {
        await PatientAppPrefs(kv).migrate();
        await TelemetryPrefs(kv).migrate();
        await AppUpdatePrefs(kv).migrate();
      });

      test('every setting keeps its value', () async {
        final pa = PatientAppPrefs(kv);
        await pa.migrate();
        final telemetry = TelemetryPrefs(kv);
        await telemetry.migrate();
        final update = AppUpdatePrefs(kv);
        await update.migrate();

        // Read through the same accessors the app uses. A default here means
        // the update dropped the patient's choice.
        expect(await pa.lang(), prefs['pa.lang']);
        expect(await pa.accent(), prefs['pa.accent']);
        expect(await pa.country(), prefs['pa.country']);
        expect((await pa.storage()).id, prefs['pa.storage']);
        expect(await pa.storage(), isNot(StorageTarget.local));
        expect(await pa.signedIn(), prefs['pa.signedIn']);
        expect(await pa.walkthroughSeen(), prefs['pa.walkthroughSeen']);
        expect(await pa.isFreshInstall(), isFalse, reason: 'an updated phone must not look freshly installed');
        expect(await pa.feedbackRating(), prefs['pa.fbRating']);
        expect(await pa.feedbackSentAt(), DateTime.parse(prefs['pa.fbSentAt']! as String));
        expect(await pa.careCloudSync(), prefs['pa.careCloudSync']);
        expect(await pa.lastTimezone(), prefs['pa.lastTz']);
        expect(await telemetry.analyticsEnabled(), prefs['telemetry.analyticsEnabled'],
            reason: 'an analytics opt-out must survive an update');
        expect(await telemetry.campaign(), jsonDecode(prefs['telemetry.campaign']! as String));
        expect(await update.manifest(), prefs['update.manifest']);
        expect(await update.skipped(), prefs['update.skipped']);

        // Every key the old version wrote was read by today's code. One that
        // was not is a setting the update orphaned (a renamed key with no
        // migration step).
        final unread = prefs.keys.where((k) => !k.endsWith('._v') && !kv.touched.contains(k));
        expect(unread, isEmpty, reason: 'settings from $version nothing reads any more');
      });

      for (final MapEntry(key: account, value: keychain) in keychains.entries) {
        test('a $account account stays signed in', () async {
          FlutterSecureStorage.setMockInitialValues(Map.of(keychain));
          final storage = SecureStorageWrapper();
          final offline = OfflineAccountService(storage: storage, hasher: _NoHasher(), eventBus: EventBus());

          final boot = await resolveBootSession(storage: storage, prefs: PatientAppPrefs(kv), offline: offline);

          expect(boot.sessionUserId?.value, keychain['balsm.user_id'], reason: 'the update signed the patient out');
          expect(boot.accountMode, AccountMode.fromWire(keychain['balsm.account_mode']));
          expect(boot.hasOfflinePassword, keychain.containsKey('balsm.offline.pw_hash'));
          // Boot clean-up must not have deleted anything the old version wrote.
          for (final k in keychain.keys) {
            expect(await storage.readToken(k), keychain[k], reason: '$k was removed or changed at first launch');
          }
          // The database key is read under the same name, or the encrypted
          // database can no longer be opened: every record would be lost.
          expect(keychain, contains(kDbKeyStorageKey));
        });
      }
    });
  }

  group('persisted key names', () {
    /// Keys a shipped version kept data under that today's code no longer
    /// mentions on purpose, each with where its data went. Adding one here
    /// is a decision: the data under the old name is abandoned unless a
    /// migration moves it.
    const retired = <String, String>{};

    final repo = Directory('..').absolute;
    final sources = [
      for (final dir in ['app/lib', 'packages', 'modules'])
        ...Directory('${repo.path}/$dir')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart') && f.path.contains('/lib/')),
    ].map((f) => f.readAsStringSync()).join('\n');

    final manifests = Directory('test/upgrade/fixtures')
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'persisted_keys_[\d.]+\.txt$').hasMatch(f.path));

    for (final manifest in manifests) {
      test('every key ${manifest.uri.pathSegments.last} lists is still used, or retired on purpose', () {
        final keys = manifest.readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('#'));
        final gone = keys.where((k) => !retired.containsKey(k) && !sources.contains("'$k"));
        expect(gone, isEmpty,
            reason: 'renaming or removing a stored key loses what patients have under it; '
                'migrate the value and add the old key to `retired`');
      });
    }
  });
}

class _NoHasher implements OfflinePasswordHasher {
  @override
  Future<String> hash(String pw) async => throw UnimplementedError();
  @override
  Future<bool> verify(String pw, String encoded) async => false;
}

/// Delegates to the real store and records every key read.
class _RecordingKV implements GlobalKVDataSource {
  _RecordingKV(this._inner);
  final GlobalKVDataSource _inner;
  final Set<String> touched = {};

  @override
  Future<T?> get<T>(String key) {
    touched.add(key);
    return _inner.get<T>(key);
  }

  @override
  Future<bool> exists(String key) {
    touched.add(key);
    return _inner.exists(key);
  }

  @override
  Future<void> put<T>(String key, T value) => _inner.put<T>(key, value);
  @override
  Future<void> delete(String key) => _inner.delete(key);
  @override
  Future<void> clear() => _inner.clear();
}
