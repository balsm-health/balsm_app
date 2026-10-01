import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import '../secure_storage/secure_storage_wrapper.dart';
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

      var key = await storage.read(key: kDbKeyStorageKey);
      if (key == null) {
        // Pre-launch builds wrote an unencrypted balsm.db. It cannot be opened
        // with a key, and there are no real users to migrate (spec D7).
        if (file.existsSync()) file.deleteSync();
        key = generateDbKeyHex();
        await storage.write(key: kDbKeyStorageKey, value: key);
      }
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
