import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../domain/aggregates/prescription.dart';
import '../../domain/value_objects/ids.dart';

/// Drift-backed [UserDataSource] for prescriptions. PHI, on-device only.
///
/// Scope semantics match the records vault: `scope == null` resolves the
/// ACTIVE user; no active user → mutations throw [NoActiveUserException] and
/// reads return null/empty. Every query filters on `user_id`.
class DriftPrescriptionsDataSource extends UserDataSource<PrescriptionId, Prescription>
    implements WatchableScopedDataSource<PrescriptionId, Prescription, UserId> {
  DriftPrescriptionsDataSource(this._db, this.activeUser);

  final AppDatabase _db;

  /// Resolves the active user at call time (null = signed out).
  final UserId? Function() activeUser;

  static const _table = 'prescription';

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

  Prescription _hydrate(Map<String, dynamic> row) => Prescription(
        id: PrescriptionId.value(row['id'] as String),
        userId: UserId.value(row['user_id'] as String),
        clinician: row['clinician'] as String,
        title: row['title'] as String?,
        specialty: row['specialty'] as String?,
        reference: row['reference'] as String?,
        source: row['source'] as String?,
        attachmentPath: row['attachment_path'] as String?,
        attachmentKind: row['attachment_kind'] as String?,
        items: [
          for (final e in jsonDecode(row['items'] as String) as List)
            PrescribedItem.fromJson((e as Map).cast<String, dynamic>()),
        ],
        issuedAt: DateTime.parse(row['issued_at'] as String),
        validUntil: switch (row['valid_until'] as String?) {
          final v? => DateTime.parse(v),
          _ => null,
        },
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  // ── Reads ────────────────────────────────────────────────────────────────

  @override
  Future<Prescription?> find(PrescriptionId key, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE id = ? AND user_id = ? LIMIT 1',
      variables: [Variable<String>(key.value), Variable<String>(user.value)],
    ).get();
    return rows.isEmpty ? null : _hydrate(rows.first.data);
  }

  @override
  Future<List<Prescription>> findAll({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE user_id = ? ORDER BY issued_at DESC',
      variables: [Variable<String>(user.value)],
    ).get();
    return [for (final r in rows) _hydrate(r.data)];
  }

  @override
  Future<List<Prescription>> findMany(Iterable<PrescriptionId> keys, {UserId? scope}) async {
    final out = <Prescription>[];
    for (final k in keys) {
      final a = await find(k, scope: scope);
      if (a != null) out.add(a);
    }
    return out;
  }

  @override
  Future<bool> exists(PrescriptionId key, {UserId? scope}) async => await find(key, scope: scope) != null;

  // ── Watch ────────────────────────────────────────────────────────────────

  @override
  Stream<Prescription?> watch(PrescriptionId key, {UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(null);
    return Stream<Prescription?>.multi((emitter) async {
      emitter.add(await find(key, scope: user));
      emitter.addStream(_changes.stream.asyncMap((_) => find(key, scope: user)));
    });
  }

  @override
  Stream<List<Prescription>> watchAll({UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(const []);
    return Stream<List<Prescription>>.multi((emitter) async {
      emitter.add(await findAll(scope: user));
      emitter.addStream(_changes.stream.asyncMap((_) => findAll(scope: user)));
    });
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<void> put(PrescriptionId key, Prescription value, {UserId? scope}) async {
    final user = _require(scope);
    await _db.customInsert(
      'INSERT OR REPLACE INTO $_table '
      '(id, user_id, clinician, title, specialty, reference, source, attachment_path, attachment_kind, items, issued_at, valid_until, created_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      variables: [
        Variable<String>(key.value),
        Variable<String>(user.value),
        Variable<String>(value.clinician),
        Variable<String>(value.title),
        Variable<String>(value.specialty),
        Variable<String>(value.reference),
        Variable<String>(value.source),
        Variable<String>(value.attachmentPath),
        Variable<String>(value.attachmentKind),
        Variable<String>(jsonEncode([for (final i in value.items) i.toJson()])),
        Variable<String>(value.issuedAt.toUtc().toIso8601String()),
        Variable<String>(value.validUntil?.toUtc().toIso8601String()),
        Variable<String>(value.createdAt.toUtc().toIso8601String()),
      ],
    );
    _notifyChanged();
  }

  @override
  Future<void> putBulk(Map<PrescriptionId, Prescription> values, {UserId? scope}) async {
    final user = _require(scope);
    for (final e in values.entries) {
      await put(e.key, e.value, scope: user);
    }
  }

  @override
  Future<void> delete(PrescriptionId key, {UserId? scope}) async {
    final user = _require(scope);
    await _db.customUpdate(
      'DELETE FROM $_table WHERE id = ? AND user_id = ?',
      variables: [Variable<String>(key.value), Variable<String>(user.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> deleteMany(Iterable<PrescriptionId> keys, {UserId? scope}) async {
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

/// DI: user-partitioned prescriptions bound to the active user port.
final prescriptionsDataSourceProvider = Provider<DriftPrescriptionsDataSource>((ref) {
  return DriftPrescriptionsDataSource(
    ref.watch(appDatabaseProvider),
    () => ref.read(currentUserIdProvider),
  );
});

/// Live prescriptions for the signed-in user, newest first.
final prescriptionListProvider = StreamProvider.autoDispose<List<Prescription>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(prescriptionsDataSourceProvider).watchAll();
});
