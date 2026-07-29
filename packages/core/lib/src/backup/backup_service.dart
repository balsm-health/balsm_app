import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../event_bus/event_bus.dart';
import '../secure_storage/secure_storage_wrapper.dart';
import 'backup_adapter.dart';
import 'blob_codec.dart';
import 'recovery_code.dart';
import 'snapshot_service.dart';
import 'sync_status.dart';

/// Orchestrates encrypted backup: consumes `backup_flush_requested` (emitted by
/// [BackupDebouncer]), snapshots the PHI DB, encrypts it with the user's
/// recovery code, and uploads the blob to their cloud. Offline-resilient — a
/// failed upload marks the backup dirty and retries when connectivity returns.
class BackupService {
  BackupService({
    required EventBus bus,
    required SnapshotPort snapshot,
    required BackupAdapter adapter,
    required SecureStorageWrapper storage,
    required SyncStatusNotifier status,
    required this.userId,
    Stream<bool>? onlineStream,
  })  : _bus = bus,
        _snapshot = snapshot,
        _adapter = adapter,
        _storage = storage,
        _status = status {
    _flushSub = _bus.events.where((e) => e.eventName == 'backup_flush_requested').listen((_) => flush());
    _onlineSub = onlineStream?.listen((online) {
      if (online) _retryIfDirty();
    });
  }

  static const _kRecovery = 'balsm.backup.recovery';
  static const _kSalt = 'balsm.backup.salt';
  static const _kDirty = 'balsm.backup.dirty';
  static const _kLast = 'balsm.backup.last';

  final EventBus _bus;
  final SnapshotPort _snapshot;
  final BackupAdapter _adapter;
  final SecureStorageWrapper _storage;
  final SyncStatusNotifier _status;
  final String userId;

  StreamSubscription? _flushSub;
  StreamSubscription? _onlineSub;
  bool _inFlight = false;

  String get blobKey => 'balsm-backup-$userId.aes';

  /// Ensures a recovery code + salt exist. Returns the **plaintext recovery
  /// code to show the user once** when freshly generated, else null. Call from
  /// onboarding so the user can write it down (it's the only key to their data).
  Future<String?> provisionIfNeeded() async {
    final existing = await _storage.readToken(_kRecovery);
    if (existing != null) return null;
    final code = RecoveryCode.generate();
    final salt = BackupCodec.newSalt();
    await _storage.writeToken(_kRecovery, code);
    await _storage.writeToken(_kSalt, base64Encode(salt));
    return code;
  }

  /// Whether this device already holds the recovery code (set up or restored).
  Future<bool> isProvisioned() async => await _storage.readToken(_kRecovery) != null;

  /// The current recovery code (to re-show in settings). Null if not set up.
  Future<String?> revealCode() => _storage.readToken(_kRecovery);

  /// User-triggered immediate backup.
  Future<void> backUpNow() => flush();

  /// Generates a fresh recovery code + salt and re-uploads the backup under the
  /// new key (the old blob is replaced on next upload). Returns the new code to
  /// show the user once. Invalidates any previously saved code.
  Future<String> rotate() async {
    final code = RecoveryCode.generate();
    final salt = BackupCodec.newSalt();
    await _storage.writeToken(_kRecovery, code);
    await _storage.writeToken(_kSalt, base64Encode(salt));
    await flush();
    return code;
  }

  /// Snapshot → encrypt → upload. Safe to call repeatedly; coalesces.
  Future<void> flush() async {
    if (_inFlight) return;
    final code = await _storage.readToken(_kRecovery);
    final saltB64 = await _storage.readToken(_kSalt);
    if (code == null || saltB64 == null) return; // not set up yet
    _inFlight = true;
    _status.set(SyncState.syncing);
    try {
      final json = await _snapshot.export();
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
      final blob = await BackupCodec.encrypt(bytes, RecoveryCode.normalize(code), salt: base64Decode(saltB64));
      await _adapter.upload(blob, blobKey);
      final now = DateTime.now();
      await _storage.writeToken(_kLast, now.toIso8601String());
      await _storage.deleteToken(_kDirty);
      _status.set(SyncState.synced, lastSyncedAt: now);
    } catch (e) {
      await _storage.writeToken(_kDirty, '1');
      // Treat any upload failure as "will retry"; surface message for error UI.
      _status.set(SyncState.offline, message: e.toString());
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _retryIfDirty() async {
    if (await _storage.readToken(_kDirty) == '1') await flush();
  }

  /// Restores last-known status on startup (e.g. show "Synced · <time>").
  Future<void> hydrateStatus() async {
    final last = await _storage.readToken(_kLast);
    final dirty = await _storage.readToken(_kDirty) == '1';
    final ts = last == null ? null : DateTime.tryParse(last);
    _status.set(dirty ? SyncState.offline : (ts != null ? SyncState.synced : SyncState.idle), lastSyncedAt: ts);
  }

  void dispose() {
    _flushSub?.cancel();
    _onlineSub?.cancel();
  }
}

/// Set in bootstrap (needs the platform [BackupAdapter] + signed-in userId).
final backupServiceProvider = Provider<BackupService>(
  (ref) => throw UnimplementedError('BackupService must be initialized in bootstrap()'),
);
