import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final gate = AgeGateUseCase();

  // Build a DOB whose birthday is *today*, [years] ago — exercises the
  // inclusive boundary in AgeGateUseCase without day/month overflow.
  DateTime birthdayTodayAged(int years) {
    final now = DateTime.now();
    return DateTime(now.year - years, now.month, now.day);
  }

  group('AgeGateUseCase', () {
    test('rejects a clearly under-age date of birth', () {
      final r = gate.validate(birthdayTodayAged(10));
      expect(r.isFailure, isTrue);
      expect(r.error, isA<AgeGateFailure>());
    });

    test('rejects someone who turns 18 later (17 today)', () {
      final r = gate.validate(birthdayTodayAged(17));
      expect(r.isFailure, isTrue);
      expect(r.error, isA<AgeGateFailure>());
    });

    test('accepts exactly 18 today (inclusive boundary)', () {
      final r = gate.validate(birthdayTodayAged(18));
      expect(r.isSuccess, isTrue);
    });

    test('accepts a clearly adult date of birth', () {
      final r = gate.validate(birthdayTodayAged(40));
      expect(r.isSuccess, isTrue);
    });
  });
}
