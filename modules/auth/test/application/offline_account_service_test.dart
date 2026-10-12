import 'dart:convert';

import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MemStorage extends Mock implements SecureStorageWrapper {
  final m = <String, String>{};
  @override
  Future<String?> readToken(String key) async => m[key];
  @override
  Future<void> writeToken(String key, String value) async => m[key] = value;
  @override
  Future<void> deleteToken(String key) async => m.remove(key);
}

/// Fast stand-in: Argon2id itself is exercised in the last test.
class _PlainHasher implements OfflinePasswordHasher {
  @override
  Future<String> hash(String pw) async => 'h:$pw';
  @override
  Future<bool> verify(String pw, String encoded) async => encoded == 'h:$pw';
}

void main() {
  late _MemStorage storage;
  late EventBus bus;
  late DateTime clock;
  late OfflineAccountService svc;

  setUp(() {
    storage = _MemStorage();
    bus = EventBus();
    clock = DateTime.utc(2026, 10, 1, 12);
    svc = OfflineAccountService(storage: storage, hasher: _PlainHasher(), eventBus: bus, now: () => clock);
  });

  test('create stores id, mode, email, hash and plaintext; publishes UserSignedIn', () async {
    final events = <UserSignedIn>[];
    bus.on<UserSignedIn>().listen(events.add);

    final id = await svc.create(email: ' Layla@Example.com ', password: 'correct-horse');
    await Future<void>.delayed(Duration.zero);

    expect(storage.m['balsm.user_id'], id);
    expect(storage.m['balsm.account_mode'], 'deviceOnly');
    expect(storage.m['balsm.offline.email'], 'layla@example.com');
    expect(storage.m['balsm.offline.pw_hash'], 'h:correct-horse');
    expect(storage.m['balsm.offline.pw_plain'], 'correct-horse');
    expect(events.single.userId.value, id);
    expect(await svc.mode(), AccountMode.deviceOnly);
  });

  test('create rejects passwords under 8', () async {
    await expectLater(svc.create(email: 'a@b.co', password: '1234567'), throwsArgumentError);
    expect(storage.m, isEmpty);
  });

  test('unlock with the right password resets failures', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    await svc.unlock('wrong-one');
    expect(await svc.unlock('correct-horse'), isA<Unlocked>());
    expect(storage.m.containsKey('balsm.offline.lockout'), isFalse);
  });

  test('five failures lock for 30s, then 1m, 5m, 15m, 1h cap', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    for (var i = 1; i <= 4; i++) {
      expect(await svc.unlock('nope'), isA<WrongPassword>());
    }
    const waits = [30, 60, 300, 900, 3600, 3600];
    for (final secs in waits) {
      final r = await svc.unlock('nope');
      expect(r, isA<LockedUntil>());
      expect((r as LockedUntil).until, clock.add(Duration(seconds: secs)));
      clock = r.until; // wait it out
    }
  });

  test('while locked out, even the right password is refused', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    for (var i = 0; i < 5; i++) {
      await svc.unlock('nope');
    }
    expect(await svc.unlock('correct-horse'), isA<LockedUntil>());
  });

  test('lockout survives a new service instance (app restart)', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    for (var i = 0; i < 5; i++) {
      await svc.unlock('nope');
    }
    final restarted = OfflineAccountService(storage: storage, hasher: _PlainHasher(), eventBus: bus, now: () => clock);
    expect(await restarted.lockout(), isNotNull);
  });

  test('markOnline keeps id and plaintext, drops offline-only keys', () async {
    final id = await svc.create(email: 'a@b.co', password: 'correct-horse');
    await svc.markOnline();
    expect(storage.m['balsm.user_id'], id);
    expect(storage.m['balsm.account_mode'], 'online');
    expect(storage.m['balsm.offline.pw_plain'], 'correct-horse');
    expect(storage.m.keys.where((k) => k.startsWith('balsm.offline.') && k != 'balsm.offline.pw_plain'), isEmpty);
    await svc.clearPlainPassword();
    expect(await svc.pendingCredentials(), isNull);
  });

  test('wipe removes every offline key and the user id', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    await svc.setPendingMerge(true);
    await svc.wipe();
    expect(storage.m, isEmpty);
  });

  test('create refuses while a device-only account already exists', () async {
    final id = await svc.create(email: 'a@b.co', password: 'correct-horse');
    await expectLater(svc.create(email: 'c@d.co', password: 'other-horse'), throwsStateError);
    // The first account is untouched.
    expect(storage.m['balsm.user_id'], id);
    expect(await svc.unlock('correct-horse'), isA<Unlocked>());
  });

  test('create works again after wipe', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    await svc.wipe();
    expect(await svc.create(email: 'c@d.co', password: 'other-horse'), isNotEmpty);
  });

  test('stale lockout does not carry into a new create', () async {
    storage.m['balsm.offline.lockout'] = jsonEncode({
      'failures': 5,
      'until': clock.add(const Duration(hours: 1)).toIso8601String(),
    });

    await svc.create(email: 'a@b.co', password: 'correct-horse');

    expect(await svc.unlock('correct-horse'), isA<Unlocked>());
  });

  test('discardIncompleteCreate wipes orphans when mode is absent', () async {
    storage.m['balsm.offline.email'] = 'a@b.co';
    storage.m['balsm.offline.pw_hash'] = 'h:x';
    storage.m['balsm.offline.pw_plain'] = 'x';
    storage.m['balsm.user_id'] = 'usr-orphan';
    // No balsm.account_mode, no balsm.refresh_token.

    await svc.discardIncompleteCreate();

    expect(storage.m, isEmpty);
  });

  test('discardIncompleteCreate leaves the user id when a refresh token exists', () async {
    storage.m['balsm.offline.email'] = 'a@b.co';
    storage.m['balsm.user_id'] = 'usr-real';
    storage.m['balsm.refresh_token'] = 'rt-real';
    // No balsm.account_mode.

    await svc.discardIncompleteCreate();

    expect(storage.m['balsm.user_id'], 'usr-real');
    expect(storage.m['balsm.refresh_token'], 'rt-real');
    expect(storage.m.containsKey('balsm.offline.email'), isFalse);
  });

  test('discardIncompleteCreate is a no-op once mode is deviceOnly', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    final before = Map<String, String>.from(storage.m);

    await svc.discardIncompleteCreate();

    expect(storage.m, before);
  });

  test('discardIncompleteCreate is a no-op when online with a pending pw_plain', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    await svc.markOnline();
    final before = Map<String, String>.from(storage.m);

    await svc.discardIncompleteCreate();

    expect(storage.m, before);
  });

  test('Argon2id hasher round-trips and rejects a wrong password', () async {
    final h = Argon2idOfflinePasswordHasher();
    final enc = await h.hash('correct-horse');
    expect(enc, startsWith(r'$argon2id$'));
    expect(await h.verify('correct-horse', enc), isTrue);
    expect(await h.verify('correct-hors3', enc), isFalse);
  });
}
