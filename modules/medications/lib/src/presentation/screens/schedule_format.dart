import '../../domain/aggregates/medication.dart';
import '../i18n/i18n.dart';

/// Human-readable schedule summary, e.g. "Daily · 08:00, 20:00" or
/// "Mon, Wed, Fri · 09:00".
String formatSchedule(Messages m, ScheduleType type, ScheduleConfig cfg) {
  final times = cfg.times.join(', ');
  final weekdays = m.weekdaysShort.split('|'); // ISO 1 (Monday) .. 7 (Sunday)
  switch (type) {
    case ScheduleType.daily:
      return m.scheduleDailyAt(times);
    case ScheduleType.weekly:
    case ScheduleType.custom:
      final days = (cfg.days ?? const <int>[]).map((d) => d >= 1 && d <= 7 ? weekdays[d - 1] : '?').join(', ');
      final label = days.isEmpty ? (type == ScheduleType.weekly ? m.scheduleWeekly : m.scheduleCustom) : days;
      return '$label · $times';
    case ScheduleType.once:
      return m.scheduleOnceAt(times);
    case ScheduleType.everyHours:
      return m.scheduleEveryHours(cfg.interval ?? 1, times);
    case ScheduleType.everyDays:
      return m.scheduleEveryDays(cfg.interval ?? 1, times);
  }
}
