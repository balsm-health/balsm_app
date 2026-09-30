import '../aggregates/medication.dart';

/// When [med] is due on the calendar day that starts at [dayStart], in order.
///
/// This is the patient's "to take" list: there are no notifications, so a dose
/// exists only because this function says so. The same slots back adherence,
/// so a slot's [DateTime] must come out identical every time it is computed —
/// dose events are matched to it by value.
Iterable<DateTime> dosesOn(Medication med, DateTime dayStart) sync* {
  final day = DateTime(dayStart.year, dayStart.month, dayStart.day);
  final next = DateTime(day.year, day.month, day.day + 1);
  if (!med.startDate.isBefore(next)) return;
  if (med.endDate != null && !med.endDate!.isAfter(day)) return;

  final cfg = med.scheduleConfig;
  final startDay = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);

  final Iterable<DateTime> slots;
  switch (med.scheduleType) {
    case ScheduleType.daily:
      slots = _at(day, cfg.times);
    case ScheduleType.weekly || ScheduleType.custom:
      slots = (cfg.days ?? const <int>[]).contains(day.weekday) ? _at(day, cfg.times) : const [];
    case ScheduleType.once:
      slots = day == startDay ? _at(day, cfg.times) : const [];
    case ScheduleType.everyDays:
      final n = _positive(cfg.interval);
      final since = _daysBetween(startDay, day);
      slots = since >= 0 && since % n == 0 ? _at(day, cfg.times) : const [];
    case ScheduleType.everyHours:
      slots = _everyHours(startDay, cfg, day, next);
  }

  for (final at in slots) {
    // Schedules made before today's rules began at the moment of adding, not
    // at midnight; their earlier slots that day never existed.
    if (at.isBefore(med.startDate)) continue;
    if (med.endDate != null && !at.isBefore(med.endDate!)) continue;
    yield at;
  }
}

/// Default dose times for [perDay] doses a day: spread from 08:00 to 20:00
/// (22:00 past three doses), on quarter hours. The patient can change them.
List<String> suggestedTimes(int perDay) {
  final n = perDay.clamp(1, 12);
  if (n == 1) return const ['08:00'];
  const first = 8 * 60;
  final last = (n <= 3 ? 20 : 22) * 60;
  final step = ((last - first) / (n - 1)) ~/ 15 * 15;
  return [for (var i = 0; i < n; i++) _hhmm(first + i * step)];
}

/// End of a set period that starts on [start]: [count] days, weeks or months
/// later, at midnight. Exclusive — the last dose is the day before.
DateTime periodEnd(DateTime start, int count, PeriodUnit unit) {
  final d = DateTime(start.year, start.month, start.day);
  return switch (unit) {
    PeriodUnit.days => DateTime(d.year, d.month, d.day + count),
    PeriodUnit.weeks => DateTime(d.year, d.month, d.day + 7 * count),
    PeriodUnit.months => DateTime(d.year, d.month + count, d.day),
  };
}

enum PeriodUnit { days, weeks, months }

Iterable<DateTime> _everyHours(DateTime startDay, ScheduleConfig cfg, DateTime day, DateTime next) sync* {
  final n = _positive(cfg.interval);
  final anchor = _at(startDay, cfg.times.take(1)).firstOrNull;
  if (anchor == null) return;
  // Whole hours since the anchor, measured on the wall clock so a DST change
  // doesn't shift every later dose by an hour.
  var k = 0;
  final hoursToDay = _daysBetween(startDay, day) * 24 - (anchor.hour * 60 + anchor.minute) / 60;
  if (hoursToDay > 0) k = (hoursToDay / n).ceil();
  while (true) {
    final total = anchor.hour * 60 + anchor.minute + k * n * 60;
    final at = DateTime(startDay.year, startDay.month, startDay.day, 0, total);
    if (!at.isBefore(next)) return;
    if (!at.isBefore(day)) yield at;
    k++;
  }
}

Iterable<DateTime> _at(DateTime day, Iterable<String> times) sync* {
  final sorted = [...times]..sort();
  for (final hhmm in sorted) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    yield DateTime(day.year, day.month, day.day, hour, minute);
  }
}

int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int _positive(int? n) => n == null || n < 1 ? 1 : n;

String _hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
