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
/// [HealthProfileId]: each account owns one self profile (`is_self = 1`,
/// ensured at session start by core's `activeProfileProvider`) and any
/// number of member profiles (dependent / prenatal) under the same partition.
/// Self is always found by `is_self`, never by "the account's first row".
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
      'SELECT * FROM health_profile WHERE user_id = ? $_memberOrder',
      variables: [Variable.withString(user.value)],
    ).get();
    return [for (final row in rows) await _hydrateProfile(row)];
  }

  /// Self first, then members in creation order — stable across edits.
  static const _memberOrder = 'ORDER BY is_self DESC, rowid ASC';

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

  /// Upserts the head row (blood type, measurements, timestamp). A new row
  /// is inserted with all of [value]'s fields; an existing row only has its
  /// head fields updated — member details and the lifecycle change through
  /// [updateMember] / [closeMember]. Child collections are NOT persisted
  /// here — use the add*/remove* methods.
  @override
  Future<void> put(HealthProfileId key, HealthProfile value, {UserId? scope}) async {
    final user = _resolve(scope) ?? value.userId;
    await _insert(key, value, user, onConflict: '''
      ON CONFLICT(id) DO UPDATE SET
        blood_type = excluded.blood_type,
        weight_kg = excluded.weight_kg,
        height_cm = excluded.height_cm,
        updated_at = excluded.updated_at''');
  }

  Future<void> _insert(HealthProfileId key, HealthProfile value, UserId user, {String onConflict = ''}) async {
    await _db.customInsert(
      '''
      INSERT INTO health_profile (id, user_id, blood_type, weight_kg, height_cm, updated_at,
        is_self, kind, display_name, date_of_birth, sex, relationship, group_id, tone,
        status, closed_on, pregnancy_id, sequence)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      $onConflict
      ''',
      variables: [
        Variable.withString(key.value),
        Variable.withString(user.value),
        Variable<String>(value.bloodType?.code),
        Variable<double>(value.weightKg),
        Variable<double>(value.heightCm),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withInt(value.isSelf ? 1 : 0),
        Variable.withString(value.kind.wire),
        ..._detailVariables(value),
        Variable.withString(value.status.wire),
        Variable<String>(_date(value.closedOn)),
        Variable<String>(value.pregnancyId?.value),
        Variable<int>(value.sequence),
      ],
    );
  }

  /// display_name, date_of_birth, sex, relationship, group_id, tone — in
  /// that column order.
  List<Variable> _detailVariables(HealthProfile value) => [
        Variable<String>(value.displayName),
        Variable<String>(_date(value.dateOfBirth)),
        Variable<String>(value.sex?.wire),
        Variable<String>(value.relationship?.wire),
        Variable<String>(value.groupId?.value),
        Variable<String>(value.tone),
      ];

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
          'SELECT * FROM health_profile WHERE user_id = ? $_memberOrder',
          variables: [Variable.withString(user.value)],
          readsFrom: {},
        )
        .watch()
        .asyncMap((rows) async => [for (final row in rows) await _hydrateProfile(row)]);
  }

  // --- Aggregate conveniences (pre-contract API, kept for callers) ---------

  /// The user's self profile (`is_self = 1`), or null if none exists yet.
  @override
  Future<HealthProfile?> getProfile(UserId userId) async {
    final rows = await _db.customSelect(
      '$_selfQuery LIMIT 1',
      variables: [Variable.withString(userId.value)],
    ).get();
    return rows.isEmpty ? null : _hydrateProfile(rows.first);
  }

  /// Emits the self profile and updates whenever the row changes.
  @override
  Stream<HealthProfile?> watchProfile(UserId userId) => _db
      .customSelect(
        '$_selfQuery LIMIT 1',
        variables: [Variable.withString(userId.value)],
        readsFrom: {},
      )
      .watch()
      .asyncMap((rows) async => rows.isEmpty ? null : _hydrateProfile(rows.first));

  /// The earliest self row wins — the same rule as core's
  /// `AppDatabase.selfHealthProfileId`.
  static const _selfQuery = 'SELECT * FROM health_profile WHERE user_id = ? AND is_self = 1 ORDER BY rowid';

  // --- Member profiles ------------------------------------------------------

  @override
  Future<List<HealthProfile>> findMembers({UserId? scope, bool includeClosed = false}) async {
    final user = _resolve(scope);
    if (user == null) return const [];
    final open = includeClosed ? '' : "AND status = 'active' ";
    final rows = await _db.customSelect(
      'SELECT * FROM health_profile WHERE user_id = ? $open$_memberOrder',
      variables: [Variable.withString(user.value)],
    ).get();
    return [for (final row in rows) await _hydrateProfile(row)];
  }

  @override
  Future<void> createMember(HealthProfile member, {UserId? scope}) async {
    final user = _require(scope);
    if (member.isSelf) {
      throw StorageWriteException('profile ${member.id.value}: the self profile is not created as a member');
    }
    try {
      await _insert(member.id, member, user);
    } catch (e) {
      throw StorageWriteException('profile ${member.id.value}: member insert failed', e);
    }
  }

  @override
  Future<bool> updateMember(HealthProfile member, {UserId? scope}) async {
    final user = _require(scope);
    final changed = await _db.customUpdate(
      '''
      UPDATE health_profile SET display_name = ?, date_of_birth = ?, sex = ?, relationship = ?,
        group_id = ?, tone = ?, sequence = ?, updated_at = ?
      WHERE id = ? AND user_id = ? AND is_self = 0 AND status = 'active'
      ''',
      variables: [
        ..._detailVariables(member),
        Variable<int>(member.sequence),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(member.id.value),
        Variable.withString(user.value),
      ],
      updateKind: UpdateKind.update,
    );
    return changed > 0;
  }

  @override
  Future<bool> closeMember(HealthProfileId id, DateTime closedOn, {UserId? scope}) async {
    final user = _require(scope);
    final changed = await _db.customUpdate(
      '''
      UPDATE health_profile SET status = 'closed', closed_on = ?, updated_at = ?
      WHERE id = ? AND user_id = ? AND is_self = 0 AND status = 'active'
      ''',
      variables: [
        Variable.withString(_date(closedOn)!),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(id.value),
        Variable.withString(user.value),
      ],
      updateKind: UpdateKind.update,
    );
    return changed > 0;
  }

  /// Calendar dates are stored as ISO `YYYY-MM-DD`.
  static String? _date(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// `is_self` is the authority: a row is self exactly when it is flagged so,
  /// whatever its `kind` text says.
  static ProfileKind _kindOf(QueryRow row) {
    if (row.read<int>('is_self') == 1) return ProfileKind.self;
    final kind = ProfileKind.fromWire(row.readNullable<String>('kind'));
    return kind == ProfileKind.self ? ProfileKind.dependent : kind;
  }

  static DateTime? _parseDate(String? s) {
    final d = s == null ? null : DateTime.tryParse(s);
    return d == null ? null : DateTime.utc(d.year, d.month, d.day);
  }

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
      kind: _kindOf(row),
      displayName: row.readNullable<String>('display_name'),
      dateOfBirth: _parseDate(row.readNullable<String>('date_of_birth')),
      sex: Sex.tryFromWire(row.readNullable<String>('sex')),
      relationship: Relationship.tryFromCode(row.readNullable<String>('relationship')),
      groupId: MemberGroupId.fromString(row.readNullable<String>('group_id')),
      tone: row.readNullable<String>('tone'),
      status: ProfileStatus.fromWire(row.readNullable<String>('status')),
      closedOn: _parseDate(row.readNullable<String>('closed_on')),
      pregnancyId: PregnancyId.fromString(row.readNullable<String>('pregnancy_id')),
      sequence: row.readNullable<int>('sequence'),
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
