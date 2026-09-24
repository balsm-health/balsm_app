import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finding the dev machine from the device, at runtime.
///
/// The probe and the interface list are both injected, so nothing here opens a
/// socket: what is under test is which hosts get asked, in what order, and what
/// happens to the URL afterwards.
void main() {
  /// A locator whose network answers only for [serving], recording every host
  /// asked in [asked].
  DevHostLocator locator({
    String? serving,
    List<String>? asked,
    List<String> subnets = const ['192.168.1'],
  }) =>
      DevHostLocator(
        probe: (host, port, timeout) async {
          asked?.add(host);
          return host == serving;
        },
        subnets: () async => subnets,
      );

  test('leaves a URL that names a real host alone', () async {
    const staging = 'https://staging.example.com/api';
    final asked = <String>[];
    expect(await locator(asked: asked).resolve(staging), staging);
    expect(asked, isEmpty, reason: 'a non-loopback URL is never probed');
  });

  test('keeps loopback when loopback is what answers', () async {
    // The simulator and desktop case: the server IS on this machine.
    final l = locator(serving: '127.0.0.1');
    expect(await l.resolve('http://localhost:5050'), 'http://127.0.0.1:5050');
  });

  test('sweeps the subnet and keeps the port and path', () async {
    final l = locator(serving: '192.168.1.24');
    expect(await l.resolve('http://localhost:5050/api'), 'http://192.168.1.24:5050/api');
  });

  test('tries the last known host before sweeping anything', () async {
    final asked = <String>[];
    final l = locator(serving: '192.168.1.24', asked: asked);
    await l.resolve('http://localhost:5050');

    asked.clear();
    await l.resolve('http://localhost:5050');
    expect(asked, ['192.168.1.24'], reason: 'the second lookup is one request, not a sweep');
  });

  test('prefers a caller-supplied host over the sweep', () async {
    final asked = <String>[];
    final l = locator(serving: '10.0.0.9', asked: asked, subnets: const ['10.0.0']);
    expect(await l.resolve('http://localhost:5050', preferred: '10.0.0.9'), 'http://10.0.0.9:5050');
    expect(asked, ['10.0.0.9'], reason: 'DEV_HOST from the launch, asked first and right');
  });

  test('returns the URL untouched when nothing answers', () async {
    final l = locator();
    expect(await l.resolve('http://localhost:5050'), 'http://localhost:5050');
  });

  test('a stale last-known host costs one probe, then the sweep finds the new one', () async {
    final asked = <String>[];
    // Serving moved to .31 while .24 was cached.
    final l = DevHostLocator(
      probe: (host, port, timeout) async {
        asked.add(host);
        return host == '192.168.1.31';
      },
      subnets: () async => const ['192.168.1'],
    )..lastKnown = '192.168.1.24';

    expect(await l.resolve('http://localhost:5050'), 'http://192.168.1.31:5050');
    expect(asked.first, '192.168.1.24');
    expect(l.lastKnown, '192.168.1.31');
  });
}
