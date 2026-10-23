import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medications/medications.dart';

/// The daily "to take" list. With no notifications, a dose the patient should
/// take exists only if `dosesOn` yields it — so every frequency the add-med
/// form offers is pinned here.
void main() {
  final monday = DateTime(2026, 10, 5); // a Monday

  Medication med(
    ScheduleType type,
    List<String> times, {
    int? interval,
    List<int>? days,
    DateTime? start,
    DateTime? end,
  }) =>
      Medication(
        id: MedicationId.uuid(),
        userId: UserId.value('u'),
        name: 'x',
        scheduleType: type,
        scheduleConfig: ScheduleConfig(times: times, days: days, interval: interval),
        startDate: start ?? monday,
        endDate: end,
      );

  List<String> on(Medication m, DateTime day) => [
        for (final at in dosesOn(m, day))
          '${at.day}/${at.month} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
      ];

  DateTime plus(int days) => DateTime(monday.year, monday.month, monday.day + days);

  group('times per day', () {
    test('every listed time, every day, in clock order', () {
      final m = med(ScheduleType.daily, ['20:00', '08:00', '14:00']);
      expect(on(m, monday), ['5/10 08:00', '5/10 14:00', '5/10 20:00']);
      expect(on(m, plus(30)), hasLength(3));
    });

    test('a med added mid-morning still lists that morning\'s dose — new meds start at midnight', () {
      expect(on(med(ScheduleType.daily, ['08:00']), monday), ['5/10 08:00']);
    });

    test('a med saved with a start time (older rows) skips slots before it that day', () {
      final m = med(ScheduleType.daily, ['08:00', '20:00'], start: DateTime(2026, 10, 5, 10, 30));
      expect(on(m, monday), ['5/10 20:00']);
      expect(on(m, plus(1)), ['6/10 08:00', '6/10 20:00']);
    });
  });

  group('one time', () {
    test('only on the day it was added', () {
      final m = med(ScheduleType.once, ['20:00']);
      expect(on(m, monday), ['5/10 20:00']);
      expect(on(m, plus(1)), isEmpty);
      expect(on(m, plus(-1)), isEmpty);
    });
  });

  group('every X hours', () {
    test('counted from the first dose, running across midnight', () {
      final m = med(ScheduleType.everyHours, ['08:00'], interval: 8);
      expect(on(m, monday), ['5/10 08:00', '5/10 16:00']);
      expect(on(m, plus(1)), ['6/10 00:00', '6/10 08:00', '6/10 16:00']);
    });

    test('an interval that does not divide 24 drifts through the day', () {
      final m = med(ScheduleType.everyHours, ['09:00'], interval: 10);
      expect(on(m, monday), ['5/10 09:00', '5/10 19:00']);
      expect(on(m, plus(1)), ['6/10 05:00', '6/10 15:00']);
      expect(on(m, plus(2)), ['7/10 01:00', '7/10 11:00', '7/10 21:00']);
    });

    test('nothing before the start day', () {
      expect(on(med(ScheduleType.everyHours, ['08:00'], interval: 6), plus(-1)), isEmpty);
    });
  });

  group('every X days', () {
    test('the start day, then every Nth day', () {
      final m = med(ScheduleType.everyDays, ['08:00'], interval: 3);
      expect(on(m, monday), ['5/10 08:00']);
      expect(on(m, plus(1)), isEmpty);
      expect(on(m, plus(2)), isEmpty);
      expect(on(m, plus(3)), ['8/10 08:00']);
      expect(on(m, plus(-3)), isEmpty);
    });

    test('stays on schedule across a month boundary', () {
      final m = med(ScheduleType.everyDays, ['08:00'], interval: 2, start: DateTime(2026, 10, 30));
      expect(on(m, DateTime(2026, 11, 1)), ['1/11 08:00']);
    });
  });

  group('duration', () {
    test('a set period ends at the start of its end day', () {
      final start = monday;
      final m = med(ScheduleType.daily, ['08:00'], end: periodEnd(start, 7, PeriodUnit.days));
      expect(on(m, plus(6)), ['11/10 08:00']);
      expect(on(m, plus(7)), isEmpty);
    });

    test('weeks and months', () {
      expect(periodEnd(monday, 2, PeriodUnit.weeks), DateTime(2026, 10, 19));
      expect(periodEnd(monday, 1, PeriodUnit.months), DateTime(2026, 11, 5));
      expect(periodEnd(DateTime(2026, 12, 20, 15), 1, PeriodUnit.months), DateTime(2027, 1, 20));
    });
  });

  test('weekly stays as it was', () {
    final m = med(ScheduleType.weekly, ['10:00'], days: [DateTime.monday]);
    expect(on(m, monday), ['5/10 10:00']);
    expect(on(m, plus(1)), isEmpty);
  });

  group('suggested times', () {
    test('spread through the waking day', () {
      expect(suggestedTimes(1), ['08:00']);
      expect(suggestedTimes(2), ['08:00', '20:00']);
      expect(suggestedTimes(3), ['08:00', '14:00', '20:00']);
      expect(suggestedTimes(4), ['08:00', '12:30', '17:00', '21:30']);
    });

    test('never past midnight, even at the form\'s maximum', () {
      final t = suggestedTimes(12);
      expect(t, hasLength(12));
      expect(t.last.compareTo('22:00') <= 0, isTrue, reason: t.last);
    });
  });

  test('the new schedule fields survive storage', () {
    const cfg = ScheduleConfig(
      times: ['08:00'],
      interval: 8,
      frequencyNote: 'as needed',
      durationKind: DurationKind.untilEmpty,
      durationNote: 'n',
    );
    expect(ScheduleConfig.fromJson(cfg.toJson()), cfg);
    // A row written before these fields existed still reads.
    expect(
        ScheduleConfig.fromJson({
          'times': ['09:00']
        }).durationKind,
        DurationKind.ongoing);
  });
}
