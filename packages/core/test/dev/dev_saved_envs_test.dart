import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Custom servers saved in Dev Config by builds that stored the URL as typed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'balsm_dev_saved_envs';
  String envs(List<String> urls) => jsonEncode([
        for (final (i, u) in urls.indexed) {'id': 'saved_$i', 'name': 'Env $i', 'url': u}
      ]);

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('a saved server without its scheme is repaired on load, and kept repaired', () async {
    SharedPreferences.setMockInitialValues({
      key: envs(['192.168.8.3:5050', 'https://staging.example.com'])
    });

    final store = DevConfigStore();
    await store.load();

    expect(store.savedEnvs.map((e) => e.url), ['http://192.168.8.3:5050', 'https://staging.example.com']);
    final persisted = jsonDecode((await SharedPreferences.getInstance()).getString(key)!) as List;
    expect(persisted.first['url'], 'http://192.168.8.3:5050');
  });

  test('one that cannot be repaired is left to edit or delete', () async {
    SharedPreferences.setMockInitialValues({
      key: envs(['http://'])
    });

    final store = DevConfigStore();
    await store.load();

    expect(store.savedEnvs.single.url, 'http://');
  });
}
