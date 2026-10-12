import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import '../secure_storage/secure_storage_wrapper.dart';
import 'db_file_guard_io.dart';
import 'db_key.dart';

/// Native (iOS/Android/desktop) executor — the real on-device SQLCipher store.
///
/// SQLCipher is bundled by package:sqlite3's build hook (`source: sqlcipher`
/// in app/pubspec.yaml); nothing needs to be loaded by hand here.
QueryExecutor openExecutor() => LazyDatabase(() async {
      // The shared store — see SecureStorageWrapper for why a fresh
      // FlutterSecureStorage() reads a different file on Android.
      const storage = SecureStorageWrapper.storage;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/balsm.db');

      // The v1 key was never applied (spec D7); drop it if an old build left it.
      if (await storage.read(key: kLegacyDbKeyStorageKey) != null) {
        await storage.delete(key: kLegacyDbKeyStorageKey);
      }
      var key = await storage.read(key: kDbKeyStorageKey);
      if (key == null) {
        // Pre-launch builds wrote an unencrypted balsm.db. It cannot be opened
        // with a key, and there are no real users to migrate (spec D7). Only
        // a plaintext file is deleted; an encrypted one throws.
        prepareDbFileForNewKey(file);
        key = generateDbKeyHex();
        await storage.write(key: kDbKeyStorageKey, value: key);
      }
      // Spliced into the PRAGMA below, so it must be exactly the hex shape
      // generateDbKeyHex writes.
      if (!isValidDbKeyHex(key)) throw StateError('stored database key is malformed');
      final hexKey = key;
      return NativeDatabase(
        file,
        setup: (db) {
          db.execute("PRAGMA key = \"x'$hexKey'\"");
          // Fails loudly if SQLCipher isn't the loaded sqlite (plain sqlite
          // returns no row here and would silently store plaintext).
          final v = db.select('PRAGMA cipher_version');
          if (v.isEmpty) throw StateError('SQLCipher not loaded; refusing to open an unencrypted database');
        },
      );
    });
