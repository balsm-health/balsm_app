import 'dart:io';

import 'package:core/src/db/db_key.dart';
import 'package:core/src/db/db_key_check_io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory docs;
  const storage = FlutterSecureStorage();

  setUp(() {
    docs = Directory.systemTemp.createTempSync('db_key_check');
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => docs.deleteSync(recursive: true));

  File db() => File('${docs.path}/$kDbFileName');
  // SQLCipher pages are random from byte 0; anything that is not the
  // plaintext header stands in for one.
  void writeEncryptedDb() => db().writeAsBytesSync(List<int>.generate(4096, (i) => (i * 31 + 7) % 256));

  group('checkDbKey', () {
    test('ok on a fresh install: no key, no database', () async {
      expect(await checkDbKey(storage: storage, documents: docs), DbKeyStatus.ok);
    });

    test('ok when the key is there', () async {
      writeEncryptedDb();
      FlutterSecureStorage.setMockInitialValues({kDbKeyStorageKey: generateDbKeyHex()});
      expect(await checkDbKey(storage: storage, documents: docs), DbKeyStatus.ok);
    });

    test('lost when an encrypted database has no key', () async {
      writeEncryptedDb();
      expect(await checkDbKey(storage: storage, documents: docs), DbKeyStatus.lost);
    });

    test('ok for an empty or plaintext file: opening replaces those (spec D7)', () async {
      db().writeAsBytesSync([]);
      expect(await checkDbKey(storage: storage, documents: docs), DbKeyStatus.ok);
      db().writeAsStringSync('SQLite format 3\u0000 and the rest of a plaintext file');
      expect(await checkDbKey(storage: storage, documents: docs), DbKeyStatus.ok);
    });
  });

  group('setAsideUnreadableData', () {
    final at = DateTime.utc(2026, 11, 26, 21, 30, 5);

    test('renames the database, its side files and the vault; deletes nothing', () async {
      writeEncryptedDb();
      File('${docs.path}/$kDbFileName-wal').writeAsStringSync('wal');
      File('${docs.path}/$kDbFileName-shm').writeAsStringSync('shm');
      Directory('${docs.path}/$kVaultDirName/user').createSync(recursive: true);
      File('${docs.path}/$kVaultDirName/user/file.bin').writeAsStringSync('sealed');

      await setAsideUnreadableData(documents: docs, now: at);

      const suffix = '.lost-20261126T213005Z';
      expect(db().existsSync(), isFalse);
      expect(File('${docs.path}/$kDbFileName$suffix').lengthSync(), 4096);
      expect(File('${docs.path}/$kDbFileName-wal$suffix').readAsStringSync(), 'wal');
      expect(File('${docs.path}/$kDbFileName-shm$suffix').readAsStringSync(), 'shm');
      expect(Directory('${docs.path}/$kVaultDirName').existsSync(), isFalse);
      expect(File('${docs.path}/$kVaultDirName$suffix/user/file.bin').readAsStringSync(), 'sealed');
    });

    test('afterwards the check is ok, so the app can open a new database', () async {
      writeEncryptedDb();
      await setAsideUnreadableData(documents: docs, now: at);
      expect(await checkDbKey(storage: storage, documents: docs), DbKeyStatus.ok);
    });

    test('does nothing when there is nothing to move', () async {
      await setAsideUnreadableData(documents: docs, now: at);
      expect(docs.listSync(), isEmpty);
    });
  });
}
