import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/profile_child_data_sources.dart';
import '../../domain/aggregates/health_profile.dart';
import '../../domain/value_objects/ids.dart';

/// Shared drift plumbing for the profile's child collections.
///
/// The three tables differ only in their columns and how a row hydrates, so
/// the contract surface — find/findAll/findMany/exists/put/putBulk/delete/
/// deleteMany/clear/clearAll/watch/watchAll — is written once here rather
/// than three times with three chances to drift apart.
abstract class _DriftProfileChildSource<K extends UniqueId, V> extends ScopedDataSource<K, V, HealthProfileId>
    implements WatchableScopedDataSource<K, V, HealthProfileId> {
  _DriftProfileChildSource({required AppDatabase db, required this.activeProfile}) : _db = db;

  final AppDatabase _db;
  final HealthProfileId? Function() activeProfile;

  /// Table name, and the ORDER BY that gives this collection its display order.
  String get table;
  String get orderBy => 'created_at ASC';

  V hydrate(QueryRow row);

  /// Columns after `id, health_profile_id`, and the matching values for
  /// [value] — `created_at` is appended by [put].
  (String columns, List<Variable<Object>> values) columnsFor(V value);

  /// The row's own id, or null when the caller has not minted one.
  String idOf(V value);

  HealthProfileId? _resolve(HealthProfileId? scope) => scope ?? activeProfile();

  HealthProfileId _require(HealthProfileId? scope) {
    final id = _resolve(scope);
    if (id == null) throw const NoActiveProfileException();
    return id;
  }

  @override
  Future<V?> find(K key, {HealthProfileId? scope}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM $table WHERE id = ?',
      variables: [Variable.withString(key.value)],
    ).get();
    return rows.isEmpty ? null : hydrate(rows.first);
  }

  @override
  Future<List<V>> findAll({HealthProfileId? scope}) async {
    final id = _resolve(scope);
    if (id == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM $table WHERE health_profile_id = ? ORDER BY $orderBy',
      variables: [Variable.withString(id.value)],
    ).get();
    return rows.map(hydrate).toList();
  }

  @override
  Future<List<V>> findMany(Iterable<K> keys, {HealthProfileId? scope}) async {
    final wanted = keys.map((k) => k.value).toSet();
    if (wanted.isEmpty) return const [];
    final all = await findAll(scope: scope);
    return all.where((v) => wanted.contains(idOf(v))).toList();
  }

  @override
  Future<bool> exists(K key, {HealthProfileId? scope}) async => await find(key, scope: scope) != null;

  @override
  Future<void> put(K key, V value, {HealthProfileId? scope}) async {
    final profileId = _require(scope);
    final (columns, values) = columnsFor(value);
    final placeholders = List.filled(values.length + 3, '?').join(', ');
    await _db.customInsert(
      'INSERT OR REPLACE INTO $table (id, health_profile_id, $columns, created_at) VALUES ($placeholders)',
      variables: [
        Variable.withString(key.value),
        Variable.withString(profileId.value),
        ...values,
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  }

  @override
  Future<void> putBulk(Map<K, V> values, {HealthProfileId? scope}) async {
    for (final e in values.entries) {
      await put(e.key, e.value, scope: scope);
    }
  }

  @override
  Future<void> delete(K key, {HealthProfileId? scope}) async {
    await _db.customUpdate(
      'DELETE FROM $table WHERE id = ?',
      variables: [Variable.withString(key.value)],
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<void> deleteMany(Iterable<K> keys, {HealthProfileId? scope}) async {
    for (final k in keys) {
      await delete(k, scope: scope);
    }
  }

  @override
  Future<void> clear({HealthProfileId? scope}) async {
    final id = _resolve(scope);
    // Idempotent logout cleanup: no active profile is a no-op, not a throw.
    if (id == null) return;
    await _db.customUpdate(
      'DELETE FROM $table WHERE health_profile_id = ?',
      variables: [Variable.withString(id.value)],
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<void> clearAll() async {
    await _db.customUpdate('DELETE FROM $table', updateKind: UpdateKind.delete);
  }

  @override
  Stream<V?> watch(K key, {HealthProfileId? scope}) => _db
      .customSelect(
        'SELECT * FROM $table WHERE id = ?',
        variables: [Variable.withString(key.value)],
        readsFrom: {},
      )
      .watch()
      .map((rows) => rows.isEmpty ? null : hydrate(rows.first));

  @override
  Stream<List<V>> watchAll({HealthProfileId? scope}) {
    final id = _resolve(scope);
    if (id == null) return Stream.value(const []);
    return _db
        .customSelect(
          'SELECT * FROM $table WHERE health_profile_id = ? ORDER BY $orderBy',
          variables: [Variable.withString(id.value)],
          readsFrom: {},
        )
        .watch()
        .map((rows) => rows.map(hydrate).toList());
  }

  static DateTime at(QueryRow r) => DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at'), isUtc: true);
  static HealthProfileId profileOf(QueryRow r) => HealthProfileId.value(r.read<String>('health_profile_id'));
}

class DriftAllergiesDataSource extends _DriftProfileChildSource<AllergyId, Allergy> implements AllergiesDataSource {
  DriftAllergiesDataSource({required super.db, required super.activeProfile});

  @override
  String get table => 'allergy';

  @override
  String idOf(Allergy v) => v.id.value;

  @override
  Allergy hydrate(QueryRow r) => Allergy(
        id: AllergyId.value(r.read<String>('id')),
        healthProfileId: _DriftProfileChildSource.profileOf(r),
        name: r.read<String>('name'),
        severity: r.read<String>('severity'),
        isControlledSubstance: r.read<int>('is_controlled_substance') == 1,
        createdAt: _DriftProfileChildSource.at(r),
      );

  @override
  (String, List<Variable<Object>>) columnsFor(Allergy v) => (
        'name, severity, is_controlled_substance',
        [
          Variable.withString(v.name),
          Variable.withString(v.severity),
          Variable.withInt(v.isControlledSubstance ? 1 : 0),
        ],
      );
}

class DriftChronicConditionsDataSource extends _DriftProfileChildSource<ChronicConditionId, ChronicCondition>
    implements ChronicConditionsDataSource {
  DriftChronicConditionsDataSource({required super.db, required super.activeProfile});

  @override
  String get table => 'chronic_condition';

  @override
  String idOf(ChronicCondition v) => v.id.value;

  @override
  ChronicCondition hydrate(QueryRow r) => ChronicCondition(
        id: ChronicConditionId.value(r.read<String>('id')),
        healthProfileId: _DriftProfileChildSource.profileOf(r),
        name: r.read<String>('name'),
        icd10Code: r.readNullable<String>('icd10_code'),
        onsetYear: r.readNullable<int>('onset_year'),
        createdAt: _DriftProfileChildSource.at(r),
      );

  @override
  (String, List<Variable<Object>>) columnsFor(ChronicCondition v) => (
        'name, icd10_code, onset_year',
        [
          Variable.withString(v.name),
          v.icd10Code != null ? Variable.withString(v.icd10Code!) : const Variable(null),
          v.onsetYear != null ? Variable.withInt(v.onsetYear!) : const Variable(null),
        ],
      );
}

class DriftEmergencyContactsDataSource extends _DriftProfileChildSource<EmergencyContactId, EmergencyContact>
    implements EmergencyContactsDataSource {
  DriftEmergencyContactsDataSource({required super.db, required super.activeProfile});

  @override
  String get table => 'emergency_contact';

  /// The primary contact leads, as the emergency card shows them.
  @override
  String get orderBy => 'is_primary DESC, created_at ASC';

  @override
  String idOf(EmergencyContact v) => v.id.value;

  @override
  EmergencyContact hydrate(QueryRow r) => EmergencyContact(
        id: EmergencyContactId.value(r.read<String>('id')),
        healthProfileId: _DriftProfileChildSource.profileOf(r),
        name: r.read<String>('name'),
        phone: r.read<String>('phone'),
        relation: r.readNullable<String>('relation'),
        isPrimary: r.read<int>('is_primary') == 1,
        createdAt: _DriftProfileChildSource.at(r),
      );

  @override
  (String, List<Variable<Object>>) columnsFor(EmergencyContact v) => (
        'name, phone, relation, is_primary',
        [
          Variable.withString(v.name),
          Variable.withString(v.phone),
          v.relation != null ? Variable.withString(v.relation!) : const Variable(null),
          Variable.withInt(v.isPrimary ? 1 : 0),
        ],
      );
}

final allergiesDataSourceProvider = Provider<AllergiesDataSource>((ref) {
  return DriftAllergiesDataSource(
    db: ref.watch(appDatabaseProvider),
    activeProfile: () => ref.read(currentProfileIdProvider),
  );
});

final chronicConditionsDataSourceProvider = Provider<ChronicConditionsDataSource>((ref) {
  return DriftChronicConditionsDataSource(
    db: ref.watch(appDatabaseProvider),
    activeProfile: () => ref.read(currentProfileIdProvider),
  );
});

final emergencyContactsDataSourceProvider = Provider<EmergencyContactsDataSource>((ref) {
  return DriftEmergencyContactsDataSource(
    db: ref.watch(appDatabaseProvider),
    activeProfile: () => ref.read(currentProfileIdProvider),
  );
});
