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

  /// Hands every file owned by [from] to [to] — the files and whatever
  /// decrypts them — when an account's id changes (a device-only account
  /// going online under a new server id). Idempotent: nothing left under
  /// [from] is a no-op. Throws [StateError] if [to] already owns files;
  /// combining two owners' files is not this method's job.
  Future<void> rekeyOwnerFiles({required String from, required String to});

  /// Merges every file owned by [from] into [to], which may already own files
  /// of its own (an offline account merged into an existing one). When [to]
  /// has nothing yet this is [rekeyOwnerFiles]; otherwise each of [from]'s
  /// files is re-written under [to] (and [to]'s key), then [from]'s partition
  /// and key are removed. Idempotent, and resumable after a crash part-way.
  Future<void> mergeOwnerFiles({required String from, required String to});

  /// Removes every file owned by [owner] and whatever decrypts them (an
  /// offline account's data discarded). Idempotent.
  Future<void> deleteOwnerFiles({required String owner});
}
