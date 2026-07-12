import 'dart:typed_data';

import '../domain/value_objects/user_id.dart';
import 'storage_exceptions.dart';

/// User-partitioned blob storage for on-device documents (record PDFs,
/// scan images). Deliberately NOT a `DataSource<K, V>`: blobs break that
/// contract's assumptions (`findAll` returning every value would load all
/// documents into memory; bytes have no decode-checked shape; bulk writes
/// aren't transactional on a filesystem). Metadata stays in a DataSource
/// row (e.g. `RecordDocument.filePath`); this port owns only the bytes.
///
/// Scope semantics match `ScopedDataSource`:
/// - `scope == null` → the ACTIVE user; no active user → mutations throw
///   [NoActiveUserException], reads return null/false, [clear] is an
///   idempotent no-op.
/// - Partition = per-user directory; one user's files are unreachable from
///   another's session.
///
/// PHI rule: implementations MUST encrypt at rest (the DB is SQLCipher-
/// protected; loose plaintext files would break the on-device story).
abstract class UserFileStore {
  /// Writes [bytes] under the user's partition and returns the RELATIVE
  /// path to persist in metadata. [fileName] should already be unique
  /// (e.g. `<recordId>.pdf`).
  Future<String> save(String fileName, Uint8List bytes, {UserId? scope});

  /// Reads a blob previously written by [save]; null when absent.
  /// A present-but-undecryptable file throws [StorageDecodeException].
  Future<Uint8List?> read(String path, {UserId? scope});

  Future<bool> exists(String path, {UserId? scope});

  /// Removes one blob (no-op when absent).
  Future<void> delete(String path, {UserId? scope});

  /// Removes the user's whole partition (logout / account deletion wipe).
  Future<void> clear({UserId? scope});
}
