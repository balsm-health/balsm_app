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
      INSERT INTO health_profile (id, user_id, blood_type, updated_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        blood_type = excluded.blood_type,
        updated_at = excluded.updated_at
      ''',
      variables: [
        Variable.withString(key.value),
        Variable.withString(user.value),
        value.bloodType != null ? Variable.withString(value.bloodType!) : const Variable(null),
        Variable.withInt(now),
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
      bloodType: row.readNullable<String>('blood_type'),
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

  /// Inserts [allergy] under [profileId]. Returns the generated [AllergyId].
  @override
  Future<AllergyId> addAllergy(HealthProfileId profileId, Allergy allergy) async {
    final id = AllergyId.uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customInsert(
      '''
      INSERT INTO allergy
        (id, health_profile_id, name, severity, is_controlled_substance, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(id.value),
        Variable.withString(profileId.value),
        Variable.withString(allergy.name),
        Variable.withString(allergy.severity),
        Variable.withInt(allergy.isControlledSubstance ? 1 : 0),
        Variable.withInt(now),
      ],
    );
    return id;
  }

  /// Deletes the allergy row with the given [allergyId].
  @override
  Future<void> removeAllergy(AllergyId allergyId) async {
    await _db.customUpdate(
      'DELETE FROM allergy WHERE id = ?',
      variables: [Variable.withString(allergyId.value)],
    );
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

  /// Inserts [condition] under [profileId]. Returns the generated
  /// [ChronicConditionId].
  @override
  Future<ChronicConditionId> addCondition(HealthProfileId profileId, ChronicCondition condition) async {
    final id = ChronicConditionId.uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customInsert(
      '''
      INSERT INTO chronic_condition
        (id, health_profile_id, name, icd10_code, onset_year, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(id.value),
        Variable.withString(profileId.value),
        Variable.withString(condition.name),
        condition.icd10Code != null ? Variable.withString(condition.icd10Code!) : const Variable(null),
        condition.onsetYear != null ? Variable.withInt(condition.onsetYear!) : const Variable(null),
        Variable.withInt(now),
      ],
    );
    return id;
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

  /// Inserts [contact] under [profileId]. Returns the generated
  /// [EmergencyContactId].
  @override
  Future<EmergencyContactId> addContact(HealthProfileId profileId, EmergencyContact contact) async {
    final id = EmergencyContactId.uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customInsert(
      '''
      INSERT INTO emergency_contact
        (id, health_profile_id, name, phone, relation, is_primary, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(id.value),
        Variable.withString(profileId.value),
        Variable.withString(contact.name),
        Variable.withString(contact.phone),
        contact.relation != null ? Variable.withString(contact.relation!) : const Variable(null),
        Variable.withInt(contact.isPrimary ? 1 : 0),
        Variable.withInt(now),
      ],
    );
    return id;
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
