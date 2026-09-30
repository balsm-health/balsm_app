import 'dart:math';

import 'package:core/src/db/db_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is 64 lowercase hex chars', () {
    expect(generateDbKeyHex(), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('is not a repeated byte (regression: microsecond-filled key)', () {
    final key = generateDbKeyHex();
    final bytes = {for (var i = 0; i < 64; i += 2) key.substring(i, i + 2)};
    expect(bytes.length, greaterThan(8));
  });

  test('two keys differ', () {
    expect(generateDbKeyHex(), isNot(generateDbKeyHex()));
  });

  test('uses the given source', () {
    expect(generateDbKeyHex(Random(1)), generateDbKeyHex(Random(1)));
  });
}
