import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/pregnancies_data_source.dart';
import '../../domain/aggregates/pregnancy.dart';
import '../../domain/entities/pregnancy_item.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/value_objects/pregnancy_enums.dart';

/// Drift-backed [PregnanciesDataSource] over the raw-SQL `pregnancy`,
/// `pregnancy_item` and `pregnancy_item_baby` tables in core's encrypted
/// database. The partition is the mother's `health_profile_id`; items reach
/// it through their pregnancy.
///
/// Values are PHI and MUST remain on-device; nothing here is logged.
class DriftPregnanciesDataSource implements PregnanciesDataSource {
  DriftPregnanciesDataSource({required AppDatabase db, required this.activeProfile}) : _db = db;

  final AppDatabase _db;

  /// Resolves the partition at call time — the account holder's self
  /// profile (null = signed out or not ensured yet).
  final HealthProfileId? Function() activeProfile;

  static const _live = 'deleted_at IS NULL';
  static const _order = 'ORDER BY created_at DESC, rowid DESC';

  /// Change signal for the watch streams — the tables are raw SQL, so
  /// drift's table-based invalidation cannot fire.
  final _changes = StreamController<void>.broadcast();

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Stream<T> _liveRead<T>(Future<T> Function() read) => Stream<T>.multi((emitter) async {
        emitter.add(await read());
        emitter.addStream(_changes.stream.asyncMap((_) => read()));
      });

  HealthProfileId? _resolve(HealthProfileId? scope) => scope ?? activeProfile();

  HealthProfileId _require(HealthProfileId? scope) {
    final profile = _resolve(scope);
    if (profile == null) throw const NoActiveProfileException();
    return profile;
  }

  // --- Pregnancy ------------------------------------------------------------

  @override
  Future<Pregnancy?> find(PregnancyId key, {HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM pregnancy WHERE id = ? AND health_profile_id = ? AND $_live LIMIT 1',
      variables: [Variable.withString(key.value), Variable.withString(profile.value)],
    ).get();
    return rows.isEmpty ? null : _pregnancy(rows.first);
  }

  @override
  Future<List<Pregnancy>> findAll({HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM pregnancy WHERE health_profile_id = ? AND $_live $_order',
      variables: [Variable.withString(profile.value)],
    ).get();
    return rows.map(_pregnancy).toList();
  }

  @override
  Future<List<Pregnancy>> findMany(Iterable<PregnancyId> keys, {HealthProfileId? scope}) async {
    final wanted = {for (final k in keys) k};
    return (await findAll(scope: scope)).where((p) => wanted.contains(p.id)).toList();
  }

  @override
  Future<bool> exists(PregnancyId key, {HealthProfileId? scope}) async => await find(key, scope: scope) != null;

  @override
  Future<Pregnancy?> findActive({HealthProfileId? scope}) async =>
      (await findAll(scope: scope)).where((p) => p.isActive).firstOrNull;

  /// Inserts [value] or rewrites its mutable fields (obstetrician, next
  /// visit, status, closed date). The mother and creation time never change.
  @override
  Future<void> put(PregnancyId key, Pregnancy value, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    if (value.motherId != profile) {
      throw StorageWriteException('pregnancy ${key.value}: belongs to another profile');
    }
    final visit = value.nextVisit;
    await _db.customInsert(
      '''
      INSERT INTO pregnancy (id, health_profile_id, due_date, ob_name, ob_phone, next_visit_on,
        next_visit_time, next_visit_clinic, status, closed_on, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        due_date = excluded.due_date,
        ob_name = excluded.ob_name,
        ob_phone = excluded.ob_phone,
        next_visit_on = excluded.next_visit_on,
        next_visit_time = excluded.next_visit_time,
        next_visit_clinic = excluded.next_visit_clinic,
        status = excluded.status,
        closed_on = excluded.closed_on
      WHERE pregnancy.health_profile_id = excluded.health_profile_id
      ''',
      variables: [
        Variable.withString(key.value),
        Variable.withString(profile.value),
        Variable.withString(_date(value.dueDate)!),
        Variable<String>(value.obName),
        Variable<String>(value.obPhone),
        Variable<String>(_date(visit?.date)),
        Variable<String>(visit?.time),
        Variable<String>(visit?.clinic),
        Variable.withString(value.status.wire),
        Variable<String>(_date(value.closedOn)),
        Variable.withInt(value.createdAt.millisecondsSinceEpoch),
      ],
    );
    _notifyChanged();
  }

  @override
  Future<void> putBulk(Map<PregnancyId, Pregnancy> values, {HealthProfileId? scope}) async {
    for (final e in values.entries) {
      await put(e.key, e.value, scope: scope);
    }
  }

  /// Soft: stamps `deleted_at`; the pregnancy and its items are kept.
  @override
  Future<void> delete(PregnancyId key, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _db.customUpdate(
      'UPDATE pregnancy SET deleted_at = ? WHERE id = ? AND health_profile_id = ? AND $_live',
      variables: [
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(key.value),
        Variable.withString(profile.value),
      ],
      updateKind: UpdateKind.update,
    );
    _notifyChanged();
  }

  @override
  Future<void> deleteMany(Iterable<PregnancyId> keys, {HealthProfileId? scope}) async {
    for (final k in keys) {
      await delete(k, scope: scope);
    }
  }

  /// Account wipe for one profile: rows go outright (items and links cascade).
  @override
  Future<void> clear({HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return;
    await _db.customUpdate(
      'DELETE FROM pregnancy WHERE health_profile_id = ?',
      variables: [Variable.withString(profile.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> clearAll() async {
    await _db.customUpdate('DELETE FROM pregnancy', updateKind: UpdateKind.delete);
    _notifyChanged();
  }

  @override
  Stream<Pregnancy?> watch(PregnancyId key, {HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(null);
    return _liveRead(() => find(key, scope: profile));
  }

  @override
  Stream<List<Pregnancy>> watchAll({HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(const []);
    return _liveRead(() => findAll(scope: profile));
  }

  // --- Items ------------------------------------------------------------------

  /// Items of a pregnancy in the partition, joined to its mother's profile.
  static const _itemsOf = '''
    SELECT i.* FROM pregnancy_item i JOIN pregnancy p ON p.id = i.pregnancy_id
    WHERE i.pregnancy_id = ? AND p.health_profile_id = ? AND i.deleted_at IS NULL
    ORDER BY i.recorded_on DESC, i.created_at DESC, i.rowid DESC''';

  @override
  Future<List<PregnancyItem>> findItems(PregnancyId pregnancy, {HealthProfileId? scope}) async {
    final profile = _resolve(scope);
    if (profile == null) return const [];
    final rows = await _db.customSelect(
      _itemsOf,
      variables: [Variable.withString(pregnancy.value), Variable.withString(profile.value)],
    ).get();
    if (rows.isEmpty) return const [];
    final links = await _db.customSelect(
      '''
      SELECT l.item_id, l.health_profile_id FROM pregnancy_item_baby l
        JOIN pregnancy_item i ON i.id = l.item_id
      WHERE i.pregnancy_id = ? AND l.deleted_at IS NULL ORDER BY l.rowid''',
      variables: [Variable.withString(pregnancy.value)],
    ).get();
    final babies = <String, List<HealthProfileId>>{};
    for (final l in links) {
      (babies[l.read<String>('item_id')] ??= []).add(HealthProfileId.value(l.read<String>('health_profile_id')));
    }
    return [for (final r in rows) _item(r, babies[r.read<String>('id')] ?? const [])];
  }

  @override
  Stream<List<PregnancyItem>> watchItems(PregnancyId pregnancy, {HealthProfileId? scope}) {
    final profile = _resolve(scope);
    if (profile == null) return Stream.value(const []);
    return _liveRead(() => findItems(pregnancy, scope: profile));
  }

  @override
  Future<void> addItem(PregnancyItem item, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    await _db.transaction(() async {
      if (await find(item.pregnancyId, scope: profile) == null) {
        throw StorageWriteException('pregnancy item ${item.id.value}: pregnancy not in partition');
      }
      await _db.customInsert(
        '''
        INSERT INTO pregnancy_item (id, pregnancy_id, about, kind, title, recorded_on, fetal_hr_bpm, efw_g,
          other_label, other_value, attachment_ref, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        variables: [
          Variable.withString(item.id.value),
          Variable.withString(item.pregnancyId.value),
          Variable.withString(item.about.wire),
          Variable.withString(item.kind.wire),
          Variable<String>(item.title),
          Variable.withString(_date(item.recordedOn)!),
          Variable<int>(item.fetalHeartRateBpm),
          Variable<int>(item.estimatedFetalWeightG),
          Variable<String>(item.otherLabel),
          Variable<String>(item.otherValue),
          Variable<String>(item.attachmentRef),
          Variable.withInt(item.createdAt.millisecondsSinceEpoch),
        ],
      );
      for (final baby in item.babyIds) {
        await _db.customInsert(
          'INSERT INTO pregnancy_item_baby (item_id, health_profile_id) VALUES (?, ?)',
          variables: [Variable.withString(item.id.value), Variable.withString(baby.value)],
        );
      }
    });
    _notifyChanged();
  }

  @override
  Future<bool> deleteItem(PregnancyItemId id, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    final changed = await _db.customUpdate(
      '''
      UPDATE pregnancy_item SET deleted_at = ?
      WHERE id = ? AND deleted_at IS NULL
        AND pregnancy_id IN (SELECT id FROM pregnancy WHERE health_profile_id = ?)''',
      variables: [
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(id.value),
        Variable.withString(profile.value),
      ],
      updateKind: UpdateKind.update,
    );
    if (changed > 0) _notifyChanged();
    return changed > 0;
  }

  @override
  Future<int> detachItems(HealthProfileId babyId, Iterable<PregnancyItemId> items, {HealthProfileId? scope}) async {
    final profile = _require(scope);
    final ids = items.map((i) => i.value).toList();
    if (ids.isEmpty) return 0;
    final placeholders = List.filled(ids.length, '?').join(', ');
    final changed = await _db.customUpdate(
      '''
      UPDATE pregnancy_item_baby SET deleted_at = ?
      WHERE health_profile_id = ? AND deleted_at IS NULL AND item_id IN ($placeholders)
        AND item_id IN (SELECT i.id FROM pregnancy_item i JOIN pregnancy p ON p.id = i.pregnancy_id
                        WHERE p.health_profile_id = ?)''',
      variables: [
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(babyId.value),
        ...ids.map(Variable.withString),
        Variable.withString(profile.value),
      ],
      updateKind: UpdateKind.update,
    );
    if (changed > 0) _notifyChanged();
    return changed;
  }

  // --- Mapping ----------------------------------------------------------------

  static Pregnancy _pregnancy(QueryRow r) {
    final visitOn = _parseDate(r.readNullable<String>('next_visit_on'));
    return Pregnancy(
      id: PregnancyId.value(r.read<String>('id')),
      motherId: HealthProfileId.value(r.read<String>('health_profile_id')),
      dueDate: _parseDate(r.readNullable<String>('due_date')) ?? DateTime.utc(1970),
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at'), isUtc: true),
      obName: r.readNullable<String>('ob_name'),
      obPhone: r.readNullable<String>('ob_phone'),
      nextVisit: visitOn == null
          ? null
          : NextVisit(
              date: visitOn,
              time: r.readNullable<String>('next_visit_time'),
              clinic: r.readNullable<String>('next_visit_clinic'),
            ),
      status: PregnancyStatus.fromWire(r.readNullable<String>('status')),
      closedOn: _parseDate(r.readNullable<String>('closed_on')),
    );
  }

  static PregnancyItem _item(QueryRow r, List<HealthProfileId> babies) => PregnancyItem(
        id: PregnancyItemId.value(r.read<String>('id')),
        pregnancyId: PregnancyId.value(r.read<String>('pregnancy_id')),
        about: ItemAbout.fromWire(r.readNullable<String>('about')),
        babyIds: babies,
        kind: ItemKind.fromWire(r.readNullable<String>('kind')),
        recordedOn: _parseDate(r.readNullable<String>('recorded_on')) ?? DateTime.utc(1970),
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('created_at'), isUtc: true),
        title: r.readNullable<String>('title'),
        fetalHeartRateBpm: r.readNullable<int>('fetal_hr_bpm'),
        estimatedFetalWeightG: r.readNullable<int>('efw_g'),
        otherLabel: r.readNullable<String>('other_label'),
        otherValue: r.readNullable<String>('other_value'),
        attachmentRef: r.readNullable<String>('attachment_ref'),
      );

  /// Calendar dates are stored as ISO `YYYY-MM-DD`.
  static String? _date(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? s) {
    final d = s == null ? null : DateTime.tryParse(s);
    return d == null ? null : DateTime.utc(d.year, d.month, d.day);
  }
}

/// Pregnancies live on the account holder's own (self) profile, whichever
/// profile is active — so the data source is bound to the self profile.
/// Requires [appDatabaseProvider] to be overridden at bootstrap.
final pregnanciesDataSourceProvider = Provider<PregnanciesDataSource>((ref) {
  return DriftPregnanciesDataSource(
    db: ref.watch(appDatabaseProvider),
    activeProfile: () => ref.read(selfProfileIdProvider).valueOrNull,
  );
});
