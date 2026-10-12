import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../secure_storage/secure_storage_wrapper.dart';
import 'backup_adapter.dart';
import 'blob_codec.dart';
import 'recovery_code.dart';
import 'snapshot_service.dart';

/// Detects and restores an encrypted backup on a new device (US1b). The user
/// supplies their recovery code; we download, decrypt, and merge into the local
/// PHI DB, then persist the code + salt so this device can back up going forward.
class RestoreService {
  RestoreService({
    required BackupAdapter adapter,
    required SnapshotPort snapshot,
    required SecureStorageWrapper storage,
    required this.userId,
  })  : _adapter = adapter,
        _snapshot = snapshot,
        _storage = storage;

  static const _kRecovery = 'balsm.backup.recovery';
  static const _kSalt = 'balsm.backup.salt';

  final BackupAdapter _adapter;
  final SnapshotPort _snapshot;
  final SecureStorageWrapper _storage;
  final String userId;

  String get blobKey => 'balsm-backup-$userId.aes';

  /// Whether a backup exists in the user's cloud for this account.
  Future<bool> hasBackup() => _adapter.hasBackup(blobKey);

  /// Downloads, decrypts with [recoveryCode], and merges into the local DB.
  /// Throws [BackupDecryptException] if the code is wrong, or [StateError] if
  /// no backup is found.
  Future<void> restore(String recoveryCode) async {
    final blob = await _adapter.download(blobKey);
    if (blob == null) throw StateError('No backup found');
    final code = RecoveryCode.normalize(recoveryCode);
    final clear = await BackupCodec.decrypt(blob, code); // throws on wrong code
    final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    await _snapshot.import(json);
    // Persist credentials so this device keeps the backup current.
    await _storage.writeToken(_kRecovery, recoveryCode);
    await _storage.writeToken(_kSalt, base64Encode(_saltFromBlob(blob)));
  }

  /// Reads the salt out of the blob header: magic(4) | ver(1) | saltLen(1) | salt.
  static Uint8List _saltFromBlob(Uint8List blob) {
    final saltLen = blob[5];
    return blob.sublist(6, 6 + saltLen);
  }
}

/// Set in bootstrap (needs the platform [BackupAdapter] + signed-in userId).
final restoreServiceProvider = Provider<RestoreService>(
  (ref) => throw UnimplementedError('RestoreService must be initialized in bootstrap()'),
);
