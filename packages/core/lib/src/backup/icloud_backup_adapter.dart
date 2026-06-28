import 'dart:typed_data';
import 'backup_adapter.dart';

/// iOS backup blob store (iCloud).
///
/// NOTE: the previous `cloud_kit` plugin was removed — its Android module used
/// the deleted Flutter v1 embedding and broke the Android build, and the
/// package is unmaintained. This is a stub pending a maintained iCloud
/// key-value plugin (or a platform channel into CloudKit/NSUbiquitousKeyValue).
/// `BackupAdapter` is only wired on iOS; calls throw until reimplemented.
class ICloudBackupAdapter implements BackupAdapter {
  @override
  Future<void> upload(Uint8List blob, String key) async =>
      throw UnimplementedError('iCloud backup pending a maintained plugin.');

  @override
  Future<Uint8List?> download(String key) async =>
      throw UnimplementedError('iCloud backup pending a maintained plugin.');

  @override
  Future<bool> hasBackup(String key) async => false;
}
