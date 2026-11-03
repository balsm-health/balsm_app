import '../aggregates/vaccination_record.dart';

/// Where a person's vaccinations stand on a given day (design
/// `mcVaccStatus`): for each vaccine only its latest dose counts, and when
/// that dose names a next due day the next dose is either still [upcoming]
/// or already [pastDue] (due today counts as past due, as in the design).
///
/// The day is passed in — the domain never reads the clock.
class VaccinationStatus {
  const VaccinationStatus._(this.upcoming, this.pastDue);

  /// Doses still to come, soonest first. Each entry is the latest recorded
  /// dose of its vaccine; the dose due is `doseNumber + 1`.
  final List<VaccinationRecord> upcoming;

  /// Doses whose due day has come without a later dose recorded, longest
  /// overdue first.
  final List<VaccinationRecord> pastDue;

  /// The next dose due, if any.
  VaccinationRecord? get next => upcoming.isEmpty ? null : upcoming.first;

  factory VaccinationStatus.of(Iterable<VaccinationRecord> records, {required DateTime today}) {
    final latest = <String, VaccinationRecord>{};
    for (final r in records) {
      final seen = latest[r.vaccineKey];
      if (seen == null || _isLater(r, seen)) latest[r.vaccineKey] = r;
    }
    final day = DateTime.utc(today.year, today.month, today.day);
    final due = latest.values.where((r) => r.nextDueOn != null).toList()
      ..sort((a, b) => a.nextDueOn!.compareTo(b.nextDueOn!));
    return VaccinationStatus._(
      List.unmodifiable(due.where((r) => r.nextDueOn!.isAfter(day))),
      List.unmodifiable(due.where((r) => !r.nextDueOn!.isAfter(day))),
    );
  }

  /// Whole days from [from] to [to] (negative when [to] is earlier).
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  /// Later given wins; on the same day the higher dose, then the later entry.
  static bool _isLater(VaccinationRecord a, VaccinationRecord b) {
    final byDay = a.administeredOn.compareTo(b.administeredOn);
    if (byDay != 0) return byDay > 0;
    if (a.doseNumber != b.doseNumber) return a.doseNumber > b.doseNumber;
    return a.createdAt.isAfter(b.createdAt);
  }
}
