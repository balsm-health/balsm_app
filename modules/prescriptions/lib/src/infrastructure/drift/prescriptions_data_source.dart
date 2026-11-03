import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../application/ports/prescriptions_data_source.dart';
import '../../domain/aggregates/prescription.dart';
import '../../domain/value_objects/ids.dart';

/// Drift-backed [ProfileDataSource] for prescriptions. PHI, on-device only.
///
/// Scope semantics match the records vault: `scope == null` resolves the
/// ACTIVE health profile; no active profile → mutations throw
/// [NoActiveProfileException] and reads return null/empty. Every query
/// filters on `health_profile_id`; `user_id` keeps the owning account.
class DriftPrescriptionsDataSource extends PrescriptionsDataSource {
  DriftPrescriptionsDataSource(this._db, this.activeProfile);

  final AppDatabase _db;

  /// Resolves the active health profile at call time (null = signed out, or
  /// the self profile is not ensured yet).
  final HealthProfileId? Function() activeProfile;

  static const _table = 'prescription';

  /// Change signal for [watch]/[watchAll] — the schema is raw SQL, so drift's
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

  /// A prescription is filed under a profile of the account that owns it —
  /// never under another account's person.
  Future<void> _requireOwnedBy(HealthProfileId profile, UserId owner, String what) async {
    final rows = await _db.customSelect(
      'SELECT 1 FROM health_profile WHERE id = ? AND user_id = ?',
      variables: [Variable<String>(profile.value), Variable<String>(owner.value)],
    ).get();
    if (rows.isEmpty) {
      throw StorageWriteException('$what: profile ${profile.value} is not owned by ${owner.value}');
    }
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
  Future<Prescription?> find(PrescriptionId key, {HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE id = ? AND health_profile_id = ? LIMIT 1',
      variables: [Variable<String>(key.value), Variable<String>(profile.value)],
    ).get();
    return rows.isEmpty ? null : _hydrate(rows.first.data);
  }

  @override
  Future<List<Prescription>> findAll({HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM $_table WHERE health_profile_id = ? ORDER BY issued_at DESC',
      variables: [Variable<String>(profile.value)],
    ).get();
    return [for (final r in rows) _hydrate(r.data)];
  }

  @override
  Future<List<Prescription>> findMany(Iterable<PrescriptionId> keys, {HealthProfileId? scope}) async {
    final out = <Prescription>[];
    for (final k in keys) {
      final a = await find(k, scope: scope);
      if (a != null) out.add(a);
    }
    return out;
  }

  @override
  Future<bool> exists(PrescriptionId key, {HealthProfileId? scope}) async => await find(key, scope: scope) != null;

  // ── Watch ────────────────────────────────────────────────────────────────

  @override
  Stream<Prescription?> watch(PrescriptionId key, {HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(null);
    return Stream<Prescription?>.multi((emitter) async {
      emitter.add(await find(key, scope: profile));
      emitter.addStream(_changes.stream.asyncMap((_) => find(key, scope: profile)));
    });
  }

  @override
  Stream<List<Prescription>> watchAll({HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(const []);
    return Stream<List<Prescription>>.multi((emitter) async {
      emitter.add(await findAll(scope: profile));
      emitter.addStream(_changes.stream.asyncMap((_) => findAll(scope: profile)));
    });
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<void> put(PrescriptionId key, Prescription value, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _requireOwnedBy(profile, value.userId, 'prescription ${key.value}');
    await _db.customInsert(
      'INSERT OR REPLACE INTO $_table '
      '(id, user_id, health_profile_id, clinician, title, specialty, reference, source, attachment_path, '
      'attachment_kind, items, issued_at, valid_until, created_at) '
      'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      variables: [
        Variable<String>(key.value),
        Variable<String>(value.userId.value),
        Variable<String>(profile.value),
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
  Future<void> putBulk(Map<PrescriptionId, Prescription> values, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    for (final e in values.entries) {
      await put(e.key, e.value, scope: profile);
    }
  }

  @override
  Future<void> delete(PrescriptionId key, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _db.customUpdate(
      'DELETE FROM $_table WHERE id = ? AND health_profile_id = ?',
      variables: [Variable<String>(key.value), Variable<String>(profile.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> deleteMany(Iterable<PrescriptionId> keys, {HealthProfileId? scope}) async {
    for (final k in keys) {
      await delete(k, scope: scope);
    }
  }

  @override
  Future<void> clear({HealthProfileId? scope}) async {
    // Idempotent: logout may run twice, and signed-out has nothing to clear.
    final profile = _resolve(scope);
    if (profile == null) return;
    await _db.customUpdate(
      'DELETE FROM $_table WHERE health_profile_id = ?',
      variables: [Variable<String>(profile.value)],
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

/// DI: profile-partitioned prescriptions bound to the active-profile port.
final prescriptionsDataSourceProvider = Provider<PrescriptionsDataSource>((ref) {
  return DriftPrescriptionsDataSource(
    ref.watch(appDatabaseProvider),
    () => ref.read(currentProfileIdProvider),
  );
});

/// Live prescriptions for the active profile, newest first. Re-subscribes
/// when the active profile changes.
final prescriptionListProvider = StreamProvider.autoDispose<List<Prescription>>((ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) return Stream.value(const []);
  return ref.watch(prescriptionsDataSourceProvider).watchAll(scope: profileId);
});
