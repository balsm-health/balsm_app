import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory keychain: the file keys live under `balsm.file_key.<userId>`.
class _MemKeychain extends SecureStorageWrapper {
  final Map<String, String> data = {};
  @override
  Future<String?> readToken(String key) async => data[key];
  @override
  Future<void> writeToken(String key, String value) async => data[key] = value;
  @override
  Future<void> deleteToken(String key) async => data.remove(key);
}

void main() {
  group('merge and delete', mergeAndDelete);

  late Directory root;
  late _MemKeychain keychain;
  UserId? active;
  late EncryptedFileStore store;

  final payload = Uint8List.fromList(List.generate(256, (i) => i % 251));

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vault_rekey_test');
    keychain = _MemKeychain();
    active = const UserId.value('off-1');
    store = EncryptedFileStore.withKeychainKey(root: root, activeUser: () => active, keychain: keychain);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('moves the partition and the file key to the new owner; files stay readable', () async {
    final path = await store.save('r1.pdf', payload);
    final key = keychain.data['balsm.file_key.off-1'];
    expect(key, isNotNull);

    await store.rekeyOwnerFiles(from: 'off-1', to: 'srv-9');

    expect(await Directory('${root.path}/off-1').exists(), isFalse);
    expect(await File('${root.path}/srv-9/r1.pdf.enc').exists(), isTrue);
    expect(keychain.data['balsm.file_key.srv-9'], key);
    expect(keychain.data.containsKey('balsm.file_key.off-1'), isFalse);

    active = const UserId.value('srv-9');
    expect(await store.read(path), payload);
  });

  test('second call is a no-op', () async {
    await store.save('r1.pdf', payload);
    await store.rekeyOwnerFiles(from: 'off-1', to: 'srv-9');
    await store.rekeyOwnerFiles(from: 'off-1', to: 'srv-9');
    expect(await File('${root.path}/srv-9/r1.pdf.enc').exists(), isTrue);
    expect(keychain.data.containsKey('balsm.file_key.srv-9'), isTrue);
  });

  test('nothing stored yet is a no-op', () async {
    await store.rekeyOwnerFiles(from: 'off-1', to: 'srv-9');
    expect(keychain.data, isEmpty);
    expect(await Directory('${root.path}/srv-9').exists(), isFalse);
  });

  test('throws when the target owner already has a file key', () async {
    await store.save('r1.pdf', payload);
    keychain.data['balsm.file_key.srv-9'] = 'other-key';
    await expectLater(store.rekeyOwnerFiles(from: 'off-1', to: 'srv-9'), throwsStateError);
    // Nothing moved.
    expect(await File('${root.path}/off-1/r1.pdf.enc').exists(), isTrue);
    expect(keychain.data['balsm.file_key.srv-9'], 'other-key');
  });

  test('resumes after a crash between writing the new key and deleting the old one', () async {
    await store.save('r1.pdf', payload);
    keychain.data['balsm.file_key.srv-9'] = keychain.data['balsm.file_key.off-1']!;
    await store.rekeyOwnerFiles(from: 'off-1', to: 'srv-9');
    expect(await File('${root.path}/srv-9/r1.pdf.enc').exists(), isTrue);
    expect(keychain.data.containsKey('balsm.file_key.off-1'), isFalse);
  });

  test('rejects ids that are not a single path segment', () async {
    await expectLater(store.rekeyOwnerFiles(from: '../x', to: 'srv-9'), throwsArgumentError);
    await expectLater(store.rekeyOwnerFiles(from: 'off-1', to: 'a/b'), throwsArgumentError);
  });
}

void mergeAndDelete() {
  late Directory root;
  late _MemKeychain keychain;
  UserId? active;
  late EncryptedFileStore store;

  final a = Uint8List.fromList(List.generate(64, (i) => i));
  final b = Uint8List.fromList(List.generate(64, (i) => 200 - i));

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vault_merge_test');
    keychain = _MemKeychain();
    active = const UserId.value('off-1');
    store = EncryptedFileStore.withKeychainKey(root: root, activeUser: () => active, keychain: keychain);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('mergeOwnerFiles', () {
    test('fresh target: the partition and key move over', () async {
      final path = await store.save('r1.pdf', a);
      final key = keychain.data['balsm.file_key.off-1'];
      await store.mergeOwnerFiles(from: 'off-1', to: 'srv-1');
      expect(keychain.data['balsm.file_key.srv-1'], key);
      expect(keychain.data.containsKey('balsm.file_key.off-1'), isFalse);
      expect(await Directory('${root.path}/off-1').exists(), isFalse);
      active = const UserId.value('srv-1');
      expect(await store.read(path), a);
    });

    test('target with its own files: offline files are re-encrypted under the target key', () async {
      final offPath = await store.save('r1.pdf', a);
      final srvPath = await store.save('s1.pdf', b, scope: const UserId.value('srv-1'));
      final srvKey = keychain.data['balsm.file_key.srv-1'];

      await store.mergeOwnerFiles(from: 'off-1', to: 'srv-1');

      expect(keychain.data['balsm.file_key.srv-1'], srvKey, reason: 'the target keeps its own key');
      expect(keychain.data.containsKey('balsm.file_key.off-1'), isFalse);
      expect(await Directory('${root.path}/off-1').exists(), isFalse);
      active = const UserId.value('srv-1');
      expect(await store.read(offPath), a);
      expect(await store.read(srvPath), b);
    });

    test('idempotent, including a resume after a crash mid-copy', () async {
      await store.save('r1.pdf', a);
      await store.save('r2.pdf', b);
      await store.save('s1.pdf', b, scope: const UserId.value('srv-1'));
      // Crash after r1 was copied but before the offline copy was deleted.
      await store.save('r1.pdf', a, scope: const UserId.value('srv-1'));

      await store.mergeOwnerFiles(from: 'off-1', to: 'srv-1');
      await store.mergeOwnerFiles(from: 'off-1', to: 'srv-1');

      active = const UserId.value('srv-1');
      expect(await store.read('r1.pdf.enc'), a);
      expect(await store.read('r2.pdf.enc'), b);
      expect(await store.read('s1.pdf.enc'), b);
      expect(keychain.data.containsKey('balsm.file_key.off-1'), isFalse);
    });

    test('an undecryptable offline file is dropped; the rest still merge', () async {
      await store.save('bad.pdf', a);
      await store.save('good.pdf', b);
      await store.save('s1.pdf', a, scope: const UserId.value('srv-1'));
      // Corrupt one file: it can't be opened under any key.
      await File('${root.path}/off-1/bad.pdf.enc').writeAsBytes(List.filled(40, 7));

      await store.mergeOwnerFiles(from: 'off-1', to: 'srv-1');

      active = const UserId.value('srv-1');
      expect(await store.read('good.pdf.enc'), b);
      expect(await store.exists('bad.pdf.enc'), isFalse);
      expect(await Directory('${root.path}/off-1').exists(), isFalse);
      expect(keychain.data.containsKey('balsm.file_key.off-1'), isFalse);
    });

    test('nothing stored is a no-op', () async {
      await store.mergeOwnerFiles(from: 'off-1', to: 'srv-1');
      expect(keychain.data, isEmpty);
    });
  });

  group('deleteOwnerFiles', () {
    test('removes the partition and the key, leaves other owners alone; idempotent', () async {
      await store.save('r1.pdf', a);
      await store.save('s1.pdf', b, scope: const UserId.value('srv-1'));

      await store.deleteOwnerFiles(owner: 'off-1');
      await store.deleteOwnerFiles(owner: 'off-1');

      expect(await Directory('${root.path}/off-1').exists(), isFalse);
      expect(keychain.data.containsKey('balsm.file_key.off-1'), isFalse);
      expect(keychain.data.containsKey('balsm.file_key.srv-1'), isTrue);
      expect(await store.read('s1.pdf.enc', scope: const UserId.value('srv-1')), b);
    });

    test('rejects ids that are not a single path segment', () async {
      await expectLater(store.deleteOwnerFiles(owner: '..'), throwsArgumentError);
    });
  });
}
