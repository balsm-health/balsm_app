import 'package:core/core.dart';

Future<UserFileStore> createUserFileStore({
  required UserId? Function() activeUser,
  required SecureStorageWrapper keychain,
}) async =>
    createWebFileStore(activeUser: activeUser, keychain: keychain);
