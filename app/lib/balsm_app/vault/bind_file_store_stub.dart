import 'package:core/core.dart';

import 'memory_file_store.dart';

Future<UserFileStore> createUserFileStore({
  required UserId? Function() activeUser,
  required SecureStorageWrapper keychain,
}) async =>
    MemoryUserFileStore();
