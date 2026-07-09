import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/value_objects/ids.dart';

// TODO: drift table annotations — run `dart run build_runner build` once tables
// are declared in AppDatabase (or a module-specific DbContext).
//
// Until build_runner integration is wired, this DAO uses AppDatabase's raw
// executor (NativeDatabase) via customSelect / customInsert helpers exposed
// by the Drift runtime.  All values written here are PHI and MUST remain
// on-device (SQLCipher encrypted).
//
// Ids are stored as TEXT (the columns were always declared TEXT; the previous
// Variable.withBlob writes relied on sqlite's dynamic typing and are gone).

/// Data-access object for the profile bounded context.
/// Reads/writes four on-device tables:
///   health_profile, allergy, chronic_condition, emergency_contact.
class ProfileDao {
  ProfileDao({required AppDatabase db}) : _db = db;

  final AppDatabase _db;

  // -----------------------------------------------------------------------
  // health_profile
  // -----------------------------------------------------------------------

  /// Returns the profile for [userId], or null if none exists yet.
  Future<HealthProfile?> getProfile(UserId userId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM health_profile WHERE user_id = ? LIMIT 1',
      variables: [Variable.withString(userId.value)],
    ).get();

    if (rows.isEmpty) return null;
    return _hydrateProfile(rows.first);
  }

  /// Emits the current profile and updates whenever the row changes.
  Stream<HealthProfile?> watchProfile(UserId userId) {
    return _db
        .customSelect(
          'SELECT * FROM health_profile WHERE user_id = ? LIMIT 1',
          variables: [Variable.withString(userId.value)],
          readsFrom: {},
        )
        .watch()
        .asyncMap((rows) async {
      if (rows.isEmpty) return null;
      return _hydrateProfile(rows.first);
    });
  }

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

  /// Inserts or updates the health_profile row for [profile.userId].
  /// Does NOT persist child collections — use the individual add* methods.
  Future<void> upsertProfile(HealthProfile profile) async {
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
        Variable.withString(profile.id.value),
        Variable.withString(profile.userId.value),
        profile.bloodType != null
            ? Variable.withString(profile.bloodType!)
            : const Variable(null),
        Variable.withInt(now),
      ],
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
              healthProfileId:
                  HealthProfileId.value(r.read<String>('health_profile_id')),
              name: r.read<String>('name'),
              severity: r.read<String>('severity'),
              isControlledSubstance:
                  r.read<int>('is_controlled_substance') == 1,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                r.read<int>('created_at'),
                isUtc: true,
              ),
            ))
        .toList();
  }

  /// Inserts [allergy] under [profileId]. Returns the generated [AllergyId].
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
              healthProfileId:
                  HealthProfileId.value(r.read<String>('health_profile_id')),
              name: r.read<String>('name'),
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                r.read<int>('created_at'),
                isUtc: true,
              ),
            ))
        .toList();
  }

  /// Inserts [condition] under [profileId]. Returns the generated
  /// [ChronicConditionId].
  Future<ChronicConditionId> addCondition(
      HealthProfileId profileId, ChronicCondition condition) async {
    final id = ChronicConditionId.uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customInsert(
      '''
      INSERT INTO chronic_condition
        (id, health_profile_id, name, created_at)
      VALUES (?, ?, ?, ?)
      ''',
      variables: [
        Variable.withString(id.value),
        Variable.withString(profileId.value),
        Variable.withString(condition.name),
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
              healthProfileId:
                  HealthProfileId.value(r.read<String>('health_profile_id')),
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
  Future<EmergencyContactId> addContact(
      HealthProfileId profileId, EmergencyContact contact) async {
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
        contact.relation != null
            ? Variable.withString(contact.relation!)
            : const Variable(null),
        Variable.withInt(contact.isPrimary ? 1 : 0),
        Variable.withInt(now),
      ],
    );
    return id;
  }
}

/// Riverpod provider — requires [appDatabaseProvider] to be overridden at bootstrap.
final profileDaoProvider = Provider<ProfileDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProfileDao(db: db);
});
