import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/aggregates/medication.dart';
import 'medications_data_source.dart';

/// Generic reminder copy. Per FR-018 the notification body MUST never contain a
/// drug name (PHI). Title is always "Balsm".
const String kMedNotificationTitle = 'Balsm';
const String kMedNotificationBody = 'Time to check your medications';

/// How many days of OS notification triggers to keep scheduled ahead.
const int kScheduleHorizonDays = 30;

/// Schedules per-medication OS notification triggers.
///
/// A daily 03:00 heartbeat rebuilds the next [kScheduleHorizonDays] of triggers.
///
/// Permission-aware (T035bj): when notification permission is denied we skip OS
/// scheduling entirely and rely on the in-app `meds.today` fallback. On a
/// denied -> granted transition, [rescheduleOnPermissionGranted] rebuilds the
/// triggers.
class MedicationScheduler {
  MedicationScheduler({
    required this.notifications,
    required this.dao,
    required this.userId,
    required NotificationPermissionState Function() readPermission,
  }) : _readPermission = readPermission;

  final NotificationService notifications;
  final DriftMedicationsDataSource dao;
  final UserId userId;
  final NotificationPermissionState Function() _readPermission;

  bool get _permissionGranted =>
      _readPermission() == NotificationPermissionState.granted ||
      _readPermission() == NotificationPermissionState.provisional;

  /// Daily 03:00 heartbeat entrypoint: rebuild all OS triggers for the horizon.
  ///
  /// No-op when permission is denied (FR-017 fallback to in-app today list).
  Future<void> dailyHeartbeat() async {
    if (!_permissionGranted) return;
    await rebuildSchedule();
  }

  /// Cancels existing triggers and reschedules the next [kScheduleHorizonDays].
  Future<void> rebuildSchedule() async {
    if (!_permissionGranted) return;
    await notifications.cancelAll();

    final meds = await dao.findAll();
    final now = DateTime.now();
    final horizonEnd = now.add(const Duration(days: kScheduleHorizonDays));

    for (final med in meds) {
      if (med.isExpired()) continue;
      for (final when in _occurrences(med, now, horizonEnd)) {
        await notifications.zonedSchedule(
          id: _notificationId(med, when),
          title: kMedNotificationTitle,
          // FR-018: generic body only — NEVER the drug name.
          body: kMedNotificationBody,
          dateTime: tz.TZDateTime.from(when, tz.local),
        );
      }
    }
  }

  /// Called on a denied -> granted permission transition (T035bj).
  Future<void> rescheduleOnPermissionGranted() => rebuildSchedule();

  /// FR-023: detect a device timezone shift and rebuild triggers so reminders
  /// fire at the intended local clock time after travel / DST changes.
  Future<void> handleTimezoneShift(String previousTimezoneName) async {
    if (previousTimezoneName == tz.local.name) return;
    await rebuildSchedule();
  }

  // --- Occurrence expansion ------------------------------------------------

  Iterable<DateTime> _occurrences(
    Medication med,
    DateTime from,
    DateTime to,
  ) sync* {
    final cfg = med.scheduleConfig;
    final effectiveStart =
        med.startDate.isAfter(from) ? med.startDate : from;
    final effectiveEnd =
        (med.endDate != null && med.endDate!.isBefore(to)) ? med.endDate! : to;

    for (var day = DateTime(effectiveStart.year, effectiveStart.month,
            effectiveStart.day);
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
        return days.contains(day.weekday); // 1=Mon..7=Sun
    }
  }

  DateTime _combine(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  /// Stable, collision-resistant 31-bit notification id from medication id +
  /// occurrence time.
  int _notificationId(Medication med, DateTime when) {
    final h = Object.hash(med.id.toString(), when.toIso8601String());
    return h & 0x7FFFFFFF;
  }
}

/// Provider factory — caller supplies the active [userId].
final medicationSchedulerProvider =
    Provider.family<MedicationScheduler, UserId>((ref, userId) {
  return MedicationScheduler(
    notifications: ref.watch(notificationServiceProvider),
    dao: ref.watch(medicationsDataSourceProvider),
    userId: userId,
    readPermission: () => ref.read(notificationPermissionStateProvider),
  );
});
