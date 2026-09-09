import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/prefs.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boot routing must follow the credentials, not the prefs flag.
///
/// `signedIn` is a plain KV bool; the session id lives in the keychain under
/// `balsm.user_id`. They can disagree — a restored-from-backup device, a
/// cleared keychain, or a reinstall keeps the flag and loses the id. Routing on
/// the flag alone landed the patient in the signed-in shell with a null user
/// id, where the account summary and every PHI read resolve to nothing and
/// nothing recovers: with no token there is no refresh, so `SessionExpired`
/// never fires and the shell never returns to auth.
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

void main() {
  late _MemoryKV kv;
  late PatientAppPrefs prefs;

  setUp(() {
    kv = _MemoryKV();
    prefs = PatientAppPrefs(kv);
  });

  test('signed-in flag plus real credentials enters the app shell', () async {
    await prefs.setSignedIn(true);
    final s = await PatientAppState.load(prefs, hasSession: true);
    expect(s.route, 'app');
  });

  test('signed-in flag without credentials falls back to welcome', () async {
    await prefs.setSignedIn(true);
    await prefs.setWalkthroughSeen(true);
    final s = await PatientAppState.load(prefs, hasSession: false);
    expect(s.route, 'welcome', reason: 'a null user id must never reach the signed-in shell');
  });

  test('the stale flag is cleared so the next launch agrees with the keychain', () async {
    await prefs.setSignedIn(true);
    await PatientAppState.load(prefs, hasSession: false);
    expect(await prefs.signedIn(), isFalse);
  });

  test('a never-signed-in device still sees the walkthrough first', () async {
    final s = await PatientAppState.load(prefs, hasSession: false);
    expect(s.route, 'walkthrough');
  });

  test('credentials without the flag stay signed out', () async {
    await prefs.setWalkthroughSeen(true);
    final s = await PatientAppState.load(prefs, hasSession: true);
    expect(s.route, 'welcome', reason: 'an explicit sign-out must not be undone by a stale keychain id');
  });
}
