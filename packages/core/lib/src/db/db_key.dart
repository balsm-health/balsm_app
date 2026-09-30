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
