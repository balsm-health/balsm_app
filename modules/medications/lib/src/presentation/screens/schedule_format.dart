import '../../domain/aggregates/medication.dart';

const _weekdayShort = {
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

/// Human-readable schedule summary, e.g. "Daily · 08:00, 20:00" or
/// "Mon, Wed, Fri · 09:00".
String formatSchedule(ScheduleType type, ScheduleConfig cfg) {
  final times = cfg.times.join(', ');
  switch (type) {
    case ScheduleType.daily:
      return 'Daily · $times';
    case ScheduleType.weekly:
    case ScheduleType.custom:
      final days = (cfg.days ?? const <int>[]).map((d) => _weekdayShort[d] ?? '?').join(', ');
      final label = days.isEmpty ? (type == ScheduleType.weekly ? 'Weekly' : 'Custom') : days;
      return '$label · $times';
  }
}
