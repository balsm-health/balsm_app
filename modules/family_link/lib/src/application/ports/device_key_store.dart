import 'dart:typed_data';

/// This phone's X25519 key pair for family cards. The private half never
/// leaves the device; the public half goes to the server with a link request,
/// an approval, or a key change.
class DeviceKeyPair {
  const DeviceKeyPair({required this.privateKey, required this.publicKey});

  final Uint8List privateKey;
  final Uint8List publicKey;
}

/// Where the account's device key pair lives (the platform secure store).
abstract class DeviceKeyStore {
  /// The stored key pair, created and stored on first use.
  Future<DeviceKeyPair> ensure();
}
