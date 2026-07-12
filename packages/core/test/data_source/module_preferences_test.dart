import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _V2Prefs extends ModulePreferences {
  _V2Prefs(super.kv, {this.failStep2 = false}) : super(namespace: 'demo');

  final bool failStep2;
  final ran = <int>[];

  @override
  int get schemaVersion => 2;

  @override
  Map<int, PrefsMigrationStep> get migrations => {
        1: (m) async {
          ran.add(1);
          await m.rename('lang', 'locale');
        },
        2: (m) async {
          ran.add(2);
          if (failStep2) throw StateError('boom');
          await m.transform<String>(
              'storage', (v) => v == 'gdrive' ? 'google_drive' : v);
        },
      };

  Future<String?> locale() => read<String>('locale');
  Future<String?> storage() => read<String>('storage');
  Future<int?> storedVersion() => read<int>('_v');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPrefsKVDataSource> kv([Map<String, Object>? seed]) async {
    SharedPreferences.setMockInitialValues(seed ?? {});
    return SharedPrefsKVDataSource(await SharedPreferences.getInstance());
  }

  test('fresh store: all steps run as no-ops, version stamped', () async {
    final p = _V2Prefs(await kv());
    await p.migrate();
    expect(p.ran, [1, 2]);
    expect(await p.storedVersion(), 2);
  });

  test('legacy (pre-versioning) store migrates keys and values', () async {
    final p = _V2Prefs(await kv({
      'demo.lang': 'ar',
      'demo.storage': 'gdrive',
    }));
    await p.migrate();
    expect(await p.locale(), 'ar'); // renamed lang -> locale
    expect(await p.storage(), 'google_drive'); // value transformed
    expect(await p.storedVersion(), 2);
  });

  test('partial upgrade runs only the pending steps', () async {
    final p = _V2Prefs(await kv({'demo._v': 1, 'demo.storage': 'gdrive'}));
    await p.migrate();
    expect(p.ran, [2]); // step 1 skipped
    expect(await p.storage(), 'google_drive');
  });

  test('re-running migrate is a no-op once stamped', () async {
    final store = await kv();
    final p = _V2Prefs(store);
    await p.migrate();
    final again = _V2Prefs(store);
    await again.migrate();
    expect(again.ran, isEmpty);
  });

  test('downgrade (stored newer than supported) fails loudly', () async {
    final p = _V2Prefs(await kv({'demo._v': 9}));
    expect(p.migrate, throwsA(isA<StorageDecodeException>()));
  });

  test('failing step aborts without stamping — retried next launch', () async {
    final store = await kv({'demo.lang': 'ar'});
    final failing = _V2Prefs(store, failStep2: true);
    await expectLater(failing.migrate(), throwsA(isA<StateError>()));
    expect(await failing.storedVersion(), isNull); // not stamped

    final retry = _V2Prefs(store);
    await retry.migrate();
    expect(retry.ran, [1, 2]); // both retried (steps are idempotent)
    expect(await retry.storedVersion(), 2);
  });
}
