import 'dart:async';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ports/check_ins_data_source.dart';
import '../../domain/aggregates/check_in.dart';
import '../../domain/value_objects/body_region.dart';
import '../../domain/value_objects/body_tissue.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/value_objects/pain_site.dart';
import '../../domain/value_objects/mood.dart';
import '../../domain/value_objects/pain_level.dart';
import '../../domain/value_objects/symptom.dart';
import '../../domain/value_objects/vitals.dart';

/// `check_in.mood` is `INTEGER NOT NULL` and [Mood] is a 1–5 scale, so 0 is the
/// on-disk marker for "no mood reported" ([CheckIn.mood] `== null`). Confined to
/// this data source — the domain only ever sees a real score or null.
const _moodNotReported = 0;

/// Drift-backed [CheckInsDataSource]. PHI lives on-device only (SQLCipher).
///
/// Partitions on `health_profile_id`. `scope == null` resolves the ACTIVE
/// profile from [activeProfile] (bound to core's `currentProfileIdProvider`);
/// no active profile → mutations throw [NoActiveProfileException], reads
/// return empty. Check-ins are immutable — [put] inserts; [delete] removes an
/// erroneous entry (child rows cascade).
class DriftCheckInsDataSource extends CheckInsDataSource {
  DriftCheckInsDataSource(this._db, this.activeProfile);

  final AppDatabase _db;
  final HealthProfileId? Function() activeProfile;

  final _changes = StreamController<void>.broadcast();
  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  HealthProfileId? _resolve(HealthProfileId? scope) => scope ?? activeProfile();

  HealthProfileId _require(HealthProfileId? scope) {
    final p = _resolve(scope);
    if (p == null) throw const NoActiveProfileException();
    return p;
  }

  // ── Reads ────────────────────────────────────────────────────────────────

  @override
  Future<CheckIn?> find(CheckInId key, {HealthProfileId? scope}) async {
    final p = _resolve(scope);
    if (p == null) return null;
    final rows = await _db.customSelect(
      'SELECT * FROM check_in WHERE id = ? AND health_profile_id = ? LIMIT 1',
      variables: [Variable<String>(key.value), Variable<String>(p.value)],
    ).get();
    if (rows.isEmpty) return null;
    return _hydrate(rows.first.data);
  }

  @override
  Future<List<CheckIn>> findAll({HealthProfileId? scope}) async {
    final p = _resolve(scope);
    if (p == null) return const [];
    final rows = await _db.customSelect(
      'SELECT * FROM check_in WHERE health_profile_id = ? '
      'ORDER BY recorded_at DESC',
      variables: [Variable<String>(p.value)],
    ).get();
    return [for (final r in rows) await _hydrate(r.data)];
  }

  @override
  Future<List<CheckIn>> findMany(Iterable<CheckInId> keys, {HealthProfileId? scope}) async {
    final result = <CheckIn>[];
    for (final k in keys) {
      final c = await find(k, scope: scope);
      if (c != null) result.add(c);
    }
    return result;
  }

  @override
  Future<bool> exists(CheckInId key, {HealthProfileId? scope}) async => await find(key, scope: scope) != null;

  // ── Watch ────────────────────────────────────────────────────────────────

  @override
  Stream<CheckIn?> watch(CheckInId key, {HealthProfileId? scope}) {
    final p = _resolve(scope);
    if (p == null) return Stream.value(null);
    return Stream<CheckIn?>.multi((emitter) async {
      emitter.add(await find(key, scope: p));
      emitter.addStream(_changes.stream.asyncMap((_) => find(key, scope: p)));
    });
  }

  @override
  Stream<List<CheckIn>> watchAll({HealthProfileId? scope}) {
    final p = _resolve(scope);
    if (p == null) return Stream.value(const []);
    return Stream<List<CheckIn>>.multi((emitter) async {
      emitter.add(await findAll(scope: p));
      emitter.addStream(_changes.stream.asyncMap((_) => findAll(scope: p)));
    });
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  @override
  Future<void> put(CheckInId key, CheckIn value, {HealthProfileId? scope}) async {
    final p = _require(scope);
    final v = value.vitals;
    await _db.transaction(() async {
      await _db.customInsert(
        'INSERT OR REPLACE INTO check_in '
        '(id, health_profile_id, recorded_at, mood, pain_level, note, '
        'photo_record_id, systolic, diastolic, heart_rate, temperature, '
        'weight_kg, spo2, glucose_fasting, glucose_post_meal, glucose_random) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        variables: [
          Variable<String>(key.value),
          Variable<String>(p.value),
          Variable<String>(value.recordedAt.toUtc().toIso8601String()),
          Variable<int>(value.mood?.score ?? _moodNotReported),
          Variable<int>(value.painLevel.value),
          Variable<String>(value.note),
          Variable<String>(value.photoRecordId),
          Variable<int>(v.systolic),
          Variable<int>(v.diastolic),
          Variable<int>(v.heartRate),
          Variable<double>(v.temperature),
          Variable<double>(v.weightKg),
          Variable<int>(v.spo2),
          Variable<int>(v.glucoseFasting),
          Variable<int>(v.glucosePostMeal),
          Variable<int>(v.glucoseRandom),
        ],
      );
      // Children: clear then re-insert (idempotent on REPLACE).
      await _db.customUpdate('DELETE FROM check_in_symptom WHERE check_in_id = ?',
          variables: [Variable<String>(key.value)], updateKind: UpdateKind.delete);
      await _db.customUpdate('DELETE FROM check_in_pain_region WHERE check_in_id = ?',
          variables: [Variable<String>(key.value)], updateKind: UpdateKind.delete);
      for (final s in value.symptoms) {
        await _db.customInsert(
          'INSERT INTO check_in_symptom (check_in_id, symptom_id) VALUES (?, ?)',
          variables: [Variable<String>(key.value), Variable<String>(s.id)],
        );
      }
      for (final site in value.painSites) {
        await _db.customInsert(
          'INSERT INTO check_in_pain_region (check_in_id, region_id, tissue_id) VALUES (?, ?, ?)',
          variables: [
            Variable<String>(key.value),
            Variable<String>(site.region.id),
            Variable<String>(site.tissue.id),
          ],
        );
      }
    });
    _notifyChanged();
  }

  @override
  Future<void> putBulk(Map<CheckInId, CheckIn> values, {HealthProfileId? scope}) async {
    final p = _require(scope);
    for (final e in values.entries) {
      await put(e.key, e.value, scope: p);
    }
  }

  @override
  Future<void> delete(CheckInId key, {HealthProfileId? scope}) async {
    final p = _require(scope);
    await _db.customUpdate(
      'DELETE FROM check_in WHERE id = ? AND health_profile_id = ?',
      variables: [Variable<String>(key.value), Variable<String>(p.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> deleteMany(Iterable<CheckInId> keys, {HealthProfileId? scope}) async {
    for (final k in keys) {
      await delete(k, scope: scope);
    }
  }

  @override
  Future<void> clear({HealthProfileId? scope}) async {
    final p = _resolve(scope);
    if (p == null) return; // idempotent logout cleanup
    await _db.customUpdate(
      'DELETE FROM check_in WHERE health_profile_id = ?',
      variables: [Variable<String>(p.value)],
      updateKind: UpdateKind.delete,
    );
    _notifyChanged();
  }

  @override
  Future<void> clearAll() async {
    await _db.customUpdate('DELETE FROM check_in', updateKind: UpdateKind.delete);
    _notifyChanged();
  }

  // ── Hydration ──────────────────────────────────────────────────────────

  Future<CheckIn> _hydrate(Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final symptomRows = await _db.customSelect(
      'SELECT symptom_id FROM check_in_symptom WHERE check_in_id = ?',
      variables: [Variable<String>(id)],
    ).get();
    final regionRows = await _db.customSelect(
      'SELECT region_id, tissue_id FROM check_in_pain_region WHERE check_in_id = ?',
      variables: [Variable<String>(id)],
    ).get();
    return CheckIn(
      id: CheckInId.value(id),
      healthProfileId: HealthProfileId.value(row['health_profile_id'] as String),
      recordedAt: DateTime.parse(row['recorded_at'] as String),
      mood: switch (row['mood'] as int) {
        _moodNotReported => null,
        final score => Mood(score),
      },
      painLevel: PainLevel(row['pain_level'] as int),
      painSites: {
        for (final r in regionRows)
          // Legacy rows predate tissue_id and default to muscle. A pair that no
          // longer resolves (retired location, or one dropped from that layer)
          // is skipped rather than coerced onto a layer it is not on.
          if (BodyRegion.fromId(
            r.read<String>('region_id'),
            BodyTissue.fromId(r.read<String>('tissue_id')) ?? BodyTissue.muscle,
          )
              case final reg?)
            PainSite(reg),
      },
      symptoms: {
        for (final s in symptomRows)
          if (SymptomId.fromId(s.read<String>('symptom_id')) case final sym?) sym,
      },
      vitals: Vitals.fromRow(row),
      note: row['note'] as String?,
      photoRecordId: row['photo_record_id'] as String?,
    );
  }
}

/// Bound to the active profile via core's `currentProfileIdProvider`.
final checkInsDataSourceProvider = Provider<CheckInsDataSource>(
  (ref) => DriftCheckInsDataSource(
    ref.watch(appDatabaseProvider),
    () => ref.read(currentProfileIdProvider),
  ),
);
