import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/medication.dart';
import '../../domain/entities/dose_event.dart';
import '../../domain/events/dose_missed.dart';
import '../../domain/value_objects/ids.dart';
import '../../application/ports/medications_data_source.dart';
import 'drift_medications_data_source.dart';

/// Grace window after a scheduled time before a dose counts as missed.
const Duration kMissedGrace = Duration(minutes: 30);

/// Detects scheduled doses that were never acted on and records them as missed.
///
/// Runs on app foreground. Missed events are APPEND-ONLY inserts and a
/// [DoseMissed] event is dispatched per detection.
///
/// T035bk: when notification permission is denied (no OS reminders fired), this
/// must run on EVERY foreground — not just the first foreground of the day —
/// because the in-app today list is the only safety net.
class MissedDoseDetector {
  MissedDoseDetector({
    required this.dao,
    required this.bus,
    required NotificationPermissionState Function() readPermission,
  }) : _readPermission = readPermission;

  final MedicationsDataSource dao;
  final EventBus bus;
  final NotificationPermissionState Function() _readPermission;

  DateTime? _lastRunDay;

  bool get _permissionDenied => _readPermission() == NotificationPermissionState.denied;

  /// Returns true if detection should run this foreground.
  ///
  /// - permission denied: always run (T035bk).
  /// - otherwise: once per calendar day (first foreground of the day).
  bool shouldRun(DateTime now) {
    if (_permissionDenied) return true;
    final today = DateTime(now.year, now.month, now.day);
    return _lastRunDay == null || _lastRunDay != today;
  }

  /// Finds scheduled doses older than now-[kMissedGrace] that have no recorded
  /// event, appends a `missed` event for each, and dispatches [DoseMissed].
  ///
  /// Returns the newly recorded missed events.
  Future<List<DoseEvent>> detectMissed(UserId userId) async {
    final now = DateTime.now();
    if (!shouldRun(now)) return const [];
    _lastRunDay = DateTime(now.year, now.month, now.day);

    final cutoff = now.subtract(kMissedGrace);
    // Look back over the schedule horizon for un-acted scheduled doses.
    final lookbackStart = now.subtract(const Duration(days: 7));

    final meds = await dao.findAll();
    final newlyMissed = <DoseEvent>[];

    for (final med in meds) {
      final existing = await dao.getDoseEvents(
        med.id,
        from: lookbackStart,
        to: now,
      );
      final recordedScheduledAt = existing.map((e) => e.scheduledAt.toIso8601String()).toSet();

      for (final scheduled in _expectedOccurrences(med, lookbackStart, cutoff)) {
        if (recordedScheduledAt.contains(scheduled.toIso8601String())) continue;

        final missed = DoseEvent(
          id: DoseEventId.uuid(),
          medicationId: med.id,
          scheduledAt: scheduled,
          recordedAt: now,
          outcome: DoseOutcome.missed,
        );
        // APPEND-ONLY insert.
        await dao.insertDoseEvent(missed);
        bus.publish(DoseMissed(
          doseEventId: missed.id,
          medicationId: med.id,
          scheduledAt: scheduled,
          recordedAt: now,
        ));
        newlyMissed.add(missed);
      }
    }
    return newlyMissed;
  }

  // --- Occurrence expansion (mirrors MedicationScheduler) ------------------

  Iterable<DateTime> _expectedOccurrences(
    Medication med,
    DateTime from,
    DateTime to,
  ) sync* {
    if (med.startDate.isAfter(to)) return;
    final cfg = med.scheduleConfig;
    final effectiveStart = med.startDate.isAfter(from) ? med.startDate : from;
    final effectiveEnd = (med.endDate != null && med.endDate!.isBefore(to)) ? med.endDate! : to;

    for (var day = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
        !day.isAfter(effectiveEnd);
        day = day.add(const Duration(days: 1))) {
      if (!_dayMatches(med.scheduleType, cfg, day)) continue;
      for (final hhmm in cfg.times) {
        final at = _combine(day, hhmm);
        if (at.isBefore(from) || at.isAfter(to)) continue;
        yield at;
      }
    }
  }

  bool _dayMatches(ScheduleType type, ScheduleConfig cfg, DateTime day) {
    switch (type) {
      case ScheduleType.daily:
        return true;
      case ScheduleType.weekly:
      case ScheduleType.custom:
        final days = cfg.days;
        if (days == null || days.isEmpty) return false;
        return days.contains(day.weekday);
    }
  }

  DateTime _combine(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}

final missedDoseDetectorProvider = Provider<MissedDoseDetector>((ref) {
  return MissedDoseDetector(
    dao: ref.watch(medicationsDataSourceProvider),
    bus: ref.watch(eventBusProvider),
    readPermission: () => ref.read(notificationPermissionStateProvider),
  );
});
