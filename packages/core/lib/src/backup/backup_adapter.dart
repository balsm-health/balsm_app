import 'dart:typed_data';

abstract interface class BackupAdapter {
  Future<void> upload(Uint8List blob, String key);
  Future<Uint8List?> download(String key);
  Future<bool> hasBackup(String key);
}
