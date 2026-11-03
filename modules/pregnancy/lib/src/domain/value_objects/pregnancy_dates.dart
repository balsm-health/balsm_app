/// Calendar-day arithmetic for a pregnancy. Dates are calendar days: the
/// time of day is ignored and the math runs in UTC so a daylight-saving
/// change never shifts a day.
abstract final class PregnancyDates {
  /// Length of a pregnancy counted from the first day of the last period.
  static const termDays = 280;

  /// [d]'s calendar day (UTC midnight).
  static DateTime day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Whole calendar days from [from] to [to] (negative when [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) => day(to).difference(day(from)).inDays;

  /// The estimated due date for a last period that began on [lastPeriod]
  /// (design start screen, "I know my last period").
  static DateTime dueFromLastPeriod(DateTime lastPeriod) => day(lastPeriod).add(const Duration(days: termDays));
}

/// Where a pregnancy stands on a given day (design `mcPregInfo`): week and
/// day of gestation, trimester, and days left to the due date.
class PregnancyInfo {
  const PregnancyInfo({required this.daysLeft, required this.week, required this.day, required this.trimester});

  /// [dueDate] as seen on [today].
  factory PregnancyInfo.on(DateTime dueDate, DateTime today) {
    final left = PregnancyDates.daysBetween(today, dueDate);
    final gestation = PregnancyDates.termDays - left;
    final ga = gestation < 0 ? 0 : gestation;
    final week = ga ~/ 7;
    return PregnancyInfo(
      daysLeft: left,
      week: week,
      day: ga % 7,
      trimester: week < 14
          ? 1
          : week < 28
              ? 2
              : 3,
    );
  }

  /// Days to the due date; negative once it has passed.
  final int daysLeft;

  /// Completed weeks of gestation.
  final int week;

  /// Days into the current week (0–6).
  final int day;

  /// 1, 2 or 3.
  final int trimester;

  /// The completed week of gestation on [date] (design `mcWeekAt`), never
  /// below zero.
  static int weekAt(DateTime dueDate, DateTime date) {
    final ga = PregnancyDates.termDays - PregnancyDates.daysBetween(date, dueDate);
    return ga < 0 ? 0 : ga ~/ 7;
  }
}
