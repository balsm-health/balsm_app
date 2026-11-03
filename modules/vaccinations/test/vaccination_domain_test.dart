import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaccinations/vaccinations.dart';

/// VaccinationRecord rules and VaccinationStatus. Synthetic vaccine names.
void main() {
  final now = DateTime(2026, 11, 3, 15, 30);

  VaccinationRecord dose(String vaccine, int n, DateTime on, {DateTime? next, DateTime? created}) => VaccinationRecord(
        id: VaccinationRecordId.value('v-$vaccine-$n-${on.millisecondsSinceEpoch}'),
        vaccine: vaccine,
        doseNumber: n,
        administeredOn: DateTime.utc(on.year, on.month, on.day),
        nextDueOn: next == null ? null : DateTime.utc(next.year, next.month, next.day),
        createdAt: created ?? DateTime.utc(2026),
      );

  group('VaccinationRecord.record', () {
    test('trims, keeps calendar days and drops a blank clinic', () {
      final r = VaccinationRecord.record(
        vaccine: '  Test Vaccine A ',
        doseNumber: 2,
        administeredOn: DateTime(2026, 11, 3, 23, 59),
        nextDueOn: DateTime(2027, 1, 3, 8),
        clinic: '   ',
        now: now,
      );
      expect(r.isSuccess, isTrue);
      expect(r.value.vaccine, 'Test Vaccine A');
      expect(r.value.administeredOn, DateTime.utc(2026, 11, 3), reason: 'given today is allowed');
      expect(r.value.nextDueOn, DateTime.utc(2027, 1, 3));
      expect(r.value.clinic, isNull);
    });

    test('reports every broken rule at once', () {
      expect(
        VaccinationRecord.violationsOf(
          vaccine: ' ',
          doseNumber: 0,
          administeredOn: DateTime(2026, 11, 4),
          clinic: 'x' * (VaccinationRecord.maxClinicLength + 1),
          nextDueOn: DateTime(2026, 11, 4),
          now: now,
        ),
        [
          VaccinationViolation.vaccineRequired,
          VaccinationViolation.doseNumberInvalid,
          VaccinationViolation.administeredInFuture,
          VaccinationViolation.clinicTooLong,
          VaccinationViolation.nextDueNotAfterAdministered,
        ],
      );
      expect(
        VaccinationRecord.violationsOf(vaccine: 'x' * 81, doseNumber: 1, administeredOn: null, now: now),
        [VaccinationViolation.vaccineTooLong, VaccinationViolation.administeredOnRequired],
      );
    });

    test('a failure names the broken rules', () {
      final r = VaccinationRecord.record(vaccine: '', doseNumber: 1, administeredOn: null, now: now);
      expect(r.error, isA<ValidationFailure>());
      expect(r.error.message, 'vaccineRequired,administeredOnRequired');
    });

    test('next due must come after the day given', () {
      final on = DateTime(2026, 10, 1);
      expect(
        VaccinationRecord.violationsOf(vaccine: 'A', doseNumber: 1, administeredOn: on, nextDueOn: on, now: now),
        [VaccinationViolation.nextDueNotAfterAdministered],
      );
      expect(
        VaccinationRecord.violationsOf(
            vaccine: 'A', doseNumber: 1, administeredOn: on, nextDueOn: DateTime(2026, 10, 2), now: now),
        isEmpty,
      );
    });
  });

  group('VaccinationStatus', () {
    final today = DateTime(2026, 11, 3, 9);

    test('only the latest dose of each vaccine counts, whatever the case or spacing', () {
      final st = VaccinationStatus.of([
        dose('Test Vaccine A', 1, DateTime(2026, 5, 1), next: DateTime(2026, 7, 1)),
        dose('test  vaccine a', 2, DateTime(2026, 7, 2), next: DateTime(2026, 12, 1)),
      ], today: today);
      expect(st.pastDue, isEmpty, reason: 'dose 1 was followed by dose 2');
      expect(st.upcoming.single.doseNumber, 2);
      expect(st.next!.nextDueOn, DateTime.utc(2026, 12, 1));
    });

    test('splits upcoming (soonest first) from past due; due today is past due', () {
      final st = VaccinationStatus.of([
        dose('Test B', 1, DateTime(2026, 1, 1), next: DateTime(2027, 2, 1)),
        dose('Test C', 1, DateTime(2026, 1, 1), next: DateTime(2026, 12, 1)),
        dose('Test D', 1, DateTime(2026, 1, 1), next: DateTime(2026, 11, 3)),
        dose('Test E', 1, DateTime(2026, 1, 1), next: DateTime(2026, 6, 1)),
        dose('Test F', 1, DateTime(2026, 1, 1)),
      ], today: today);
      expect([for (final r in st.upcoming) r.vaccine], ['Test C', 'Test B']);
      expect([for (final r in st.pastDue) r.vaccine], ['Test E', 'Test D']);
    });

    test('on the same day the higher dose, then the later entry, is the latest', () {
      final day = DateTime(2026, 9, 1);
      final st = VaccinationStatus.of([
        dose('Test G', 3, day, next: DateTime(2027, 3, 1)),
        dose('Test G', 2, day, next: DateTime(2026, 10, 1)),
      ], today: today);
      expect(st.upcoming.single.doseNumber, 3);
      expect(st.pastDue, isEmpty);

      final tie = VaccinationStatus.of([
        dose('Test H', 1, day, next: DateTime(2027, 1, 1), created: DateTime.utc(2026, 9, 2)),
        dose('Test H', 1, day, next: DateTime(2026, 10, 1), created: DateTime.utc(2026, 9, 1)),
      ], today: today);
      expect(tie.upcoming.single.nextDueOn, DateTime.utc(2027, 1, 1));
    });

    test('nothing recorded: nothing due', () {
      final st = VaccinationStatus.of(const [], today: today);
      expect(st.next, isNull);
      expect(st.pastDue, isEmpty);
    });

    test('daysBetween counts calendar days', () {
      expect(VaccinationStatus.daysBetween(DateTime(2026, 11, 3, 23), DateTime(2026, 11, 4, 1)), 1);
      expect(VaccinationStatus.daysBetween(DateTime(2026, 11, 3), DateTime(2026, 10, 30)), -4);
    });
  });
}
