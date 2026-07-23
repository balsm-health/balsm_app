import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/aggregates/medication.dart';
import '../domain/entities/dose_event.dart';
import '../domain/value_objects/ids.dart';
import '../infrastructure/drift/drift_medications_data_source.dart';

/// Reactive list of the active profile's medications. Uses core's
/// [currentProfileIdProvider] (self profile, ensured at session start).
final medicationListProvider = StreamProvider<List<Medication>>((ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) return Stream.value(const <Medication>[]);
  return ref
      .watch(medicationsDataSourceProvider)
      .watchAll(scope: profileId);
});

/// A scheduled dose for "today" plus its recorded outcome (if any).
class TodayDose {
  const TodayDose({
    required this.medication,
    required this.scheduledAt,
    this.event,
  });

  final Medication medication;
  final DateTime scheduledAt;

  /// The latest recorded event for this scheduled slot, or null if pending.
  final DoseEvent? event;

  /// Stable id used for highlight/scroll: medicationId@ISO8601(scheduledAt).
  String get slotId =>
      '${medication.id}@${scheduledAt.toIso8601String()}';

  bool get isPending => event == null;
}

/// Today's scheduled doses (across all active medications), sorted by time,
/// joined with the latest recorded outcome per slot.
final todayDosesProvider = FutureProvider<List<TodayDose>>((ref) async {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) return const <TodayDose>[];
  final dao = ref.watch(medicationsDataSourceProvider);
  final meds = await dao.findAll(scope: profileId);

  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final doses = <TodayDose>[];
  for (final med in meds) {
    if (med.isExpired()) continue;
    final events = await dao.getDoseEvents(med.id, from: dayStart, to: dayEnd);
    // Latest event per scheduledAt wins (corrections supersede originals).
    final latestBySlot = <String, DoseEvent>{};
    for (final e in events) {
      final key = e.scheduledAt.toIso8601String();
      final existing = latestBySlot[key];
      if (existing == null || e.recordedAt.isAfter(existing.recordedAt)) {
        latestBySlot[key] = e;
      }
    }

    for (final at in _todayOccurrences(med, dayStart, dayEnd)) {
      doses.add(TodayDose(
        medication: med,
        scheduledAt: at,
        event: latestBySlot[at.toIso8601String()],
      ));
    }
  }

  doses.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return doses;
});

/// Dose history for a single medication (most recent first).
final doseHistoryProvider =
    FutureProvider.family<List<DoseEvent>, MedicationId>((ref, medicationId) {
  return ref.watch(medicationsDataSourceProvider).getDoseEvents(medicationId);
});

Iterable<DateTime> _todayOccurrences(
  Medication med,
  DateTime dayStart,
  DateTime dayEnd,
) sync* {
  if (med.startDate.isAfter(dayEnd)) return;
  final cfg = med.scheduleConfig;
  final matchesDay = switch (med.scheduleType) {
    ScheduleType.daily => true,
    ScheduleType.weekly ||
    ScheduleType.custom =>
      (cfg.days ?? const <int>[]).contains(dayStart.weekday),
  };
  if (!matchesDay) return;

  for (final hhmm in cfg.times) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final at = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day,
      hour,
      minute,
    );
    if (med.startDate.isAfter(at)) continue;
    yield at;
  }
}
