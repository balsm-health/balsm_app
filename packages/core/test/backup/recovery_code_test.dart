import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates valid, grouped, high-entropy codes', () {
    final code = RecoveryCode.generate();
    expect(code.contains('-'), isTrue);
    expect(RecoveryCode.isValid(code), isTrue);
    expect(RecoveryCode.normalize(code).length, 30);
  });

  test('normalize strips separators + upper-cases', () {
    expect(RecoveryCode.normalize('ab12-cd34 '), 'AB12CD34');
  });

  test('rejects ambiguous / short input', () {
    expect(RecoveryCode.isValid('SHORT'), isFalse);
    expect(RecoveryCode.isValid(RecoveryCode.normalize(RecoveryCode.generate())), isTrue);
  });

  test('codes are unique across generations', () {
    final set = {for (var i = 0; i < 50; i++) RecoveryCode.generate()};
    expect(set.length, 50);
  });
}
