import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Synthetic, non-PHI.
class _Thing {
  const _Thing(this.name);
  final String name;
  Map<String, dynamic> toJson() => {'name': name};
  static _Thing fromJson(Map<String, dynamic> j) => _Thing(j['name'] as String);
}

void main() {
  late AppDatabase db;
  late CachedValue<_Thing> cached;

  CachedValue<_Thing> valueWith(Duration ttl) => CachedValue<_Thing>(
        store: DriftCacheStore(db),
        namespace: 'thing',
        ttl: ttl,
        decode: _Thing.fromJson,
        encode: (t) => t.toJson(),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cached = valueWith(const Duration(hours: 1));
  });
  tearDown(() => db.close());

  test('a miss fetches and retains', () async {
    var calls = 0;
    final got = await cached.read('k', fetch: () async {
      calls++;
      return const _Thing('fetched');
    });
    expect(got!.name, 'fetched');
    expect(calls, 1);
    expect((await cached.peek('k'))!.name, 'fetched');
  });

  test('a fresh hit does not fetch', () async {
    await cached.read('k', fetch: () async => const _Thing('first'));
    var calls = 0;
    final got = await cached.read('k', fetch: () async {
      calls++;
      return const _Thing('second');
    });
    expect(calls, 0, reason: 'a fresh row must not touch the network');
    expect(got!.name, 'first');
  });

  test('a stale hit refetches and replaces', () async {
    final expiring = valueWith(Duration.zero);
    await expiring.read('k', fetch: () async => const _Thing('old'));
    final got = await expiring.read('k', fetch: () async => const _Thing('new'));
    expect(got!.name, 'new');
  });

  test('an offline error on refetch serves the stale row', () async {
    final expiring = valueWith(Duration.zero);
    await expiring.read('k', fetch: () async => const _Thing('old'));

    final got = await expiring.read('k', fetch: () async => throw const SocketException('offline'));

    expect(got!.name, 'old');
  });

  test('a server error rethrows and does NOT serve stale', () async {
    final expiring = valueWith(Duration.zero);
    await expiring.read('k', fetch: () async => const _Thing('old'));

    await expectLater(
      () => expiring.read('k', fetch: () async => throw StateError('boom')),
      throwsA(isA<StateError>()),
      reason: 'serving stale for a server error hides the bug forever',
    );
    expect((await expiring.peek('k'))!.name, 'old', reason: 'the row survives, it is just not served');
  });

  test('an offline error with nothing cached rethrows', () async {
    await expectLater(
      () => cached.read('k', fetch: () async => throw const SocketException('offline')),
      throwsA(isA<SocketException>()),
    );
  });

  test('peek never fetches', () async {
    expect(await cached.peek('absent'), isNull);
  });

  test('keys do not leak across each other', () async {
    await cached.read('u1', fetch: () async => const _Thing('one'));
    await cached.read('u2', fetch: () async => const _Thing('two'));
    expect((await cached.peek('u1'))!.name, 'one');
    expect((await cached.peek('u2'))!.name, 'two');
  });

  test('invalidate forces the next read to fetch', () async {
    await cached.read('k', fetch: () async => const _Thing('first'));
    await cached.invalidate('k');
    final got = await cached.read('k', fetch: () async => const _Thing('second'));
    expect(got!.name, 'second');
  });

  test('invalidateAll clears the namespace', () async {
    await cached.read('u1', fetch: () async => const _Thing('one'));
    await cached.read('u2', fetch: () async => const _Thing('two'));
    await cached.invalidateAll();
    expect(await cached.peek('u1'), isNull);
    expect(await cached.peek('u2'), isNull);
  });

  test('a corrupt payload is treated as a miss, not an error', () async {
    await DriftCacheStore(db).write('thing', 'k', 'not json at all');
    final got = await cached.read('k', fetch: () async => const _Thing('recovered'));
    expect(got!.name, 'recovered');
  });

  test('a corrupt payload is not served when the refetch fails offline', () async {
    await DriftCacheStore(db).write('thing', 'k', 'not json at all');
    await expectLater(
      () => cached.read('k', fetch: () async => throw const SocketException('offline')),
      throwsA(isA<SocketException>()),
      reason: 'undecodable is indistinguishable from absent — there is nothing to serve',
    );
  });

  test('a null fetch result clears the row', () async {
    await cached.read('k', fetch: () async => const _Thing('first'));
    await cached.invalidate('k');
    final got = await cached.read('k', fetch: () async => null);
    expect(got, isNull);
    expect(await cached.peek('k'), isNull);
  });
}
