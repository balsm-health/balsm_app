import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/health_profiles_data_source.dart';
import '../../domain/aggregates/health_profile.dart';
import '../../domain/value_objects/ids.dart';

/// Drift-backed [UserDataSource] for the profile bounded context.
///
/// The partition is the OWNING account (`user_id`), the key is the
/// [HealthProfileId]: today each account owns exactly one profile (self,
/// ensured at session start by core's `activeProfileProvider`); the
/// dependants feature (P00X) adds sibling rows under the same partition, and
/// `findAll()` becomes the profile-switcher's data source.
///
/// Values are PHI and MUST remain on-device. Child collections (allergies,
/// conditions, emergency contacts) hydrate into the aggregate on reads but
/// are persisted via the dedicated add*/remove* methods — [put] writes the
/// head row only.
///
/// Scope semantics (per `ScopedDataSource`): `scope == null` resolves the
/// active user from [activeUser]; signed out → reads return null/empty,
/// mutations throw [NoActiveUserException], [clear] is an idempotent no-op.
class DriftProfileDataSource extends HealthProfilesDataSource {
  DriftProfileDataSource({required AppDatabase db, required this.activeUser}) : _db = db;

  final AppDatabase _db;

  /// Resolves the active user at call time (null = signed out).
  final UserId? Function() activeUser;

  UserId? _resolve(UserId? scope) => scope ?? activeUser();

  UserId _require(UserId? scope) {
    final user = _resolve(scope);
    if (user == null) throw const NoActiveUserException();
    return user;
  }

  // --- ScopedDataSource ----------------------------------------------------

  @override
  Future<HealthProfile?> find(HealthProfileId key, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM health_profile WHERE id = ? AND user_id = ? LIMIT 1',
      variables: [
        Variable.withString(key.value),
        Variable.withString(user.value),
      ],
    ).get();
    if (rows.isEmpty) return null;
    return _hydrateProfile(rows.first);
  }

  @override
  Future<List<HealthProfile>> findAll({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM health_profile WHERE user_id = ? ORDER BY updated_at ASC',
      variables: [Variable.withString(user.value)],
    ).get();
    return [for (final row in rows) await _hydrateProfile(row)];
  }

  @override
  Future<List<HealthProfile>> findMany(Iterable<HealthProfileId> keys, {UserId? scope}) async {
    final result = <HealthProfile>[];
    for (final key in keys) {
      final profile = await find(key, scope: scope);
      if (profile != null) result.add(profile);
    }
    return result;
  }

  @override
  Future<bool> exists(HealthProfileId key, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return false;
    final rows = await _db.customSelect(
      'SELECT 1 FROM health_profile WHERE id = ? AND user_id = ? LIMIT 1',
      variables: [
        Variable.withString(key.value),
        Variable.withString(user.value),
      ],
    ).get();
    return rows.isNotEmpty;
  }

  /// Upserts the head row (blood type + timestamps). Child collections are
  /// NOT persisted here — use the add*/remove* methods.
  @override
  Future<void> put(HealthProfileId key, HealthProfile value, {UserId? scope}) async {
    final user = _resolve(scope) ?? value.userId;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customInsert(
      '''
      INSERT INTO health_profile (id, user_id, blood_type, weight_kg, height_cm, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        blood_type = excluded.blood_type,
        weight_kg = excluded.weight_kg,
        height_cm = excluded.height_cm,
        updated_at = excluded.updated_at
      ''',
      variables: [
        Variable.withString(key.value),
        Variable.withString(user.value),
        value.bloodType != null ? Variable.withString(value.bloodType!.code) : const Variable(null),
        value.weightKg != null ? Variable.withReal(value.weightKg!) : const Variable(null),
        value.heightCm != null ? Variable.withReal(value.heightCm!) : const Variable(null),
        Variable.withInt(now),
      ],
    );
    await _syncChildren(key, value, now);
  }

  /// Writes the aggregate's child collections to match [value].
  ///
  /// Reads hydrate allergies, conditions and contacts into the aggregate, so
  /// `put` has to write them back or the two halves disagree — that asymmetry
  /// is what the old add*/remove* methods existed to paper over.
  ///
  /// Last-write-wins on the whole aggregate: a row that is stored but absent
  /// from [value] is deleted. Safe here because a profile is single-user,
  /// on-device, and always read immediately before it is modified — but it
  /// does mean a caller must `put` an aggregate it actually read, never one it
  /// assembled from nothing.
  ///
  /// Rows are matched by id. A child carrying an empty id is new and gets one
  /// minted with that table's own prefix, so callers append a fresh value
  /// without inventing an id.
  Future<void> _syncChildren(HealthProfileId profileId, HealthProfile value, int now) async {
    Future<void> sync({
      required String table,
      required String columns,
      required String Function() mint,
      required List<({String id, List<Variable<Object>> values})> rows,
    }) async {
      final keep = <String>[];
      for (final row in rows) {
        final id = row.id.isEmpty ? mint() : row.id;
        keep.add(id);
        final placeholders = List.filled(row.values.length + 3, '?').join(', ');
        await _db.customInsert(
          'INSERT OR REPLACE INTO $table ($columns) VALUES ($placeholders)',
          variables: [
            Variable.withString(id),
            Variable.withString(profileId.value),
            ...row.values,
            Variable.withInt(now),
          ],
        );
      }
      // Anything under this profile that survived is no longer in the
      // aggregate, so it was removed.
      final marks = keep.isEmpty ? '' : ' AND id NOT IN (${List.filled(keep.length, '?').join(', ')})';
      await _db.customUpdate(
        'DELETE FROM $table WHERE health_profile_id = ?$marks',
        variables: [Variable.withString(profileId.value), ...keep.map(Variable.withString)],
        updateKind: UpdateKind.delete,
      );
    }

    await sync(
      table: 'allergy',
      columns: 'id, health_profile_id, name, severity, is_controlled_substance, created_at',
      mint: () => AllergyId.uuid().value,
      rows: [
        for (final a in value.allergies)
          (
            id: a.id.value,
            values: <Variable<Object>>[
              Variable.withString(a.name),
              Variable.withString(a.severity),
              Variable.withInt(a.isControlledSubstance ? 1 : 0),
            ],
          ),
      ],
    );
    await sync(
      table: 'chronic_condition',
      columns: 'id, health_profile_id, name, icd10_code, onset_year, created_at',
      mint: () => ChronicConditionId.uuid().value,
      rows: [
        for (final c in value.conditions)
          (
            id: c.id.value,
            values: <Variable<Object>>[
              Variable.withString(c.name),
              c.icd10Code != null ? Variable.withString(c.icd10Code!) : const Variable(null),
              c.onsetYear != null ? Variable.withInt(c.onsetYear!) : const Variable(null),
            ],
          ),
      ],
    );
    await sync(
      table: 'emergency_contact',
      columns: 'id, health_profile_id, name, phone, relation, is_primary, created_at',
      mint: () => EmergencyContactId.uuid().value,
      rows: [
        for (final c in value.emergencyContacts)
          (
            id: c.id.value,
            values: <Variable<Object>>[
              Variable.withString(c.name),
              Variable.withString(c.phone),
              c.relation != null ? Variable.withString(c.relation!) : const Variable(null),
              Variable.withInt(c.isPrimary ? 1 : 0),
            ],
          ),
      ],
    );
  }

  @override
  Future<void> putBulk(Map<HealthProfileId, HealthProfile> values, {UserId? scope}) async {
    for (final entry in values.entries) {
      await put(entry.key, entry.value, scope: scope);
    }
  }

  /// Deletes the profile row; child rows cascade (`ON DELETE CASCADE`).
  @override
  Future<void> delete(HealthProfileId key, {UserId? scope}) async {
    final user = _require(scope);
    await _db.customUpdate(
      'DELETE FROM health_profile WHERE id = ? AND user_id = ?',
      variables: [
        Variable.withString(key.value),
        Variable.withString(user.value),
      ],
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<void> deleteMany(Iterable<HealthProfileId> keys, {UserId? scope}) async {
    for (final key in keys) {
      await delete(key, scope: scope);
    }
  }

  @override
  Future<void> clear({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return; // idempotent logout cleanup
    await _db.customUpdate(
      'DELETE FROM health_profile WHERE user_id = ?',
      variables: [Variable.withString(user.value)],
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<void> clearAll() async {
    await _db.customUpdate('DELETE FROM health_profile', updateKind: UpdateKind.delete);
  }

  // --- WatchableScopedDataSource -------------------------------------------

  @override
  Stream<HealthProfile?> watch(HealthProfileId key, {UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(null);
    return _db
        .customSelect(
          'SELECT * FROM health_profile WHERE id = ? AND user_id = ? LIMIT 1',
          variables: [
            Variable.withString(key.value),
            Variable.withString(user.value),
          ],
          readsFrom: {},
        )
        .watch()
        .asyncMap((rows) async => rows.isEmpty ? null : _hydrateProfile(rows.first));
  }

  @override
  Stream<List<HealthProfile>> watchAll({UserId? scope}) {
    final user = _resolve(scope);
    if (user == null) return Stream.value(const []);
    return _db
        .customSelect(
          'SELECT * FROM health_profile WHERE user_id = ? '
          'ORDER BY updated_at ASC',
          variables: [Variable.withString(user.value)],
          readsFrom: {},
        )
        .watch()
        .asyncMap((rows) async => [for (final row in rows) await _hydrateProfile(row)]);
  }

  // --- Aggregate conveniences (pre-contract API, kept for callers) ---------

  /// The user's (self) profile, or null if none exists yet.
  @override
  Future<HealthProfile?> getProfile(UserId userId) async => (await findAll(scope: userId)).firstOrNull;

  /// Emits the current profile and updates whenever the row changes.
  @override
  Stream<HealthProfile?> watchProfile(UserId userId) => watchAll(scope: userId).map((profiles) => profiles.firstOrNull);

  /// Inserts or updates the head row for [profile]. Does NOT persist child
  /// collections — use the individual add*/remove* methods.
  @override
  Future<void> upsertProfile(HealthProfile profile) => put(profile.id, profile, scope: profile.userId);

  Future<HealthProfile> _hydrateProfile(QueryRow row) async {
    final profileId = HealthProfileId.value(row.read<String>('id'));

    final allergies = await _getAllergies(profileId);
    final conditions = await _getConditions(profileId);
    final contacts = await _getContacts(profileId);

    return HealthProfile(
      id: profileId,
      userId: UserId.value(row.read<String>('user_id')),
      // Legacy free-text rows degrade to unknown rather than crashing.
      bloodType: BloodType.tryParse(row.readNullable<String>('blood_type')),
      weightKg: (row.data['weight_kg'] as num?)?.toDouble(),
      heightCm: (row.data['height_cm'] as num?)?.toDouble(),
      allergies: allergies,
      conditions: conditions,
      emergencyContacts: contacts,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('updated_at'),
        isUtc: true,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // allergy
  // -----------------------------------------------------------------------

  Future<List<Allergy>> _getAllergies(HealthProfileId profileId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM allergy WHERE health_profile_id = ? ORDER BY created_at ASC',
      variables: [Variable.withString(profileId.value)],
    ).get();

    return rows
        .map((r) => Allergy(
              id: AllergyId.value(r.read<String>('id')),
              healthProfileId: HealthProfileId.value(r.read<String>('health_profile_id')),
              name: r.read<String>('name'),
              severity: r.read<String>('severity'),
              isControlledSubstance: r.read<int>('is_controlled_substance') == 1,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                r.read<int>('created_at'),
                isUtc: true,
              ),
            ))
        .toList();
  }

  // -----------------------------------------------------------------------
  // chronic_condition
  // -----------------------------------------------------------------------

  Future<List<ChronicCondition>> _getConditions(HealthProfileId profileId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM chronic_condition WHERE health_profile_id = ? ORDER BY created_at ASC',
      variables: [Variable.withString(profileId.value)],
    ).get();

    return rows
        .map((r) => ChronicCondition(
              id: ChronicConditionId.value(r.read<String>('id')),
              healthProfileId: HealthProfileId.value(r.read<String>('health_profile_id')),
              name: r.read<String>('name'),
              icd10Code: r.readNullable<String>('icd10_code'),
              onsetYear: r.readNullable<int>('onset_year'),
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                r.read<int>('created_at'),
                isUtc: true,
              ),
            ))
        .toList();
  }

  // -----------------------------------------------------------------------
  // emergency_contact
  // -----------------------------------------------------------------------

  Future<List<EmergencyContact>> _getContacts(HealthProfileId profileId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM emergency_contact WHERE health_profile_id = ? ORDER BY is_primary DESC, created_at ASC',
      variables: [Variable.withString(profileId.value)],
    ).get();

    return rows
        .map((r) => EmergencyContact(
              id: EmergencyContactId.value(r.read<String>('id')),
              healthProfileId: HealthProfileId.value(r.read<String>('health_profile_id')),
              name: r.read<String>('name'),
              phone: r.read<String>('phone'),
              relation: r.readNullable<String>('relation'),
              isPrimary: r.read<int>('is_primary') == 1,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                r.read<int>('created_at'),
                isUtc: true,
              ),
            ))
        .toList();
  }
}

/// Bound to the authenticated user via core's `currentUserIdProvider`;
/// requires [appDatabaseProvider] to be overridden at bootstrap.
final profileDataSourceProvider = Provider<HealthProfilesDataSource>((ref) {
  return DriftProfileDataSource(
    db: ref.watch(appDatabaseProvider),
    activeUser: () => ref.read(currentUserIdProvider),
  );
});
