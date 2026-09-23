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
    required UserId? Function() activeUser,
    void Function()? onChanged,
  })  : _api = api,
        _outbox = outbox,
        _db = db,
        _status = status,
        _activeUser = activeUser,
        _onChanged = onChanged;

  final CareTeamApi _api;
  final SyncOutboxDao _outbox;
  final AppDatabase _db;
  final SyncStatusNotifier _status;

  /// Whose queue to drain. The outbox is shared by every account that has used
  /// this device, so draining unscoped would push one patient's PHI under the
  /// next patient's token.
  final UserId? Function() _activeUser;

  /// Called after a pull actually changed local rows. `customStatement` does not
  /// notify drift stream queries, so without this the merged rows stay invisible
  /// until the app restarts — pull-to-refresh appears to do nothing.
  final void Function()? _onChanged;

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
    final user = _activeUser();
    if (user == null) return;
    for (final entry in await _outbox.pending(userId: user.value)) {
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
      } on ApiException catch (e) {
        if (_isPermanent(e)) {
          // The server will never accept this entry: a tombstoned id (409), an
          // invalid type (422), a row that is not ours (404). Retrying forever
          // would jam every later change behind it, so drop it and carry on —
          // a 409 in particular is resolved by the pull that follows, which
          // brings the tombstone down and deletes the row locally.
          await _outbox.complete(entry.id);
          continue;
        }
        await _outbox.fail(entry.id, e.toString());
        // Retryable (5xx, offline): STOP here. Skipping ahead would let a delete
        // overtake the upsert that created its row, so the server would tombstone
        // a row it never saw and the next pull would carry that tombstone back.
        rethrow;
      } catch (e) {
        await _outbox.fail(entry.id, e.toString());
        rethrow;
      }
    }
  }

  Future<void> _pullInner(HealthProfileId profileId) async {
    final cursor = await _readCursor(profileId);
    final rows = await _api.pull(healthProfileId: profileId.value, since: cursor);
    if (rows.isEmpty) return;

    var changed = false;
    for (final row in rows) {
      // Rows are keyed to the account, not to a profile: the id this device
      // minted is not the one the row was written under. Map them onto the
      // local profile as they land.
      if (await _merge(row, profileId)) changed = true;
    }

    // Advance to the newest updated_at actually applied.
    final newest = rows.map((r) => r.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    await _writeCursor(profileId, newest);

    if (changed) _onChanged?.call();
  }

  /// Row-level last-writer-wins on `updated_at`.
  ///
  /// Writes here go straight to drift and deliberately bypass the outbox —
  /// routing a pulled row back through the data source would enqueue an
  /// outbound push for a row that just came FROM the server, and the two sides
  /// would push each other forever.
  Future<bool> _merge(CareProviderResponse row, HealthProfileId profileId) async {
    final local = await _db.customSelect(
      'SELECT updated_at, created_at FROM care_provider WHERE id = ?',
      variables: [Variable.withString(row.id)],
    ).getSingleOrNull();

    if (local != null) {
      final localStampMs = local.readNullable<int>('updated_at') ?? local.read<int>('created_at');
      final localStamp = DateTime.fromMillisecondsSinceEpoch(localStampMs, isUtc: true);
      // Strictly newer wins, so re-pulling rows already applied is a no-op.
      if (!row.updatedAt.isAfter(localStamp)) return false;
    }

    if (row.isDeleted) {
      // Nothing local to delete means nothing changed on screen.
      if (local == null) return false;
      await _db.customStatement('DELETE FROM care_provider WHERE id = ?', [row.id]);
      return true;
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
        profileId.value,
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
    return true;
  }

  /// A failure the server will never accept on retry. Keeping these queued jams
  /// every later change behind them forever; 408 and 429 are explicitly NOT
  /// permanent — those mean "try again".
  static bool _isPermanent(ApiException e) {
    final code = e.statusCode;
    if (code == null) return false;
    if (code == 408 || code == 429) return false;
    return code >= 400 && code < 500;
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

/// Care-team sync status, deliberately SEPARATE from `syncStatusProvider`.
///
/// That one is the Drive backup's state and is rendered as "Backed up / Synced"
/// on the storage sheet. Stamping it here told a patient with no Drive session —
/// the exact person this feature exists for — that their data was backed up when
/// it was not, and masked real backup failures for everyone else.
final careTeamSyncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) => SyncStatusNotifier());

/// Set in bootstrap — needs the network stack and the signed-in user.
final careTeamSyncServiceProvider = Provider<CareTeamSyncService>(
  (ref) => throw UnimplementedError('CareTeamSyncService must be initialized in bootstrap()'),
);
