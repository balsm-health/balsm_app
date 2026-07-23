import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/medication.dart';
import '../../domain/entities/dose_event.dart';
import '../../domain/value_objects/ids.dart';

// TODO: drift table annotations + build_runner.
// These tables are currently created/queried via raw SQL against AppDatabase.
// Once drift `@DataClassName` table classes are added to AppDatabase's
// `@DriftDatabase(tables: [...])` list and build_runner is run, replace the raw
// SQL below with generated, type-safe table accessors.
//
// Expected schema:
//   CREATE TABLE medications (
//     id TEXT PRIMARY KEY,
//     user_id TEXT NOT NULL,
//     name TEXT NOT NULL,
//     dose_amount TEXT,
//     schedule_type TEXT NOT NULL,
//     schedule_config TEXT NOT NULL,   -- JSON
//     start_date TEXT NOT NULL,        -- ISO-8601
//     end_date TEXT,                   -- ISO-8601, null = active
//     is_controlled INTEGER NOT NULL DEFAULT 0
//   );
//   CREATE TABLE dose_events (        -- APPEND-ONLY: never UPDATE/DELETE
//     id TEXT PRIMARY KEY,
//     medication_id TEXT NOT NULL,
//     scheduled_at TEXT NOT NULL,
//     recorded_at TEXT NOT NULL,
//     outcome TEXT NOT NULL,
//     parent_event_id TEXT,
//     snooze_until TEXT
//   );

const _kMedicationsTable = 'medications';
const _kDoseEventsTable = 'dose_events';

/// Data access for medications + their APPEND-ONLY dose history.
///
/// PHI lives on-device only. Dose events are inserted and read, never updated or
/// deleted — corrections are modelled as new events.
class MedicationDao {
  MedicationDao(this._db);

  final AppDatabase _db;

  // --- Medications ---------------------------------------------------------

  Future<List<Medication>> getMedications(UserId userId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM $_kMedicationsTable WHERE user_id = ? '
      'ORDER BY name COLLATE NOCASE ASC',
      variables: [Variable<String>(userId.value)],
    ).get();
    return rows.map((r) => _medicationFromRow(r.data)).toList();
  }

  /// Reactive stream of a user's medications.
  Stream<List<Medication>> watchMedications(UserId userId) {
    return _db.customSelect(
      'SELECT * FROM $_kMedicationsTable WHERE user_id = ? '
      'ORDER BY name COLLATE NOCASE ASC',
      variables: [Variable<String>(userId.value)],
      readsFrom: {/* TODO: medications table after build_runner */},
    ).watch().map((rows) => rows.map((r) => _medicationFromRow(r.data)).toList());
  }

  Future<void> addMedication(Medication m) async {
    // health_profile_id: dependants seam — anchor to the user's (self) profile
    // row when it exists; NULL otherwise (the app_database convergent backfill
    // fills it on a later open). Queries still filter on user_id until F1.
    await _db.customInsert(
      'INSERT INTO $_kMedicationsTable '
      '(id, user_id, health_profile_id, name, dose_amount, schedule_type, '
      'schedule_config, start_date, end_date, is_controlled) '
      'VALUES (?, ?, '
      '(SELECT id FROM health_profile WHERE user_id = ?), '
      '?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(m.id.value),
        Variable<String>(m.userId.value),
        Variable<String>(m.userId.value),
        Variable<String>(m.name),
        Variable<String>(m.doseAmount),
        Variable<String>(m.scheduleType.name),
        Variable<String>(jsonEncode(m.scheduleConfig.toJson())),
        Variable<String>(m.startDate.toIso8601String()),
        Variable<String>(m.endDate?.toIso8601String()),
        Variable<int>(m.isControlled ? 1 : 0),
      ],
    );
  }

  Future<void> updateMedication(Medication m) async {
    await _db.customUpdate(
      'UPDATE $_kMedicationsTable SET '
      'name = ?, dose_amount = ?, schedule_type = ?, schedule_config = ?, '
      'start_date = ?, end_date = ?, is_controlled = ? '
      'WHERE id = ?',
      variables: [
        Variable<String>(m.name),
        Variable<String>(m.doseAmount),
        Variable<String>(m.scheduleType.name),
        Variable<String>(jsonEncode(m.scheduleConfig.toJson())),
        Variable<String>(m.startDate.toIso8601String()),
        Variable<String>(m.endDate?.toIso8601String()),
        Variable<int>(m.isControlled ? 1 : 0),
        Variable<String>(m.id.value),
      ],
      updateKind: UpdateKind.update,
    );
  }

  /// Soft delete: sets `end_date` to yesterday so the medication is treated as
  /// expired while its (append-only) dose history is preserved.
  Future<void> deleteMedication(MedicationId id) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await _db.customUpdate(
      'UPDATE $_kMedicationsTable SET end_date = ? WHERE id = ?',
      variables: [
        Variable<String>(yesterday.toIso8601String()),
        Variable<String>(id.value),
      ],
      updateKind: UpdateKind.update,
    );
  }

  // --- Dose events (APPEND-ONLY) ------------------------------------------

  /// Appends a dose event. Never updates or deletes existing rows.
  Future<void> insertDoseEvent(DoseEvent e) async {
    await _db.customInsert(
      'INSERT INTO $_kDoseEventsTable '
      '(id, medication_id, scheduled_at, recorded_at, outcome, '
      'parent_event_id, snooze_until) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(e.id.value),
        Variable<String>(e.medicationId.value),
        Variable<String>(e.scheduledAt.toIso8601String()),
        Variable<String>(e.recordedAt.toIso8601String()),
        Variable<String>(e.outcome.name),
        Variable<String>(e.parentEventId?.value),
        Variable<String>(e.snoozeUntil?.toIso8601String()),
      ],
    );
  }

  /// Dose events for a medication, optionally bounded by [from]/[to]
  /// (inclusive of [from], exclusive of [to]) on `scheduled_at`.
  Future<List<DoseEvent>> getDoseEvents(
    MedicationId medicationId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final where = StringBuffer('medication_id = ?');
    final vars = <Variable>[Variable<String>(medicationId.value)];
    if (from != null) {
      where.write(' AND scheduled_at >= ?');
      vars.add(Variable<String>(from.toIso8601String()));
    }
    if (to != null) {
      where.write(' AND scheduled_at < ?');
      vars.add(Variable<String>(to.toIso8601String()));
    }
    final rows = await _db.customSelect(
      'SELECT * FROM $_kDoseEventsTable WHERE $where '
      'ORDER BY scheduled_at DESC, recorded_at DESC',
      variables: vars,
    ).get();
    return rows.map((r) => _doseEventFromRow(r.data)).toList();
  }

  /// Dose events recorded with the `missed` outcome scheduled before [cutoff].
  Future<List<DoseEvent>> getMissedEvents(DateTime cutoff) async {
    final rows = await _db.customSelect(
      "SELECT * FROM $_kDoseEventsTable "
      "WHERE outcome = 'missed' AND scheduled_at < ? "
      'ORDER BY scheduled_at DESC',
      variables: [Variable<String>(cutoff.toIso8601String())],
    ).get();
    return rows.map((r) => _doseEventFromRow(r.data)).toList();
  }

  // --- Mapping -------------------------------------------------------------

  Medication _medicationFromRow(Map<String, dynamic> row) => Medication(
        id: MedicationId.value(row['id'] as String),
        userId: UserId.value(row['user_id'] as String),
        name: row['name'] as String,
        doseAmount: row['dose_amount'] as String?,
        scheduleType: ScheduleType.values
            .byName(row['schedule_type'] as String),
        scheduleConfig: ScheduleConfig.fromJson(
          jsonDecode(row['schedule_config'] as String) as Map<String, dynamic>,
        ),
        startDate: DateTime.parse(row['start_date'] as String),
        endDate: (row['end_date'] as String?) != null
            ? DateTime.parse(row['end_date'] as String)
            : null,
        isControlled: (row['is_controlled'] as int) != 0,
      );

  DoseEvent _doseEventFromRow(Map<String, dynamic> row) => DoseEvent(
        id: DoseEventId.value(row['id'] as String),
        medicationId: MedicationId.value(row['medication_id'] as String),
        scheduledAt: DateTime.parse(row['scheduled_at'] as String),
        recordedAt: DateTime.parse(row['recorded_at'] as String),
        outcome: DoseOutcome.values.byName(row['outcome'] as String),
        parentEventId: (row['parent_event_id'] as String?) != null
            ? DoseEventId.value(row['parent_event_id'] as String)
            : null,
        snoozeUntil: (row['snooze_until'] as String?) != null
            ? DateTime.parse(row['snooze_until'] as String)
            : null,
      );
}

final medicationDaoProvider = Provider<MedicationDao>(
  (ref) => MedicationDao(ref.watch(appDatabaseProvider)),
);
