import 'dart:math';

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
