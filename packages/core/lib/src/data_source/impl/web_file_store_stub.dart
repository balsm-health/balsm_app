import '../../domain/value_objects/user_id.dart';
import '../../secure_storage/secure_storage_wrapper.dart';
import '../file_store.dart';

/// Only the web build has a browser file store; native uses EncryptedFileStore.
UserFileStore createWebFileStore({
  required UserId? Function() activeUser,
  required SecureStorageWrapper keychain,
}) =>
    throw UnsupportedError('createWebFileStore is web only');
