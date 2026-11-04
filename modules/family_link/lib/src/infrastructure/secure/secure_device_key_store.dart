import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';

import '../../application/ports/device_key_store.dart';

/// [DeviceKeyStore] over the platform secure store ([SecureStorageWrapper]),
/// one key pair per account on this phone. A lost or cleared store simply
/// mints a new pair: links then carry a new public key, and the other side's
/// phone re-seals for it on its next pull.
class SecureDeviceKeyStore implements DeviceKeyStore {
  SecureDeviceKeyStore({required SecureStorageWrapper storage, required String accountId, X25519? x25519})
      : _storage = storage,
        _key = 'balsm.family_link.device_key.$accountId',
        _x25519 = x25519 ?? X25519();

  final SecureStorageWrapper _storage;
  final String _key;
  final X25519 _x25519;
  DeviceKeyPair? _cached;

  @override
  Future<DeviceKeyPair> ensure() async {
    final cached = _cached;
    if (cached != null) return cached;
    final stored = await _read();
    if (stored != null) return _cached = stored;
    final pair = await _x25519.newKeyPair();
    final private = Uint8List.fromList(await pair.extractPrivateKeyBytes());
    final public = Uint8List.fromList((await pair.extractPublicKey()).bytes);
    await _storage.writeToken(_key, jsonEncode({'sk': base64.encode(private), 'pk': base64.encode(public)}));
    return _cached = DeviceKeyPair(privateKey: private, publicKey: public);
  }

  Future<DeviceKeyPair?> _read() async {
    final raw = await _storage.readToken(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final private = base64.decode(json['sk'] as String);
      final public = base64.decode(json['pk'] as String);
      if (private.length != 32 || public.length != 32) return null;
      return DeviceKeyPair(privateKey: private, publicKey: public);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
