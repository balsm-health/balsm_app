import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../secure_storage/secure_storage_wrapper.dart';
import 'db_file_guard_io.dart';
import 'db_key.dart';

/// Whether the on-device database can be opened, checked before it is.
///
/// [DbKeyStatus.lost] means an encrypted `balsm.db` is on disk and its key is
/// not in secure storage. The executor refuses to open it (minting a new key
/// would orphan the data silently), so every query would fail: the app must
/// ask the patient what to do first. It happens when the keychain no longer
/// hands the key back, e.g. after the iOS app moved to another Apple team,
/// whose builds cannot read the previous team's keychain items.
///
/// [storage] and [documents] are for tests.
Future<DbKeyStatus> checkDbKey({FlutterSecureStorage? storage, Directory? documents}) async {
  final store = storage ?? SecureStorageWrapper.storage;
  if (await store.read(key: kDbKeyStorageKey) != null) return DbKeyStatus.ok;
  final docs = documents ?? await getApplicationDocumentsDirectory();
  return isEncryptedDatabase(File('${docs.path}/$kDbFileName')) ? DbKeyStatus.lost : DbKeyStatus.ok;
}

/// Moves the database the app can no longer open, and the encrypted files
/// whose keys went with it, out of the way, so the app starts empty. Nothing
/// is deleted: each item is renamed to `<name>.lost-<UTC timestamp>` in place.
///
/// Only after the patient chose to start fresh ([checkDbKey] said
/// [DbKeyStatus.lost]). [documents] and [now] are for tests.
Future<void> setAsideUnreadableData({Directory? documents, DateTime? now}) async {
  final docs = documents ?? await getApplicationDocumentsDirectory();
  final suffix = '.lost-${_stamp((now ?? DateTime.now()).toUtc())}';
  for (final name in [kDbFileName, '$kDbFileName-wal', '$kDbFileName-shm', '$kDbFileName-journal']) {
    final file = File('${docs.path}/$name');
    if (file.existsSync()) file.renameSync('${file.path}$suffix');
  }
  final vault = Directory('${docs.path}/$kVaultDirName');
  if (vault.existsSync()) vault.renameSync('${vault.path}$suffix');
}

/// `20261126T213000Z`: sortable, and safe in a file name on every platform.
String _stamp(DateTime utc) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}
