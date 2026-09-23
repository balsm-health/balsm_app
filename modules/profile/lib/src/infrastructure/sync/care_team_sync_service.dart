import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Converges the on-device care team with the Balsm cloud mirror (FR-500).
///
/// Push is a strict FIFO drain of [SyncOutboxDao]; pull is incremental by
/// `updated_at` cursor and merges row-level last-writer-wins. Local drift stays
/// the write path — this service never sits between the UI and the database, so
/// a screen keeps rendering from its own stream whether or not sync is working.
class CareTeamSyncService {
  CareTeamSyncService({
    required CareTeamApi api,
    required SyncOutboxDao outbox,
    required AppDatabase db,
    required SyncStatusNotifier status,
  })  : _api = api,
        _outbox = outbox,
        _db = db,
        _status = status;

  final CareTeamApi _api;
  final SyncOutboxDao _outbox;
  final AppDatabase _db;
  final SyncStatusNotifier _status;

  static const _entity = 'care_provider';

  bool _inFlight = false;

  /// Drain then pull. Push first so a local edit is never clobbered by a pull
  /// of the row it just changed.
  Future<void> sync(HealthProfileId profileId) async {
    if (_inFlight) return;
    _inFlight = true;
    _status.set(SyncState.syncing);
    try {
      await _drainInner();
      await _pullInner(profileId);
      _status.set(SyncState.synced, lastSyncedAt: DateTime.now());
    } catch (e) {
      _status.set(SyncState.offline, message: e.toString());
    } finally {
      _inFlight = false;
    }
  }

  /// Pushes every queued change, oldest first.
  Future<void> drain() async {
    try {
      await _drainInner();
    } catch (e) {
      _status.set(SyncState.offline, message: e.toString());
    }
  }

  /// Pulls rows changed since the stored cursor and merges them.
  Future<void> pull(HealthProfileId profileId) async {
    try {
      await _pullInner(profileId);
    } catch (e) {
      _status.set(SyncState.offline, message: e.toString());
    }
  }

  Future<void> _drainInner() async {
    for (final entry in await _outbox.pending()) {
      if (entry.entity != _entity) continue;
      try {
        switch (entry.op) {
          case OutboxOp.upsert:
            final json = jsonDecode(entry.payload) as Map<String, dynamic>;
            await _api.upsert(UpsertCareProviderRequest(
              id: json['id'] as String,
              healthProfileId: json['health_profile_id'] as String,
              type: json['type'] as String,
              name: json['name'] as String,
              specialty: json['specialty'] as String?,
              phone: json['phone'] as String?,
              phone2: json['phone2'] as String?,
              email: json['email'] as String?,
              clinic: json['clinic'] as String?,
              address: json['address'] as String?,
              mapUrl: json['map_url'] as String?,
              notes: json['notes'] as String?,
              createdAt: DateTime.parse(json['created_at'] as String),
            ));
          case OutboxOp.delete:
            await _api.delete(entry.entityId);
        }
        await _outbox.complete(entry.id);
      } catch (e) {
        await _outbox.fail(entry.id, e.toString());
        // STOP at the first failure. Skipping ahead would let a delete overtake
        // the upsert that created its row, so the server would tombstone a row
        // it never saw and the next pull would carry that tombstone back.
        rethrow;
      }
    }
  }

  Future<void> _pullInner(HealthProfileId profileId) async {
    final cursor = await _readCursor(profileId);
    final rows = await _api.pull(healthProfileId: profileId.value, since: cursor);
    if (rows.isEmpty) return;

    for (final row in rows) {
      await _merge(row);
    }

    // Advance to the newest updated_at actually applied.
    final newest = rows.map((r) => r.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    await _writeCursor(profileId, newest);
  }

  /// Row-level last-writer-wins on `updated_at`.
  ///
  /// Writes here go straight to drift and deliberately bypass the outbox —
  /// routing a pulled row back through the data source would enqueue an
  /// outbound push for a row that just came FROM the server, and the two sides
  /// would push each other forever.
  Future<void> _merge(CareProviderResponse row) async {
    final local = await _db.customSelect(
      'SELECT updated_at, created_at FROM care_provider WHERE id = ?',
      variables: [Variable.withString(row.id)],
    ).getSingleOrNull();

    if (local != null) {
      final localStampMs = local.readNullable<int>('updated_at') ?? local.read<int>('created_at');
      final localStamp = DateTime.fromMillisecondsSinceEpoch(localStampMs, isUtc: true);
      // Strictly newer wins, so re-pulling rows already applied is a no-op.
      if (!row.updatedAt.isAfter(localStamp)) return;
    }

    if (row.isDeleted) {
      await _db.customStatement('DELETE FROM care_provider WHERE id = ?', [row.id]);
      return;
    }

    Object? opt(String? v) => v == null || v.isEmpty ? null : v;

    await _db.customStatement(
      '''
      INSERT INTO care_provider
        (id, health_profile_id, type, name, specialty, phone, phone2, email,
         clinic, address, map_url, notes, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        type = excluded.type, name = excluded.name, specialty = excluded.specialty,
        phone = excluded.phone, phone2 = excluded.phone2, email = excluded.email,
        clinic = excluded.clinic, address = excluded.address,
        map_url = excluded.map_url, notes = excluded.notes,
        updated_at = excluded.updated_at
      ''',
      [
        row.id,
        row.healthProfileId,
        row.type,
        row.name,
        opt(row.specialty),
        opt(row.phone),
        opt(row.phone2),
        opt(row.email),
        opt(row.clinic),
        opt(row.address),
        opt(row.mapUrl),
        opt(row.notes),
        row.createdAt.millisecondsSinceEpoch,
        row.updatedAt.millisecondsSinceEpoch,
      ],
    );
  }

  Future<DateTime?> _readCursor(HealthProfileId profileId) async {
    final row = await _db.customSelect(
      'SELECT value FROM sync_cursor WHERE entity = ? AND scope = ?',
      variables: [Variable.withString(_entity), Variable.withString(profileId.value)],
    ).getSingleOrNull();
    final raw = row?.readNullable<String>('value');
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> _writeCursor(HealthProfileId profileId, DateTime value) async {
    await _db.customStatement(
      '''
      INSERT INTO sync_cursor (entity, scope, value) VALUES (?, ?, ?)
      ON CONFLICT(entity, scope) DO UPDATE SET value = excluded.value
      ''',
      [_entity, profileId.value, value.toUtc().toIso8601String()],
    );
  }
}

/// Set in bootstrap — needs the network stack and the signed-in user.
final careTeamSyncServiceProvider = Provider<CareTeamSyncService>(
  (ref) => throw UnimplementedError('CareTeamSyncService must be initialized in bootstrap()'),
);
