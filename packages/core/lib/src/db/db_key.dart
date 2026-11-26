import 'dart:math';

/// The on-device database file, in the app's documents directory.
const kDbFileName = 'balsm.db';

/// The encrypted-files folder next to it (see `bind_file_store_io.dart`). Its
/// per-account keys live in the same keychain as [kDbKeyStorageKey], so they
/// are lost together.
const kVaultDirName = 'vault';

/// Whether the on-device database can be opened (see `checkDbKey`).
enum DbKeyStatus {
  /// The key is there, or there is no encrypted database that needs one.
  ok,

  /// An encrypted database is on disk but its key is gone from secure storage:
  /// it can never be opened, and must not be silently replaced.
  lost,
}

/// Secure-storage key for the SQLCipher key. `.v2` because the v1 key was
/// never applied and was not random; it must not be reused.
const kDbKeyStorageKey = 'balsm.db.key.v2';

/// 32 random bytes as hex. [random] is for tests only; production uses
/// [Random.secure].
String generateDbKeyHex([Random? random]) {
  final r = random ?? Random.secure();
  return List<int>.generate(32, (_) => r.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Secure-storage key the never-applied v1 DB key was written under. Dead:
/// deleted at open so it doesn't linger in the keychain.
const kLegacyDbKeyStorageKey = 'balsm.db.key';

final _dbKeyHex = RegExp(r'^[0-9a-f]{64}$');

/// True for exactly 64 lowercase hex characters — the only shape
/// [generateDbKeyHex] writes, and the only one safe to splice into
/// `PRAGMA key`.
bool isValidDbKeyHex(String key) => _dbKeyHex.hasMatch(key);
