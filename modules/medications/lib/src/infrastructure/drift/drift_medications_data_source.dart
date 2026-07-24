import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/medications_data_source.dart';
import '../../domain/aggregates/medication.dart';
import '../../domain/entities/dose_event.dart';
import '../../domain/value_objects/ids.dart';

const _kMedicationsTable = 'medications';
const _kDoseEventsTable = 'dose_events';

/// Drift-backed [ProfileDataSource] for medications + their APPEND-ONLY dose
/// history. PHI lives on-device only.
///
/// Scope semantics (per `ScopedDataSource`): rows partition on
/// `health_profile_id` — the person the medication belongs to. `scope == null`
/// resolves the ACTIVE profile from the injected [activeProfile] callback
/// (bound to core's `currentProfileIdProvider`, which ensures the self
/// profile row at session start); no active profile → mutations throw
/// [NoActiveProfileException], reads return empty.
///
/// Domain deviations from the raw contract, both deliberate:
/// - [delete] is a SOFT delete (sets `end_date` to yesterday): the
///   append-only dose history (FR-019) must outlive the medication row, and
///   sqlite triggers block deleting `dose_events` anyway.
/// - [clear]/[clearAll] soft-retire for the same reason. Physical PHI wipe is
///   a database-file-level operation owned by the deletion flow, not a
///   row-level contract op.
class DriftMedicationsDataSource extends MedicationsDataSource {
  DriftMedicationsDataSource(this._db, this.activeProfile);

  final AppDatabase _db;

  /// Resolves the active health profile at call time (null = signed out or
  /// the self profile is not ensured yet).
  final HealthProfileId? Function() activeProfile;

  HealthProfileId? _resolve(HealthProfileId? scope) => scope ?? activeProfile();

  HealthProfileId _require(HealthProfileId? scope) {
    final profile = _resolve(scope);
    if (profile == null) throw const NoActiveProfileException();
    return profile;
  }

  // --- ScopedDataSource ----------------------------------------------------

  @override
  Future<Medication?> find(MedicationId key, {HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM $_kMedicationsTable '
      'WHERE id = ? AND health_profile_id = ? LIMIT 1',
      variables: [
        Variable<String>(key.value),
        Variable<String>(profile.value),
      ],
    ).get();
    return rows.isEmpty ? null : _medicationFromRow(rows.first.data);
  }

  @override
  Future<List<Medication>> findAll({HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM $_kMedicationsTable WHERE health_profile_id = ? '
      'ORDER BY name COLLATE NOCASE ASC',
      variables: [Variable<String>(profile.value)],
    ).get();
    return rows.map((r) => _medicationFromRow(r.data)).toList();
  }

  @override
  Future<List<Medication>> findMany(Iterable<MedicationId> keys,
      {HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null || keys.isEmpty) return const [];
    final ids = keys.map((k) => k.value).toList();
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.customSelect(
      'SELECT * FROM $_kMedicationsTable '
      'WHERE health_profile_id = ? AND id IN ($placeholders)',
      variables: [
        Variable<String>(profile.value),
        ...ids.map((id) => Variable<String>(id)),
      ],
    ).get();
    return rows.map((r) => _medicationFromRow(r.data)).toList();
  }

  @override
  Future<bool> exists(MedicationId key, {HealthProfileId? scope}) async =>
      await find(key, scope: scope) != null;

  @override
  Future<void> put(MedicationId key, Medication value,
      {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _db.customInsert(
      'INSERT OR REPLACE INTO $_kMedicationsTable '
      '(id, user_id, health_profile_id, name, dose_amount, schedule_type, '
      'schedule_config, start_date, end_date, is_controlled) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(key.value),
        Variable<String>(value.userId.value),
        Variable<String>(profile.value),
        Variable<String>(value.name),
        Variable<String>(value.doseAmount),
        Variable<String>(value.scheduleType.name),
        Variable<String>(jsonEncode(value.scheduleConfig.toJson())),
        Variable<String>(value.startDate.toIso8601String()),
        Variable<String>(value.endDate?.toIso8601String()),
        Variable<int>(value.isControlled ? 1 : 0),
      ],
    );
  }

  @override
  Future<void> putBulk(Map<MedicationId, Medication> values,
      {HealthProfileId? scope}) async {
    final profile = _require(scope);
    for (final entry in values.entries) {
      await put(entry.key, entry.value, scope: profile);
    }
  }

  /// Soft delete: sets `end_date` to yesterday so the medication is treated
  /// as expired while its (append-only) dose history is preserved.
  @override
  Future<void> delete(MedicationId key, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await _db.customUpdate(
      'UPDATE $_kMedicationsTable SET end_date = ? '
      'WHERE id = ? AND health_profile_id = ?',
      variables: [
        Variable<String>(yesterday.toIso8601String()),
        Variable<String>(key.value),
        Variable<String>(profile.value),
      ],
      updateKind: UpdateKind.update,
    );
  }

  @override
  Future<void> deleteMany(Iterable<MedicationId> keys,
      {HealthProfileId? scope}) async {
    final profile = _require(scope);
    for (final key in keys) {
      await delete(key, scope: profile);
    }
  }

  /// Soft-retires the partition (see class doc — physical wipe is
  /// DB-file-level). No-op when signed out (idempotent logout cleanup).
  @override
  Future<void> clear({HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await _db.customUpdate(
      'UPDATE $_kMedicationsTable SET end_date = ? WHERE health_profile_id = ?',
      variables: [
        Variable<String>(yesterday.toIso8601String()),
        Variable<String>(profile.value),
      ],
      updateKind: UpdateKind.update,
    );
  }

  @override
  Future<void> clearAll() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await _db.customUpdate(
      'UPDATE $_kMedicationsTable SET end_date = ?',
      variables: [Variable<String>(yesterday.toIso8601String())],
      updateKind: UpdateKind.update,
    );
  }

  // --- WatchableScopedDataSource -------------------------------------------

  @override
  Stream<Medication?> watch(MedicationId key, {HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(null);
    return _db.customSelect(
      'SELECT * FROM $_kMedicationsTable '
      'WHERE id = ? AND health_profile_id = ? LIMIT 1',
      variables: [
        Variable<String>(key.value),
        Variable<String>(profile.value),
      ],
      readsFrom: {/* TODO: medications table after build_runner */},
    ).watch().map(
        (rows) => rows.isEmpty ? null : _medicationFromRow(rows.first.data));
  }

  @override
  Stream<List<Medication>> watchAll({HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(const []);
    return _db
        .customSelect(
          'SELECT * FROM $_kMedicationsTable WHERE health_profile_id = ? '
          'ORDER BY name COLLATE NOCASE ASC',
          variables: [Variable<String>(profile.value)],
          readsFrom: {/* TODO: medications table after build_runner */},
        )
        .watch()
        .map((rows) => rows.map((r) => _medicationFromRow(r.data)).toList());
  }

  // --- Dose events (APPEND-ONLY, keyed by medication FK — unscoped) --------

  /// Appends a dose event. Never updates or deletes existing rows.
  @override
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
  @override
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
  @override
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

/// Bound to the active profile via core's `currentProfileIdProvider` (which
/// ensures the self health-profile row at session start).
final medicationsDataSourceProvider = Provider<MedicationsDataSource>(
  (ref) => DriftMedicationsDataSource(
    ref.watch(appDatabaseProvider),
    () => ref.read(currentProfileIdProvider),
  ),
);
