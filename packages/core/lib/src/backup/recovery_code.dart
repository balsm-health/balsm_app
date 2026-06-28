import 'dart:math';

/// Generates and validates the user's backup **recovery code** — a Crockford
/// base32 string the user saves once and re-enters to restore on a new device.
///
/// 30 significant chars × 5 bits ≈ 150 bits of entropy. Grouped for legibility:
/// `J8H2-K4MN-...`. The code is the only secret that can decrypt the backup;
/// Balsm never sees it.
class RecoveryCode {
  RecoveryCode._();

  // Crockford base32 (no I, L, O, U to avoid ambiguity).
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const _groups = 6;
  static const _groupLen = 5;
  static final _rng = Random.secure();

  /// A fresh grouped recovery code, e.g. `J8H2K-4MNP9-...`.
  static String generate() {
    final buf = StringBuffer();
    for (var g = 0; g < _groups; g++) {
      if (g > 0) buf.write('-');
      for (var c = 0; c < _groupLen; c++) {
        buf.write(_alphabet[_rng.nextInt(_alphabet.length)]);
      }
    }
    return buf.toString();
  }

  /// Strips separators/whitespace and upper-cases for use as key material.
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

  /// True when [input] has the right length and only valid characters.
  static bool isValid(String input) {
    final n = normalize(input);
    if (n.length != _groups * _groupLen) return false;
    return n.split('').every(_alphabet.contains);
  }
}
