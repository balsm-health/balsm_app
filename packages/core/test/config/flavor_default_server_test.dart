import 'package:core/src/config/flavor.dart';
import 'package:core/src/config/server_preset.dart';
import 'package:flutter_test/flutter_test.dart';

const _envs = [
  ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050'),
  ServerPreset(label: 'Production', apiBaseUrl: 'https://api.balsm.health'),
  ServerPreset(label: 'Staging', apiBaseUrl: 'https://api-stg-balsm-health.mosalam.com'),
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
    expect(FlavorConfig.current.defaultServer.apiBaseUrl, 'https://api-stg-balsm-health.mosalam.com');
  });
}
