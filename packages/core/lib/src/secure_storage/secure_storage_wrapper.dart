import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageWrapper>(
  (_) => SecureStorageWrapper(),
);

class SecureStorageWrapper {
  /// The one secure store for session credentials. Anything that reads or
  /// writes `balsm.*` tokens directly must use THIS instance: on Android the
  /// options pick the backing file, so a `FlutterSecureStorage()` with default
  /// options reads a different, empty store — every restart then looked
  /// signed out, and the interceptor could never find the refresh token.
  static const FlutterSecureStorage storage = _storage;

  static const _storage = FlutterSecureStorage(
    // Keep encryptedSharedPreferences through v10: it is how v10 finds and migrates
    // existing v9 data. Drop it only together with the move to v11.
    // ignore: deprecated_member_use
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // macOS: the iOS-style data-protection keychain demands a
    // keychain-access-groups entitlement backed by a provisioning profile;
    // without one every operation fails with errSecMissingEntitlement
    // (-34018) and sign-in dies before it reaches the network. The legacy
    // file keychain works under the sandbox with plain Development signing.
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  Future<String?> readToken(String key) => _storage.read(key: key);
  Future<void> writeToken(String key, String value) => _storage.write(key: key, value: value);
  Future<void> deleteToken(String key) => _storage.delete(key: key);
  Future<void> clearAll() => _storage.deleteAll();
}
