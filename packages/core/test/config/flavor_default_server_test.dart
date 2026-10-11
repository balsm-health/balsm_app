import 'package:core/src/config/env_hosts.dart';
import 'package:core/src/config/flavor.dart';
import 'package:core/src/config/server_preset.dart';
import 'package:flutter_test/flutter_test.dart';

const _envs = [
  ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050'),
  ServerPreset(label: 'Production', apiBaseUrl: 'https://api.balsm.health'),
  ServerPreset(label: 'Staging', apiBaseUrl: 'https://api-stg.balsm.health'),
];

void main() {
  test('prod boots against Production, not the first ENVS entry', () {
    FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.prod, servers: _envs);
    expect(FlavorConfig.current.defaultServer.apiBaseUrl, 'https://api.balsm.health');
    expect(FlavorConfig.current.serverSwitchingEnabled, isFalse);
  });

  test('dev boots against Local', () {
    FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.dev, servers: _envs);
    expect(FlavorConfig.current.defaultServer.apiBaseUrl, 'http://localhost:5050');
    expect(FlavorConfig.current.serverSwitchingEnabled, isTrue);
  });

  test('staging boots against Staging', () {
    FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.staging, servers: _envs);
    expect(FlavorConfig.current.defaultServer.apiBaseUrl, 'https://api-stg.balsm.health');
  });

  group('with no entry for the environment', () {
    const localOnly = [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')];

    test('a production build boots against the production API, never Local', () {
      FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.prod, servers: localOnly);
      // This test build has no HOST_SUFFIX, which is what production means.
      expect(FlavorConfig.current.defaultServer.apiBaseUrl, 'https://api.balsm.health');
    });

    test('a dev build still takes the first entry', () {
      FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.dev, servers: localOnly);
      expect(FlavorConfig.current.defaultServer.apiBaseUrl, 'http://localhost:5050');
    });
  });

  group('envHost', () {
    test('no suffix is the production name', () {
      expect(envHost('app', suffix: ''), 'app.balsm.health');
      expect(envHost('api', suffix: ''), 'api.balsm.health');
    });

    test('a suffix is appended to the first label', () {
      expect(envHost('app', suffix: 'stg'), 'app-stg.balsm.health');
      expect(envHost('api', suffix: 'stg'), 'api-stg.balsm.health');
      expect(envHost('portal', suffix: 'qa'), 'portal-qa.balsm.health');
    });
  });
}
