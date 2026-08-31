import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/appointment.dart';
import '../../domain/value_objects/ids.dart';

/// Drift-backed [UserDataSource] for appointments. PHI, on-device only.
///
/// Scope semantics match the records vault: `scope == null` resolves the
/// ACTIVE user; no active user → mutations throw [NoActiveUserException] and
/// reads return null/empty. Every query filters on `user_id`.
class DriftAppointmentsDataSource extends UserDataSource<AppointmentId, Appointment>
    implements WatchableScopedDataSource<AppointmentId, Appointment, UserId> {
  DriftAppointmentsDataSource(this._db, this.activeUser);

  final AppDatabase _db;

  /// Resolves the active user at call time (null = signed out).
  final UserId? Function() activeUser;

  static const _table = 'appointment';

  /// Change signal for [watch]/[watchAll] — the schema is raw SQL, so drift's
  /// table-based invalidation cannot fire.
  final _changes = StreamController<void>.broadcast();

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  UserId? _resolve(UserId? scope) => scope ?? activeUser();

  UserId _require(UserId? scope) {
    final user = _resolve(scope);
    if (user == null) throw const NoActiveUserException();
    return user;
  }

  Appointment _hydrate(Map<String, dynamic> row) => Appointment(
        id: AppointmentId.value(row['id'] as String),
        userId: UserId.value(row['user_id'] as String),
        clinician: row['clinician'] as String,
        specialty: row['specialty'] as String?,
        location: row['location'] as String?,
        kind: switch (row['kind'] as String) {
          'follow_up' => AppointmentKind.followUp,
          _ => AppointmentKind.checkUp,
        },
        startsAt: DateTime.parse(row['starts_at'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  static String _kindId(AppointmentKind k) => k == AppointmentKind.followUp ? 'follow_up' : 'check_up';

  // ── Reads ────────────────────────────────────────────────────────────────

  @override
  Future<Appointment?> find(AppointmentId key, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE id = ? AND user_id = ? LIMIT 1',
      variables: [Variable<String>(key.value), Variable<String>(user.value)],
    ).get();
    return rows.isEmpty ? null : _hydrate(rows.first.data);
  }

  @override
  Future<List<Appointment>> findAll({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE user_id = ? ORDER BY starts_at DESC',
      variables: [Variable<String>(user.value)],
    ).get();
    return [for (final r in rows) _hydrate(r.data)];
  }

  @override
  Future<List<Appointment>> findMany(Iterable<AppointmentId> keys, {UserId? scope}) async {
    final out = <Appointment>[];
    for (final k in keys) {
      final a = await find(k, scope: scope);
      if (a != null) out.add(a);
    }
    return out;
  }

  @override
  Future<bool> exists(AppointmentId key, {UserId? scope}) async => await find(key, scope: scope) != null;

  // ── Watch ────────────────────────────────────────────────────────────────

  @override
  Stream<Appointment?> watch(AppointmentId key, {UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(null);
    return Stream<Appointment?>.multi((emitter) async {
      emitter.add(await find(key, scope: user));
      emitter.addStream(_changes.stream.asyncMap((_) => find(key, scope: user)));
    });
  }

  @override
  Stream<List<Appointment>> watchAll({UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(const []);
    return Stream<List<Appointment>>.multi((emitter) async {
      emitter.add(await findAll(scope: user));
      emitter.addStream(_changes.stream.asyncMap((_) => findAll(scope: user)));
    });
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<void> put(AppointmentId key, Appointment value, {UserId? scope}) async {
    final user = _require(scope);
    await _db.customInsert(
      'INSERT OR REPLACE INTO $_table '
      '(id, user_id, clinician, specialty, location, kind, starts_at, created_at) '
      'VALUES (?,?,?,?,?,?,?,?)',
      variables: [
        Variable<String>(key.value),
        Variable<String>(user.value),
        Variable<String>(value.clinician),
        Variable<String>(value.specialty),
        Variable<String>(value.location),
        Variable<String>(_kindId(value.kind)),
        Variable<String>(value.startsAt.toUtc().toIso8601String()),
        Variable<String>(value.createdAt.toUtc().toIso8601String()),
      ],
    );
    _notifyChanged();
  }

  @override
  Future<void> putBulk(Map<AppointmentId, Appointment> values, {UserId? scope}) async {
    final user = _require(scope);
    for (final e in values.entries) {
      await put(e.key, e.value, scope: user);
    }
  }

  @override
  Future<void> delete(AppointmentId key, {UserId? scope}) async {
    final user = _require(scope);
    await _db.customUpdate(
      'DELETE FROM $_table WHERE id = ? AND user_id = ?',
      variables: [Variable<String>(key.value), Variable<String>(user.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> deleteMany(Iterable<AppointmentId> keys, {UserId? scope}) async {
    for (final k in keys) {
      await delete(k, scope: scope);
    }
  }

  @override
  Future<void> clear({UserId? scope}) async {
    // Idempotent: logout may run twice, and signed-out has nothing to clear.
    final user = _resolve(scope);
    if (user == null) return;
    await _db.customUpdate(
      'DELETE FROM $_table WHERE user_id = ?',
      variables: [Variable<String>(user.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> clearAll() async {
    // Device-wide wipe (account deletion), not scoped to one user.
    await _db.customUpdate('DELETE FROM $_table', updateKind: UpdateKind.delete);
    _notifyChanged();
  }
}

/// DI: user-partitioned appointments bound to the active user port.
final appointmentsDataSourceProvider = Provider<DriftAppointmentsDataSource>((ref) {
  return DriftAppointmentsDataSource(
    ref.watch(appDatabaseProvider),
    () => ref.read(currentUserIdProvider),
  );
});

/// Live appointments for the signed-in user, soonest-last (newest first).
final appointmentListProvider = StreamProvider.autoDispose<List<Appointment>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(appointmentsDataSourceProvider).watchAll();
});
