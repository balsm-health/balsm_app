import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// `addFamilyMember` mirrors the design's age derivation: whole years since the
/// birth date, decremented when this year's birthday has not happened yet.
///
/// PHI note: the DOB here is session-only test input — [FamilyMemberPreview] is
/// never persisted, logged or transmitted.
void main() {
  FamilyMemberPreview member(DateTime? dob) => FamilyMemberPreview(
        id: 'fam_test',
        name: 'Test',
        relation: 'Sibling',
        color: T.petalAqua,
        dob: dob,
      );

  test('no birth date means no age', () {
    expect(member(null).age, isNull);
  });

  test('birthday already passed this year counts the full year', () {
    final now = DateTime.now();
    // 30 years ago, one day before today → birthday has happened.
    final dob = DateTime(now.year - 30, now.month, now.day).subtract(const Duration(days: 1));
    expect(member(dob).age, 30);
  });

  test('birthday still ahead this year subtracts one', () {
    final now = DateTime.now();
    // 30 years ago, one day after today → birthday has not happened yet.
    final dob = DateTime(now.year - 30, now.month, now.day).add(const Duration(days: 1));
    expect(member(dob).age, 29);
  });

  test('birthday exactly today counts the full year', () {
    final now = DateTime.now();
    expect(member(DateTime(now.year - 40, now.month, now.day)).age, 40);
  });

  test('a future birth date clamps to zero rather than going negative', () {
    expect(member(DateTime.now().add(const Duration(days: 400))).age, 0);
  });

  test('addFamilyMember carries the birth date through', () {
    final s = PatientAppState();
    final dob = DateTime(1990, 5, 20);
    s.addFamilyMember(name: 'Layla', relation: 'Daughter', dob: dob);
    expect(s.extraFamily.single.dob, dob);
    expect(s.extraFamily.single.age, isNotNull);
  });

  test('birth date is optional', () {
    final s = PatientAppState();
    s.addFamilyMember(name: 'Sam', relation: 'Sibling');
    expect(s.extraFamily.single.dob, isNull);
    expect(s.extraFamily.single.age, isNull);
  });
}
