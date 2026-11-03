import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/growth_log_data_source.dart';
import '../../domain/aggregates/growth_entry.dart';
import '../../domain/value_objects/growth_entry_id.dart';

/// Drift-backed [GrowthLogDataSource] over the raw-SQL
/// `growth_entry` table in core's encrypted database.
///
/// Scope semantics (per `ScopedDataSource`):
/// - `scope == null` → the ACTIVE health profile from [activeProfile]
///   (bound to `currentProfileIdProvider`) — the person measured.
/// - no active profile → mutations throw [NoActiveProfileException]; reads
///   return null/empty; [clear] is an idempotent no-op.
/// - every query filters on `health_profile_id`, so one person's growth log is
///   invisible while another profile is active.
///
/// A write is refused ([StorageWriteException]) unless the profile is an
/// open profile of the signed-in account ([activeUser]): a closed member's
/// log stays read-only, and no account logs measurements for another's person.
/// [delete] only stamps `deleted_at`; dates are stored as `YYYY-MM-DD`.
class DriftGrowthLogDataSource extends ProfileDataSource<GrowthEntryId, GrowthEntry> implements GrowthLogDataSource {
  DriftGrowthLogDataSource({
    required AppDatabase db,
    required this.activeProfile,
    required this.activeUser,
    DateTime Function()? clock,
  })  : _db = db,
        _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Resolves the active health profile at call time (null = none yet).
  final HealthProfileId? Function() activeProfile;

  /// Resolves the signed-in account at call time (null = signed out).
  final UserId? Function() activeUser;

  static const _table = 'growth_entry';
  static const _live = 'deleted_at IS NULL';
  static const _order = 'ORDER BY measured_on DESC, created_at DESC';

  /// Change signal for the watch streams — the table is raw SQL, so drift's
  /// table-based invalidation cannot fire.
  final _changes = StreamController<void>.broadcast();

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  HealthProfileId? _resolve(HealthProfileId? scope) => scope ?? activeProfile();

  HealthProfileId _require(HealthProfileId? scope) {
    final profile = _resolve(scope);
    if (profile == null) throw const NoActiveProfileException();
    return profile;
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  @override
  Future<GrowthEntry?> find(GrowthEntryId key, {HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE id = ? AND health_profile_id = ? AND $_live LIMIT 1',
      variables: [Variable.withString(key.value), Variable.withString(profile.value)],
    ).get();
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<GrowthEntry>> findAll({HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE health_profile_id = ? AND $_live $_order',
      variables: [Variable.withString(profile.value)],
    ).get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<GrowthEntry>> findMany(Iterable<GrowthEntryId> keys, {HealthProfileId? scope}) async {
    final wanted = {for (final k in keys) k.value};
    return (await findAll(scope: scope)).where((r) => wanted.contains(r.id.value)).toList();
  }

  @override
  Future<bool> exists(GrowthEntryId key, {HealthProfileId? scope}) async => await find(key, scope: scope) != null;

  // ── Watch ────────────────────────────────────────────────────────────────

  @override
  Stream<GrowthEntry?> watch(GrowthEntryId key, {HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(null);
    return _watch(() => find(key, scope: profile));
  }

  @override
  Stream<List<GrowthEntry>> watchAll({HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(const []);
    return _watch(() => findAll(scope: profile));
  }

  Stream<T> _watch<T>(Future<T> Function() read) => Stream<T>.multi((emitter) async {
        emitter.add(await read());
        emitter.addStream(_changes.stream.asyncMap((_) => read()));
      });

  // ── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<void> put(GrowthEntryId key, GrowthEntry value, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _requireWritable(profile);
    await _write(key, value, profile);
    _notifyChanged();
  }

  @override
  Future<void> putBulk(Map<GrowthEntryId, GrowthEntry> values, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _requireWritable(profile);
    await _db.transaction(() async {
      for (final e in values.entries) {
        await _write(e.key, e.value, profile);
      }
    });
    _notifyChanged();
  }

  Future<void> _write(GrowthEntryId key, GrowthEntry value, HealthProfileId profile) async {
    try {
      await _db.customInsert(
        '''
        INSERT INTO $_table
          (id, health_profile_id, measured_on, weight_kg, height_cm, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          measured_on = excluded.measured_on, weight_kg = excluded.weight_kg, height_cm = excluded.height_cm
          WHERE $_table.health_profile_id = excluded.health_profile_id AND $_table.deleted_at IS NULL
        ''',
        variables: [
          Variable.withString(key.value),
          Variable.withString(profile.value),
          Variable.withString(_iso(value.measuredOn)),
          Variable<double>(value.weightKg),
          Variable<double>(value.heightCm),
          Variable.withInt(value.createdAt.millisecondsSinceEpoch),
        ],
      );
    } catch (e) {
      throw StorageWriteException('$_table ${key.value}: write failed', e);
    }
  }

  /// Soft delete: the row stays, stamped `deleted_at`.
  @override
  Future<void> delete(GrowthEntryId key, {HealthProfileId? scope}) => deleteMany([key], scope: scope);

  @override
  Future<void> deleteMany(Iterable<GrowthEntryId> keys, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    final ids = keys.map((k) => k.value).toList();
    if (ids.isEmpty) return;
    await _db.customUpdate(
      'UPDATE $_table SET deleted_at = ? WHERE health_profile_id = ? AND $_live '
      'AND id IN (${List.filled(ids.length, '?').join(', ')})',
      variables: [
        Variable.withInt(_clock().millisecondsSinceEpoch),
        Variable.withString(profile.value),
        ...ids.map(Variable.withString),
      ],
      updateKind: UpdateKind.update,
    );
    _notifyChanged();
  }

  /// Account wipe: removes the profile's rows outright.
  @override
  Future<void> clear({HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return;
    await _db.customUpdate(
      'DELETE FROM $_table WHERE health_profile_id = ?',
      variables: [Variable.withString(profile.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> clearAll() async {
    await _db.customUpdate('DELETE FROM $_table', updateKind: UpdateKind.delete);
    _notifyChanged();
  }

  Future<void> _requireWritable(HealthProfileId profile) async {
    final user = activeUser();
    if (user == null) throw const NoActiveUserException();
    final rows = await _db.customSelect(
      "SELECT 1 FROM health_profile WHERE id = ? AND user_id = ? AND status = 'active'",
      variables: [Variable.withString(profile.value), Variable.withString(user.value)],
    ).get();
    if (rows.isEmpty) {
      throw StorageWriteException('$_table: profile ${profile.value} is not an open profile of this account');
    }
  }

  // ── Mapping ──────────────────────────────────────────────────────────────

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _day(String iso) {
    final d = DateTime.parse(iso);
    return DateTime.utc(d.year, d.month, d.day);
  }

  static GrowthEntry _fromRow(QueryRow row) {
    try {
      return GrowthEntry(
        id: GrowthEntryId.value(row.read<String>('id')),
        measuredOn: _day(row.read<String>('measured_on')),
        weightKg: row.readNullable<double>('weight_kg'),
        heightCm: row.readNullable<double>('height_cm'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at'), isUtc: true),
      );
    } catch (e) {
      throw StorageDecodeException('$_table row: undecodable', e);
    }
  }
}

/// Bound to the active profile and the signed-in account; requires
/// [appDatabaseProvider] to be overridden at bootstrap. Exposed as the port.
final growthLogDataSourceProvider = Provider<GrowthLogDataSource>((ref) {
  return DriftGrowthLogDataSource(
    db: ref.watch(appDatabaseProvider),
    activeProfile: () => ref.read(currentProfileIdProvider),
    activeUser: () => ref.read(currentUserIdProvider),
  );
});
