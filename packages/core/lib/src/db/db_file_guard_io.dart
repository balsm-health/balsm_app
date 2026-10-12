import 'dart:io';

/// The first 16 bytes of every plaintext SQLite database file.
const _plainSqliteHeader = 'SQLite format 3\u0000';

/// True when [file] starts with the plaintext SQLite header. A SQLCipher
/// database is encrypted from byte 0, so it never matches.
bool isPlaintextSqlite(File file) {
  if (!file.existsSync()) return false;
  final raf = file.openSync();
  try {
    final head = raf.readSync(_plainSqliteHeader.length);
    return String.fromCharCodes(head) == _plainSqliteHeader;
  } finally {
    raf.closeSync();
  }
}

/// Called when there is no stored DB key. A plaintext database left by a
/// pre-encryption build can't be opened with a key and holds nothing worth
/// migrating (spec D7), so it is deleted, as is an empty file. Anything else on disk is an
/// encrypted database whose key went missing: deleting it would silently
/// destroy data, so this throws instead.
void prepareDbFileForNewKey(File file) {
  if (!file.existsSync()) return;
  // An empty file holds no data under any key.
  if (file.lengthSync() > 0 && !isPlaintextSqlite(file)) {
    throw StateError('database key missing for an existing encrypted database');
  }
  file.deleteSync();
}
