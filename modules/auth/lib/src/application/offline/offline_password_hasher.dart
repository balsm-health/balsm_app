import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

abstract class OfflinePasswordHasher {
  Future<String> hash(String password);
  Future<bool> verify(String password, String encoded);
}

/// Argon2id, PHC-style string: `$argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>`.
/// Parameters are OWASP's minimum for Argon2id (19 MiB, 2 passes, 1 lane).
class Argon2idOfflinePasswordHasher implements OfflinePasswordHasher {
  static const _m = 19456, _t = 2, _p = 1, _len = 32;

  Argon2id get _algo => Argon2id(memory: _m, iterations: _t, parallelism: _p, hashLength: _len);

  @override
  Future<String> hash(String password) async {
    final r = Random.secure();
    final salt = List<int>.generate(16, (_) => r.nextInt(256));
    final key = await _algo.deriveKeyFromPassword(password: password, nonce: salt);
    final bytes = await key.extractBytes();
    String b64(List<int> v) => base64.encode(v).replaceAll('=', '');
    return '\$argon2id\$v=19\$m=$_m,t=$_t,p=$_p\$${b64(salt)}\$${b64(bytes)}';
  }

  @override
  Future<bool> verify(String password, String encoded) async {
    final parts = encoded.split(r'$');
    if (parts.length != 6 || parts[1] != 'argon2id') return false;
    List<int> unb64(String s) => base64.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));
    final salt = unb64(parts[4]);
    final expected = unb64(parts[5]);
    final key = await _algo.deriveKeyFromPassword(password: password, nonce: salt);
    final actual = await key.extractBytes();
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }
}
