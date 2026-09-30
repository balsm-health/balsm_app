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
