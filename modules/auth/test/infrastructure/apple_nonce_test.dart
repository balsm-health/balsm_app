import 'dart:math';

import 'package:auth/src/infrastructure/social/apple_credentials_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generateNonce_isUrlSafeAnd43Chars', () {
    final nonce = generateNonce();

    // 32 bytes, base64url, no padding.
    expect(nonce.length, 43);
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(nonce), isTrue);
  });

  test('generateNonce_twoCallsDiffer', () {
    expect(generateNonce(), isNot(generateNonce()));
  });

  test('generateNonce_usesTheGivenRandom', () {
    expect(generateNonce(Random(1)), generateNonce(Random(1)));
  });

  test('sha256Hex_knownVector', () {
    expect(sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}
