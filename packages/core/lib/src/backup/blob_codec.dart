import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'backup_key_derivation.dart';

/// Serializes and AES-256-GCM encrypts the on-device backup snapshot.
///
/// Blob layout (all single-byte lengths; values are small and fixed):
/// ```
/// magic "BLSM" (4) | version (1) | saltLen (1) | salt | nonceLen (1) | nonce
///                 | macLen (1) | mac | ciphertext…
/// ```
/// The salt is non-secret and travels with the blob so the key can be
/// re-derived from the user's recovery secret on any device.
class BackupCodec {
  BackupCodec._();

  static const _magic = [0x42, 0x4C, 0x53, 0x4D]; // "BLSM"
  static const _version = 1;
  static final _algo = AesGcm.with256bits();
  static final _rng = Random.secure();

  /// Generates a random 16-byte salt.
  static Uint8List newSalt() => Uint8List.fromList(List<int>.generate(16, (_) => _rng.nextInt(256)));

  /// Encrypts [data] under a key derived from [recoverySecret] + [salt].
  static Future<Uint8List> encrypt(
    Uint8List data,
    String recoverySecret, {
    required Uint8List salt,
  }) async {
    final key = await deriveKey(recoverySecret, salt);
    final box = await _algo.encrypt(data, secretKey: SecretKey(key));
    final out = BytesBuilder();
    out.add(_magic);
    out.addByte(_version);
    out.addByte(salt.length);
    out.add(salt);
    out.addByte(box.nonce.length);
    out.add(box.nonce);
    out.addByte(box.mac.bytes.length);
    out.add(box.mac.bytes);
    out.add(box.cipherText);
    return out.toBytes();
  }

  /// Decrypts a blob produced by [encrypt]. Throws [BackupDecryptException] if
  /// the recovery secret is wrong or the blob is corrupt/unsupported.
  static Future<Uint8List> decrypt(Uint8List blob, String recoverySecret) async {
    var i = 0;
    int byte() => blob[i++];
    Uint8List take(int n) {
      final s = blob.sublist(i, i + n);
      i += n;
      return s;
    }

    try {
      final magic = take(4);
      if (!_listEq(magic, _magic)) throw const BackupDecryptException('bad magic');
      if (byte() != _version) throw const BackupDecryptException('unsupported version');
      final salt = take(byte());
      final nonce = take(byte());
      final mac = take(byte());
      final cipher = blob.sublist(i);
      final key = await deriveKey(recoverySecret, salt);
      final clear = await _algo.decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
      );
      return Uint8List.fromList(clear);
    } on BackupDecryptException {
      rethrow;
    } catch (e) {
      // SecretBoxAuthenticationError (wrong key) or range errors (corrupt blob).
      throw BackupDecryptException(e.toString());
    }
  }

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class BackupDecryptException implements Exception {
  const BackupDecryptException(this.message);
  final String message;
  @override
  String toString() => 'BackupDecryptException: $message';
}
