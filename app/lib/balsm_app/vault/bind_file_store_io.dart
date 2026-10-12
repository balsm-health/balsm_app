import 'dart:io';

import 'package:core/core.dart';
import 'package:path_provider/path_provider.dart';

Future<UserFileStore> createUserFileStore({
  required UserId? Function() activeUser,
  required SecureStorageWrapper keychain,
}) async {
  final docs = await getApplicationDocumentsDirectory();
  return EncryptedFileStore.withKeychainKey(
    root: Directory('${docs.path}/vault'),
    activeUser: activeUser,
    keychain: keychain,
  );
}
