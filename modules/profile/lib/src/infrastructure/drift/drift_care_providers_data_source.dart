import 'dart:convert';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/care_providers_data_source.dart';
import '../../domain/entities/care_provider.dart';
import '../../domain/value_objects/care_provider_type.dart';
import '../../domain/value_objects/ids.dart';

/// Drift-backed [CareProvidersDataSource]. Raw SQL against the PHI schema in
/// core's `_phiSchema`, like every other on-device PHI store here.
///
/// A null scope resolves the ACTIVE profile from the injected [activeProfile]
/// callback; mutations with no active profile throw, reads come back empty.
class DriftCareProvidersDataSource extends CareProvidersDataSource {
  /// [outbox] is null in tests and in any build without cloud sync — the data
  /// source then behaves exactly as it did before sync existed, writing only
  /// locally.
  DriftCareProvidersDataSource({
    required AppDatabase db,
    required this.activeProfile,
    SyncOutboxDao? outbox,
    UserId? Function()? activeUser,
  })  : _db = db,
        _outbox = outbox,
        _activeUser = activeUser;

  final AppDatabase _db;
  final SyncOutboxDao? _outbox;

  /// Whose queue an enqueued change belongs to. Without it a change could be
  /// drained under the next account to sign in on this device.
  final UserId? Function()? _activeUser;
  final HealthProfileId? Function() activeProfile;

  /// Table name the outbox queues under, matching the cloud table.
  static const _entity = 'care_provider';

  /// The wire shape of one provider, matching UpsertCareProviderRequest.toJson
  /// in `balsm_api`. Kept here rather than on the entity so the domain stays
  /// free of transport concerns.
  static Map<String, dynamic> _payload(CareProviderId id, HealthProfileId profileId, CareProvider p) => {
        'id': id.value,
        'health_profile_id': profileId.value,
        'type': p.type.id,
        'name': p.name,
        'specialty': p.specialty,
        'phone': p.phone,
        'phone2': p.phone2,
        'email': p.email,
        'clinic': p.clinic,
        'address': p.address,
        'map_url': p.mapUrl,
        'notes': p.notes,
        'created_at': p.createdAt.toUtc().toIso8601String(),
      };

  HealthProfileId? _resolve(HealthProfileId? scope) => scope ?? activeProfile();

  HealthProfileId _require(HealthProfileId? scope) {
    final id = _resolve(scope);
    if (id == null) throw const NoActiveProfileException();
    return id;
  }

  static const _byProfile = 'SELECT * FROM care_provider WHERE health_profile_id = ? ORDER BY created_at ASC';

  CareProvider _hydrate(QueryRow r) => CareProvider(
        id: CareProviderId.value(r.read<String>('id')),
        healthProfileId: HealthProfileId.value(r.read<String>('health_profile_id')),
        type: CareProviderType.fromId(r.readNullable<String>('type')),
        name: r.read<String>('name'),
        specialty: r.readNullable<String>('specialty'),
        phone: r.readNullable<String>('phone'),
        phone2: r.readNullable<String>('phone2'),
        email: r.readNullable<String>('email'),
        clinic: r.readNullable<String>('clinic'),
        address: r.readNullable<String>('address'),
        mapUrl: r.readNullable<String>('map_url'),
        notes: r.readNullable<String>('notes'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at'), isUtc: true),
      );

  /// Empty optional fields persist as NULL, not '', so `readNullable` and the
  /// card's "has a value" checks agree.
  static Variable<Object> _opt(String? value) =>
      value == null || value.isEmpty ? const Variable(null) : Variable.withString(value);

  @override
  Future<CareProvider?> find(CareProviderId key, {HealthProfileId? scope}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM care_provider WHERE id = ?',
      variables: [Variable.withString(key.value)],
    ).get();
    return rows.isEmpty ? null : _hydrate(rows.first);
  }

  @override
  Future<List<CareProvider>> findAll({HealthProfileId? scope}) async {
    final id = _resolve(scope);
    if (id == null) return const [];
    final rows = await _db.customSelect(_byProfile, variables: [Variable.withString(id.value)]).get();
    return rows.map(_hydrate).toList();
  }

  @override
  Future<List<CareProvider>> findMany(Iterable<CareProviderId> keys, {HealthProfileId? scope}) async {
    final wanted = keys.map((k) => k.value).toSet();
    if (wanted.isEmpty) return const [];
    final all = await findAll(scope: scope);
    return all.where((p) => wanted.contains(p.id.value)).toList();
  }

  @override
  Future<bool> exists(CareProviderId key, {HealthProfileId? scope}) async => await find(key, scope: scope) != null;

  /// Insert or update. Re-putting an existing id is an edit — `created_at` is
  /// written once and left alone on later puts, so a row keeps the date it was
  /// first saved.
  @override
  Future<void> put(CareProviderId key, CareProvider value, {HealthProfileId? scope}) async {
    final profileId = _require(scope ?? value.healthProfileId);
    await _db.customInsert(
      '''
      INSERT INTO care_provider
        (id, health_profile_id, type, name, specialty, phone, phone2, email, clinic, address, map_url, notes, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        type = excluded.type, name = excluded.name, specialty = excluded.specialty,
        phone = excluded.phone, phone2 = excluded.phone2, email = excluded.email,
        clinic = excluded.clinic, address = excluded.address, map_url = excluded.map_url,
        notes = excluded.notes
      ''',
      variables: [
        Variable.withString(key.value),
        Variable.withString(profileId.value),
        Variable.withString(value.type.id),
        Variable.withString(value.name),
        _opt(value.specialty),
        _opt(value.phone),
        _opt(value.phone2),
        _opt(value.email),
        _opt(value.clinic),
        _opt(value.address),
        _opt(value.mapUrl),
        _opt(value.notes),
        Variable.withInt(value.createdAt.millisecondsSinceEpoch),
      ],
    );
    // Local write already happened — the queue is a mirror, never a gate (ADR-11).
    final user = _activeUser?.call();
    if (user != null) {
      await _outbox?.enqueue(
        entity: _entity,
        entityId: key.value,
        op: OutboxOp.upsert,
        payload: jsonEncode(_payload(key, profileId, value)),
        userId: user.value,
      );
    }
  }

  @override
  Future<void> putBulk(Map<CareProviderId, CareProvider> values, {HealthProfileId? scope}) async {
    for (final e in values.entries) {
      await put(e.key, e.value, scope: scope);
    }
  }

  @override
  Future<void> delete(CareProviderId key, {HealthProfileId? scope}) async {
    await _db.customUpdate(
      'DELETE FROM care_provider WHERE id = ?',
      variables: [Variable.withString(key.value)],
      updateKind: UpdateKind.delete,
    );
    final user = _activeUser?.call();
    if (user != null) {
      await _outbox?.enqueue(
        entity: _entity,
        entityId: key.value,
        op: OutboxOp.delete,
        payload: '{}',
        userId: user.value,
      );
    }
  }

  @override
  Future<void> deleteMany(Iterable<CareProviderId> keys, {HealthProfileId? scope}) async {
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
      'DELETE FROM care_provider WHERE health_profile_id = ?',
      variables: [Variable.withString(id.value)],
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Future<void> clearAll() async {
    await _db.customUpdate('DELETE FROM care_provider', updateKind: UpdateKind.delete);
  }

  @override
  Stream<CareProvider?> watch(CareProviderId key, {HealthProfileId? scope}) => _db
      .customSelect(
        'SELECT * FROM care_provider WHERE id = ?',
        variables: [Variable.withString(key.value)],
        readsFrom: {},
      )
      .watch()
      .map((rows) => rows.isEmpty ? null : _hydrate(rows.first));

  @override
  Stream<List<CareProvider>> watchAll({HealthProfileId? scope}) {
    final id = _resolve(scope);
    if (id == null) return Stream.value(const []);
    return _db
        .customSelect(_byProfile, variables: [Variable.withString(id.value)], readsFrom: {})
        .watch()
        .map((rows) => rows.map(_hydrate).toList());
  }

  // ── attachments ─────────────────────────────────────────────────────────

  static const _filesByProvider =
      'SELECT path FROM care_provider_file WHERE care_provider_id = ? ORDER BY created_at ASC';

  @override
  Future<List<String>> findFiles(CareProviderId providerId) async {
    final rows = await _db.customSelect(
      _filesByProvider,
      variables: [Variable.withString(providerId.value)],
    ).get();
    return [for (final r in rows) r.read<String>('path')];
  }

  @override
  Stream<List<String>> watchFiles(CareProviderId providerId) => _db
      .customSelect(_filesByProvider, variables: [Variable.withString(providerId.value)], readsFrom: {})
      .watch()
      .map((rows) => [for (final r in rows) r.read<String>('path')]);

  @override
  Future<void> putFile(CareProviderId providerId, String path) async {
    await _db.customInsert(
      'INSERT INTO care_provider_file (id, care_provider_id, path, created_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable.withString(CareProviderId.uuid().value),
        Variable.withString(providerId.value),
        Variable.withString(path),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  }

  @override
  Future<void> deleteFile(CareProviderId providerId, String path) async {
    await _db.customUpdate(
      'DELETE FROM care_provider_file WHERE care_provider_id = ? AND path = ?',
      variables: [Variable.withString(providerId.value), Variable.withString(path)],
      updateKind: UpdateKind.delete,
    );
  }
}

final careProvidersDataSourceProvider = Provider<CareProvidersDataSource>((ref) {
  return DriftCareProvidersDataSource(
    db: ref.watch(appDatabaseProvider),
    activeProfile: () => ref.read(currentProfileIdProvider),
    outbox: SyncOutboxDao(ref.watch(appDatabaseProvider)),
    activeUser: () => ref.read(currentUserIdProvider),
  );
});
