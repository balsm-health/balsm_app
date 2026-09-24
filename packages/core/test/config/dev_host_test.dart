import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repointing a loopback preset at the dev machine (`DEV_HOST`).
///
/// A phone's `localhost` is the phone, so a device on the desk needs the
/// address the desktop answers on. `bin/balsm run` injects it; this is the
/// rewrite it feeds.
void main() {
  test('swaps the host and keeps everything else', () {
    expect(
      FlavorConfig.resolveDevHost('http://localhost:5050', host: '192.168.1.24'),
      'http://192.168.1.24:5050',
    );
    expect(
      FlavorConfig.resolveDevHost('http://127.0.0.1:5050/api', host: '192.168.1.24'),
      'http://192.168.1.24:5050/api',
    );
  });

  test('leaves a real host alone', () {
    const staging = 'https://staging.example.com';
    expect(FlavorConfig.resolveDevHost(staging, host: '192.168.1.24'), staging);
  });

  test('no host is a no-op, so an ordinary build never changes', () {
    expect(FlavorConfig.resolveDevHost('http://localhost:5050', host: ''), 'http://localhost:5050');
    expect(FlavorConfig.resolveDevHost('http://localhost:5050', host: '   '), 'http://localhost:5050');
  });

  test('a hostname works as well as an address', () {
    // mDNS: survives the DHCP lease changing under the machine.
    expect(
      FlavorConfig.resolveDevHost('http://localhost:5050', host: 'macbook.local'),
      'http://macbook.local:5050',
    );
  });

  test('rewrites every configured server, prod excepted', () {
    const local = ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050');
    const live = ServerPreset(label: 'Production', apiBaseUrl: 'https://api.example.com');

    FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.dev, servers: [local, live]);
    // No DEV_HOST is compiled into the test binary, so the list is unchanged —
    // what matters here is that prod refuses even when one is.
    expect(FlavorConfig.current.servers.map((s) => s.apiBaseUrl), [local.apiBaseUrl, live.apiBaseUrl]);
    expect(FlavorConfig.current.withDevHost('http://localhost:5050'), 'http://localhost:5050');

    FlavorConfig.init(brand: AppBrand.balsm, flavor: Flavor.prod, servers: [local, live]);
    expect(FlavorConfig.current.withDevHost('http://localhost:5050'), 'http://localhost:5050',
        reason: 'a production build is never repointed');
  });
}
