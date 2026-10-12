import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

import '../secure_storage/secure_storage_wrapper.dart';
import '../web/tab_claim.dart';
import 'db_key.dart';

/// Encrypted SQLite build (SQLite3 Multiple Ciphers) served next to the app.
/// Must match the pinned package:sqlite3 version — see docs/web-app.md.
const _sqliteWasm = 'sqlite3mc.wasm';

/// IndexedDB database holding the encrypted file's pages.
const _fileSystemName = 'balsm.db';

/// Web executor: the same schema and raw SQL as native, on SQLite compiled to
/// WebAssembly, encrypted with the key in secure storage, persisted to
/// IndexedDB.
///
/// It runs on the main thread, not a worker: the key has to be applied in the
/// context that opens the file, and the database is small. The cost is that
/// only one tab can hold it, which [claimDatabaseTab] enforces.
///
/// A browser may evict this storage (Safari: about a week without a visit).
/// Web data is only as durable as its backup or sync.
QueryExecutor openExecutor() => LazyDatabase(() async {
      // The shell shows the "open in another tab" screen for this case; the
      // throw is what actually keeps the losing tab off the data.
      if (!await claimDatabaseTab()) throw StateError('Balsm is already open in another tab');
      const storage = SecureStorageWrapper.storage;
      final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse(_sqliteWasm));
      final files = await IndexedDbFileSystem.open(dbName: _fileSystemName);
      sqlite.registerVirtualFileSystem(files, makeDefault: true);

      var key = await storage.read(key: kDbKeyStorageKey);
      if (key == null) {
        // Same rule as native: never mint a new key over existing encrypted
        // pages, that would silently orphan the data.
        if (files.xAccess('/$_fileSystemName', 0) != 0) {
          throw StateError('database key missing for an existing encrypted database');
        }
        key = generateDbKeyHex();
        await storage.write(key: kDbKeyStorageKey, value: key);
      }
      if (!isValidDbKeyHex(key)) throw StateError('stored database key is malformed');
      final hexKey = key;
      return WasmDatabase(
        sqlite3: _EncryptedOpen(sqlite, files.name),
        path: '/$_fileSystemName',
        // Passing the file system makes drift flush to IndexedDB after each
        // write, so a closed tab does not lose the last change.
        fileSystem: files,
        setup: (db) {
          db.execute("PRAGMA key = '$hexKey'");
          // Plain sqlite3.wasm returns no row here and would store plaintext.
          if (db.select('PRAGMA cipher').isEmpty) {
            throw StateError('encrypted SQLite not loaded; refusing to open an unencrypted database');
          }
        },
      );
    });

/// drift opens the file on the default file system, which cannot encrypt.
/// SQLite3 Multiple Ciphers registers an encrypting twin of every file system
/// as `multipleciphers-<name>`; this routes drift's open through it.
final class _EncryptedOpen implements CommonSqlite3 {
  _EncryptedOpen(this._inner, String fileSystemName) : _vfs = 'multipleciphers-$fileSystemName';

  final CommonSqlite3 _inner;
  final String _vfs;

  @override
  CommonDatabase open(
    String filename, {
    String? vfs,
    OpenMode mode = OpenMode.readWriteCreate,
    bool uri = false,
    bool? mutex,
  }) =>
      _inner.open(filename, vfs: vfs ?? _vfs, mode: mode, uri: uri, mutex: mutex);

  @override
  CommonDatabase openInMemory({String? vfs}) => _inner.openInMemory(vfs: vfs);

  @override
  Version get version => _inner.version;

  @override
  String? get tempDirectory => _inner.tempDirectory;

  @override
  set tempDirectory(String? value) => _inner.tempDirectory = value;

  @override
  void registerVirtualFileSystem(VirtualFileSystem vfs, {bool makeDefault = false}) =>
      _inner.registerVirtualFileSystem(vfs, makeDefault: makeDefault);

  @override
  void unregisterVirtualFileSystem(VirtualFileSystem vfs) => _inner.unregisterVirtualFileSystem(vfs);
}
