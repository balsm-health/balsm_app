import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  UserId? active;
  late EncryptedFileStore store;

  const alice = UserId.value('alice');
  const bob = UserId.value('bob');

  // Deterministic per-user keys (32 bytes) — keychain not involved in tests.
  Future<List<int>> keyFor(UserId u) async =>
      List<int>.generate(32, (i) => (i + u.value.length) & 0xff);

  final payload = Uint8List.fromList(List.generate(1024, (i) => i % 251));

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vault_test');
    active = alice;
    store = EncryptedFileStore(
      root: root,
      activeUser: () => active,
      keyFor: keyFor,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('round-trips bytes through the active partition', () async {
    final path = await store.save('r1.pdf', payload);
    expect(path, 'alice/r1.pdf.enc');
    final back = await store.read(path);
    expect(back, payload);
    expect(await store.exists(path), isTrue);
  });

  test('bytes are encrypted at rest (ciphertext != plaintext)', () async {
    final path = await store.save('r1.pdf', payload);
    final raw = await File('${root.path}/alice/r1.pdf.enc').readAsBytes();
    expect(raw.length, greaterThan(payload.length)); // nonce + mac overhead
    // No plaintext window should survive encryption.
    final rawStr = raw.join(',');
    expect(rawStr.contains(payload.sublist(0, 64).join(',')), isFalse);
    expect(path.endsWith('.enc'), isTrue);
  });

  test('partitions are isolated and keyed separately', () async {
    final path = await store.save('r1.pdf', payload);
    active = bob;
    expect(await store.read(path), isNull); // bob's partition has no file
    expect(await store.exists(path), isFalse);
    active = alice;
    expect(await store.read(path), isNotNull);
  });

  test('signed out: reads null/false, mutations throw, clear no-op', () async {
    final path = await store.save('r1.pdf', payload);
    active = null;
    expect(await store.read(path), isNull);
    expect(await store.exists(path), isFalse);
    expect(() => store.save('x.pdf', payload),
        throwsA(isA<NoActiveUserException>()));
    expect(() => store.delete(path), throwsA(isA<NoActiveUserException>()));
    await store.clear(); // must not throw
    active = alice;
    expect(await store.exists(path), isTrue); // clear was a real no-op
  });

  test('tampered file fails loudly on read', () async {
    final path = await store.save('r1.pdf', payload);
    final f = File('${root.path}/alice/r1.pdf.enc');
    final raw = await f.readAsBytes();
    raw[raw.length - 1] ^= 0xff; // corrupt the MAC
    await f.writeAsBytes(raw, flush: true);
    expect(() => store.read(path), throwsA(isA<StorageDecodeException>()));
  });

  test('delete removes one blob; clear wipes the partition', () async {
    final a = await store.save('a.pdf', payload);
    final b = await store.save('b.pdf', payload);
    await store.delete(a);
    expect(await store.exists(a), isFalse);
    expect(await store.exists(b), isTrue);
    await store.clear();
    expect(await store.exists(b), isFalse);
    expect(await Directory('${root.path}/alice').exists(), isFalse);
  });

  test('path traversal is rejected', () async {
    expect(() => store.save('../escape.pdf', payload),
        throwsA(isA<StorageWriteException>()));
    expect(() => store.read('../../etc/passwd'),
        throwsA(isA<StorageWriteException>()));
  });
}
