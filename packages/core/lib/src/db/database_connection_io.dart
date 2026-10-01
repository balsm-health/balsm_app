import 'dart:ffi';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

/// Load SQLCipher into this isolate so `sqlite3` `source: process` can resolve
/// `sqlite3_initialize`. Android ships `libsqlcipher.so`; iOS/macOS ship
/// `SQLCipher.framework` via CocoaPods.
void _ensureSqlCipherLoaded() {
  if (Platform.isAndroid) {
    // Calling `openCipherOnAndroid()` directly loads libsqlcipher.so but
    // discards the handle, so sqlite3's native-assets FFI resolver still
    // can't see `sqlite3_initialize` and falls back to a process-wide symbol
    // lookup that fails (BALSM-APP-S). Registering it as the open override
    // makes sqlite3 resolve against that handle instead.
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
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
      // macOS: legacy file keychain — the data-protection keychain needs a
      // provisioned keychain-access-group entitlement (-34018 without it).
      const storage = FlutterSecureStorage(mOptions: MacOsOptions(useDataProtectionKeyChain: false));
      var key = await storage.read(key: 'balsm.db.key');
      if (key == null) {
        final bytes = List<int>.generate(32, (_) => DateTime.now().microsecond);
        key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        await storage.write(key: 'balsm.db.key', value: key);
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/balsm.db');
      return NativeDatabase(file);
    });
