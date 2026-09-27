import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageWrapper>(
  (_) => SecureStorageWrapper(),
);

/// The ONE secure-storage configuration for this app.
///
/// On Android the options pick the backend: `encryptedSharedPreferences: true`
/// stores into `FlutterSecureStorage.xml`, the default into the KeyStore-wrapped
/// `FlutterSecureKeyStorage.xml`. Two instances configured differently are two
/// separate stores, so a key written through one reads back null through the
/// other — which is why every construction site must use this const rather than
/// building its own.
const balsmSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // macOS: the iOS-style data-protection keychain demands a
    // keychain-access-groups entitlement backed by a provisioning profile;
    // without one every operation fails with errSecMissingEntitlement
    // (-34018) and sign-in dies before it reaches the network. The legacy
    // file keychain works under the sandbox with plain Development signing.
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
);

class SecureStorageWrapper {
  static const _storage = balsmSecureStorage;

  Future<String?> readToken(String key) => _storage.read(key: key);
  Future<void> writeToken(String key, String value) => _storage.write(key: key, value: value);
  Future<void> deleteToken(String key) => _storage.delete(key: key);
  Future<void> clearAll() => _storage.deleteAll();
}
