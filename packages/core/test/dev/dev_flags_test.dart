import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // load() also reads the log-encryption key from the keychain, which has no
    // plugin in a unit test. Flags live in plain prefs; this just lets load()
    // finish.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? null : <String, String>{},
    );
  });

  test('the map zoom-floor flag is offered in Dev Config', () {
    expect(kDevFlags.map((f) => f.id), contains(kFlagMapNoZoomFloor));
  });

  test('flags default to off', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    expect(c.read(devFlagProvider(kFlagMapNoZoomFloor)), isFalse);
  });

  test('toggling a flag is visible to the code that reads it', () async {
    // Flags were persist-only; a toggle that stayed inside the panel would make
    // this feature do nothing. The store is shared for exactly this reason.
    final c = ProviderContainer();
    addTearDown(c.dispose);

    final store = c.read(devConfigStoreProvider);
    await store.load();
    await store.setFlag(kFlagMapNoZoomFloor, true);

    expect(c.read(devFlagProvider(kFlagMapNoZoomFloor)), isTrue);

    await store.setFlag(kFlagMapNoZoomFloor, false);
    expect(c.read(devFlagProvider(kFlagMapNoZoomFloor)), isFalse);
  });

  test('a flag survives a reload, so it holds across a restart', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    final store = c.read(devConfigStoreProvider);
    await store.load();
    await store.setFlag(kFlagMapNoZoomFloor, true);
    await store.load();

    expect(store.flag(kFlagMapNoZoomFloor), isTrue);
  });
}
