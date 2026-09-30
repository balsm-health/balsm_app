import 'dart:ffi';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import '../secure_storage/secure_storage_wrapper.dart';
import 'db_key.dart';

/// Load SQLCipher into this isolate so `sqlite3` `source: process` can resolve
/// `sqlite3_initialize`. Android ships `libsqlcipher.so`; iOS/macOS ship
/// `SQLCipher.framework` via CocoaPods.
void _ensureSqlCipherLoaded() {
  if (Platform.isAndroid) {
    openCipherOnAndroid();
    return;
  }
  if (Platform.isIOS || Platform.isMacOS) {
    try {
      DynamicLibrary.open('SQLCipher.framework/SQLCipher');
    } on ArgumentError {
      // Already linked into the process by the plugin.
    }
  }
}

/// Native (iOS/Android/desktop) executor — the real on-device SQLCipher store.
QueryExecutor openExecutor() => LazyDatabase(() async {
      _ensureSqlCipherLoaded();
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
