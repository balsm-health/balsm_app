import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The key that encrypts an exported log bundle.
///
/// It lives in the OS keychain and is minted once. Regenerating it is how a key
/// that has been pasted into a chat or a ticket stops being the key that opens
/// the next export.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> keychain;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    keychain = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => switch (call.method) {
        'read' => keychain[call.arguments['key'] as String],
        'write' => keychain[call.arguments['key'] as String] = call.arguments['value'] as String,
        _ => <String, String>{},
      },
    );
  });

  test('a fresh install mints a key', () async {
    final store = DevConfigStore();
    await store.load();

    expect(store.encKey, isNotEmpty);
    expect(store.encKey, matches(RegExp(r'^[0-9a-f]{40}$')), reason: '20 random bytes as hex');
  });

  test('regenerating replaces the key', () async {
    final store = DevConfigStore();
    await store.load();
    final before = store.encKey;

    final after = await store.regenerateEncKey();

    expect(after, isNot(before));
    expect(store.encKey, after);
    expect(after, matches(RegExp(r'^[0-9a-f]{40}$')));
  });

  test('the new key outlives the session', () async {
    final store = DevConfigStore();
    await store.load();
    final regenerated = await store.regenerateEncKey();

    // A second store reads the same keychain — a key that only lived in memory
    // would leave yesterday's exports unopenable and today's unreadable.
    final reopened = DevConfigStore();
    await reopened.load();

    expect(reopened.encKey, regenerated);
  });

  test('listeners hear about it, so the screen redraws the key it shows', () async {
    final store = DevConfigStore();
    await store.load();
    var notified = 0;
    store.addListener(() => notified++);

    await store.regenerateEncKey();

    expect(notified, greaterThan(0));
  });
}
