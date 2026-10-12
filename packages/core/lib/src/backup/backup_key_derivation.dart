import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Derives the 32-byte backup encryption key from a user recovery secret and a
/// per-backup [salt]. Zero-knowledge: the recovery secret is never persisted or
/// transmitted, and the salt is stored in the blob header (non-secret) so the
/// same key can be re-derived on a new device at restore time.
///
/// Argon2id (memory-hard) makes brute-forcing a weak recovery secret expensive.
Future<Uint8List> deriveKey(String recoverySecret, List<int> salt) async {
  final algorithm = Argon2id(
    memory: 65536,
    parallelism: 1,
    iterations: 3,
    hashLength: 32,
  );
  final result = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(recoverySecret)),
    nonce: salt,
  );
  return Uint8List.fromList(await result.extractBytes());
}
