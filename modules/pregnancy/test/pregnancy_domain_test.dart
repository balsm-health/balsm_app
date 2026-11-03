import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pregnancy/pregnancy.dart';

/// Pregnancy domain rules: the week math (`mcPregInfo`), settling and
/// ending, items and birth details. Synthetic data only; the clock is
/// passed in.
void main() {
  final today = DateTime(2026, 11, 3);
  const mother = HealthProfileId.value('hp-self');
  const preg = PregnancyId.value('preg-1');

  PregnancyBaby baby(String id, int seq, {BabyStatus status = BabyStatus.active, String? name}) =>
      PregnancyBaby(id: HealthProfileId.value(id), pregnancyId: preg, sequence: seq, status: status, name: name);

  Pregnancy started({DateTime? due}) =>
      Pregnancy.start(id: preg, motherId: mother, dueDate: due ?? DateTime(2027, 2, 21), now: today).value;

  group('PregnancyInfo', () {
    test('110 days before the due date is week 24 day 2, second trimester', () {
      final info = PregnancyInfo.on(today.add(const Duration(days: 110)), today);

      expect(info.daysLeft, 110);
      expect(info.week, 24);
      expect(info.day, 2);
      expect(info.trimester, 2);
    });

    test('trimester edges are weeks 14 and 28', () {
      PregnancyInfo atWeek(int w) => PregnancyInfo.on(today.add(Duration(days: 280 - w * 7)), today);

      expect(atWeek(13).trimester, 1);
      expect(atWeek(14).trimester, 2);
      expect(atWeek(27).trimester, 2);
      expect(atWeek(28).trimester, 3);
    });

    test('gestation never goes below zero and keeps counting past the due date', () {
      final early = PregnancyInfo.on(today.add(const Duration(days: 300)), today);
      final late = PregnancyInfo.on(today.subtract(const Duration(days: 3)), today);

      expect((early.week, early.day), (0, 0));
      expect(late.daysLeft, -3);
      expect((late.week, late.day), (40, 3));
    });

    test('ignores the time of day', () {
      final info = PregnancyInfo.on(DateTime(2027, 2, 21, 1), DateTime(2026, 11, 3, 23, 59));

      expect(info.daysLeft, 110);
    });

    test('weekAt and the due date from a last period', () {
      final due = DateTime.utc(2027, 2, 21);

      expect(PregnancyInfo.weekAt(due, DateTime(2026, 11, 3)), 24);
      expect(PregnancyInfo.weekAt(due, DateTime(2026, 1, 1)), 0);
      expect(PregnancyDates.dueFromLastPeriod(DateTime(2026, 5, 17)), DateTime.utc(2027, 2, 21));
    });
  });

  group('Pregnancy', () {
    test('starts active with a due date as a calendar day and trimmed text', () {
      final p = Pregnancy.start(
        id: preg,
        motherId: mother,
        dueDate: DateTime(2027, 2, 21, 14),
        now: today,
        obName: '  Test Doctor ',
        obPhone: ' ',
      ).value;

      expect(p.isActive, isTrue);
      expect(p.dueDate, DateTime.utc(2027, 2, 21));
      expect(p.obName, 'Test Doctor');
      expect(p.obPhone, isNull);
      expect(p.infoOn(today).week, 24);
    });

    test('refuses a due date more than a term ahead or long past', () {
      Pregnancy.start(id: preg, motherId: mother, dueDate: today.add(const Duration(days: 280)), now: today).value;
      final far =
          Pregnancy.start(id: preg, motherId: mother, dueDate: today.add(const Duration(days: 281)), now: today);
      final past =
          Pregnancy.start(id: preg, motherId: mother, dueDate: today.subtract(const Duration(days: 43)), now: today);

      expect(far.error.message, 'dueDateTooFar');
      expect(past.error.message, 'dueDatePassed');
    });

    test('settle keeps it open while a baby is still followed', () {
      final p = started();

      expect(identical(p.settle([baby('a', 1), baby('b', 2, status: BabyStatus.closed)], today), p), isTrue);
    });

    test('settle closes as birth once no baby is active and one was born', () {
      final p = started().settle(
          [baby('a', 1, status: BabyStatus.born), baby('b', 2, status: BabyStatus.closed)], DateTime(2027, 2, 20, 9));

      expect(p.status, PregnancyStatus.birth);
      expect(p.closedOn, DateTime.utc(2027, 2, 20));
    });

    test('settle closes as ended when every baby stopped being followed', () {
      final p = started().settle([baby('a', 1, status: BabyStatus.closed)], today);

      expect(p.status, PregnancyStatus.ended);
      expect(p.isActive, isFalse);
    });

    test('end closes it as ended once; a closed one no longer changes', () {
      final ended = started().end(today).value;

      expect(ended.status, PregnancyStatus.ended);
      expect(ended.closedOn, DateTime.utc(2026, 11, 3));
      expect(ended.end(today).error.message, 'closed');
      expect(ended.withNextVisit(null, now: today).error.message, 'closed');
      expect(identical(ended.settle(const [], today), ended), isTrue);
    });

    test('next visit is set, trimmed and cleared', () {
      final p = started()
          .withNextVisit(NextVisit(date: DateTime(2026, 11, 14, 8), time: '10:30', clinic: ' Test Clinic '), now: today)
          .value;

      expect(p.nextVisit!.date, DateTime.utc(2026, 11, 14));
      expect(p.nextVisit!.clinic, 'Test Clinic');
      expect(p.withNextVisit(null, now: today).value.nextVisit, isNull);
    });
  });

  group('BabyLabel', () {
    test('a name wins; one baby is "Baby"; several are lettered by sequence', () {
      final a = baby('a', 1), b = baby('b', 2), named = baby('c', 3, name: ' Test Name ');

      expect(BabyLabel.of(a, [a]), isA<OnlyBaby>());
      expect((BabyLabel.of(b, [b, a]) as LetteredBaby).index, 1);
      expect((BabyLabel.of(named, [a, b, named]) as NamedBaby).name, 'Test Name');
      expect(BabyLabel.of(baby('d', 1, name: ' '), [baby('d', 1, name: ' ')]), isA<OnlyBaby>());
    });

    test('there is no sex on a baby before birth', () {
      // The read model carries no sex at all; birth is where it is first asked.
      const details = BirthDetails(babyId: HealthProfileId.value('a'), name: 'Test Baby', sex: null, dateOfBirth: null);

      expect(details.violations(today), containsAll([BirthViolation.sexRequired, BirthViolation.birthDateRequired]));
    });
  });

  group('PregnancyItem', () {
    AppResult<PregnancyItem> item({
      ItemAbout about = ItemAbout.baby,
      List<String> babies = const ['a'],
      ItemKind kind = ItemKind.measure,
      String? title,
      int? hr,
      int? efw,
      String? otherLabel,
      String? otherValue,
      String? file,
      DateTime? on,
    }) =>
        PregnancyItem.create(
          id: const PregnancyItemId.value('i1'),
          pregnancyId: preg,
          about: about,
          babyIds: [for (final b in babies) HealthProfileId.value(b)],
          kind: kind,
          recordedOn: on ?? today,
          now: today,
          title: title,
          fetalHeartRateBpm: hr,
          estimatedFetalWeightG: efw,
          otherLabel: otherLabel,
          otherValue: otherValue,
          attachmentRef: file,
        );

    test('a measurement of one baby keeps its numbers as entered', () {
      final i = item(hr: 144, efw: 610).value;

      expect((i.fetalHeartRateBpm, i.estimatedFetalWeightG), (144, 610));
      expect(i.isAbout(const HealthProfileId.value('a')), isTrue);
      expect(i.isShared, isFalse);
    });

    test('measurements are for one baby at a time and need a value', () {
      expect(item(babies: ['a', 'b'], hr: 140).error.message, 'measureOneBaby');
      expect(item(about: ItemAbout.me, babies: [], hr: 140).error.message, 'measureOneBaby');
      expect(item().error.message, 'measurementRequired');
      expect(item(otherLabel: 'Test length').error.message, 'measurementRequired,otherIncomplete');
      expect(item(otherLabel: 'Test length', otherValue: '44 mm').isSuccess, isTrue);
    });

    test('a scan or document needs a title or a file; measurements are dropped', () {
      final shared = item(kind: ItemKind.scan, babies: ['a', 'b'], title: 'Test scan', hr: 150, file: 'vault/x').value;

      expect(shared.isShared, isTrue);
      expect(shared.fetalHeartRateBpm, isNull);
      expect(shared.attachmentRef, 'vault/x');
      expect(item(kind: ItemKind.doc, about: ItemAbout.me, babies: []).error.message, 'titleOrFileRequired');
      expect(item(kind: ItemKind.doc, about: ItemAbout.me, babies: [], file: 'vault/y').isSuccess, isTrue);
    });

    test('about a baby needs one; about me takes none; no future dates or slips', () {
      expect(item(kind: ItemKind.doc, babies: [], title: 'x').error.message, 'babyRequired');
      expect(item(kind: ItemKind.doc, about: ItemAbout.me, title: 'x').error.message, 'babiesOnMe');
      expect(item(hr: 140, on: DateTime(2026, 11, 4)).error.message, 'dateInFuture');
      expect(item(hr: 0, efw: 20000).error.message, 'heartRateOutOfRange,weightOutOfRange');
    });
  });

  group('BirthDetails', () {
    test('name, sex and a date of birth not in the future', () {
      BirthDetails d({String name = 'Test Baby', DateTime? dob}) => BirthDetails(
          babyId: const HealthProfileId.value('a'), name: name, sex: Sex.female, dateOfBirth: dob ?? today);

      expect(d().violations(today), isEmpty);
      expect(d().relationship, Relationship.child);
      expect(d(name: ' ').violations(today), [BirthViolation.nameRequired]);
      expect(d(dob: DateTime(2026, 11, 4)).violations(today), [BirthViolation.birthDateInFuture]);
    });
  });
}
