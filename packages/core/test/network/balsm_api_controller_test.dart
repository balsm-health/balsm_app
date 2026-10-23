import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

// A non-loopback default, so DevHostLocator never probes the network.
const _default = ServerPreset(label: 'Dev', apiBaseUrl: 'https://api-dev.example.com');
const _key = 'balsm.active_server_preset';

String _saved(String url) => jsonEncode({'label': 'LAN', 'apiBaseUrl': url});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStorage storage;
  late BalsmApiClient client;
  late BalsmApiController controller;

  void setUpWith(Map<String, String> stored) {
    FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.dev, servers: const [_default]);
    FlutterSecureStorage.setMockInitialValues(stored);
    storage = const FlutterSecureStorage();
    client = BalsmApiClient.create(baseUrl: _default.apiBaseUrl);
    controller = BalsmApiController(client: client, store: ActiveServerStore(storage), bus: EventBus());
  }

  group('init', () {
    test('repairs a saved server that only lacks its scheme, and saves the fix', () async {
      // What older builds stored after Dev Config's failed save (BALSM-APP-1X).
      setUpWith({_key: _saved('192.168.8.3:5050')});

      await controller.init();

      expect(client.baseUrl, 'http://192.168.8.3:5050');
      final stored = jsonDecode((await storage.read(key: _key))!) as Map<String, dynamic>;
      expect(stored['apiBaseUrl'], 'http://192.168.8.3:5050');
    });

    test('drops a saved server that cannot work and boots on the default', () async {
      setUpWith({_key: _saved('http://')});

      await controller.init();

      expect(client.baseUrl, _default.apiBaseUrl);
      expect(await storage.read(key: _key), isNull);
    });

    test('keeps a valid saved server as it is', () async {
      setUpWith({_key: _saved('https://staging.example.com')});

      await controller.init();

      expect(client.baseUrl, 'https://staging.example.com');
    });
  });

  group('reconfigure', () {
    test('adds the scheme before applying and saving', () async {
      setUpWith({});

      await controller.reconfigure(const ServerPreset(label: 'LAN', apiBaseUrl: '192.168.8.3:5050'));

      expect(client.baseUrl, 'http://192.168.8.3:5050');
      final stored = jsonDecode((await storage.read(key: _key))!) as Map<String, dynamic>;
      expect(stored['apiBaseUrl'], 'http://192.168.8.3:5050');
    });

    test('rejects an unusable URL without saving it or moving the client', () async {
      setUpWith({});

      await expectLater(
        controller.reconfigure(const ServerPreset(label: 'Bad', apiBaseUrl: 'http://')),
        throwsFormatException,
      );

      expect(client.baseUrl, _default.apiBaseUrl);
      expect(await storage.read(key: _key), isNull);
    });
  });
}
