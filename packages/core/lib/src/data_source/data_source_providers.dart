import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_store.dart';
import 'key_value_data_source.dart';

/// App-wide key-value store port. Bound in the composition root
/// (`bootstrap()`), e.g. to `SharedPrefsKVDataSource` — see that class for
/// the wiring snippet. Presentation-layer concern: business logic receives
/// the data source via constructor injection, not via this provider.
final globalKVDataSourceProvider = Provider<GlobalKVDataSource>(
  (ref) => throw UnimplementedError(
    'globalKVDataSourceProvider must be overridden in bootstrap()',
  ),
);

/// Current user's key-value store port (settings/prefs/drafts, wiped on
/// logout). Bound in the composition root once a scoped implementation
/// exists (sembast / drift kv table).
final userKVDataSourceProvider = Provider<UserKVDataSource>(
  (ref) => throw UnimplementedError(
    'userKVDataSourceProvider must be overridden in bootstrap()',
  ),
);

/// Encrypted per-user blob storage port (record documents). Bound in the
/// composition root, e.g.:
///
/// ```dart
/// final docs = await getApplicationDocumentsDirectory(); // bootstrap()
/// userFileStoreProvider.overrideWithValue(
///   EncryptedFileStore.withKeychainKey(
///     root: Directory('${docs.path}/vault'),
///     activeUser: () => container.read(currentUserIdProvider),
///     keychain: SecureStorageWrapper(),
///   ),
/// );
/// ```
final userFileStoreProvider = Provider<UserFileStore>(
  (ref) => throw UnimplementedError(
    'userFileStoreProvider must be overridden in bootstrap()',
  ),
);
