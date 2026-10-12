import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/value_objects/user_id.dart';
import '../../secure_storage/secure_storage_wrapper.dart';
import '../../web/idb.dart';
import '../file_store.dart';
import '../storage_exceptions.dart';

UserFileStore createWebFileStore({
  required UserId? Function() activeUser,
  required SecureStorageWrapper keychain,
}) =>
    WebEncryptedFileStore(activeUser: activeUser, keychain: keychain);

/// The browser counterpart of `EncryptedFileStore`: same contract, same
/// AES-256-GCM record (`nonce(12) ‖ ciphertext ‖ mac(16)`), same per-user key
/// under `balsm.file_key.<userId>` in secure storage. Records live in
/// IndexedDB under `<userId>/<fileName>.enc` instead of on a file system.
///
/// The browser may evict this storage; see database_connection_web.dart.
class WebEncryptedFileStore implements UserFileStore {
  WebEncryptedFileStore({required this.activeUser, required SecureStorageWrapper keychain}) : _keychain = keychain;

  static const _files = 'files';

  /// Resolves the active user at call time (null = signed out).
  final UserId? Function() activeUser;
  final SecureStorageWrapper _keychain;
  final _idb = Idb('balsm.files', const [_files]);

  static final _cipher = AesGcm.with256bits();

  static String _keyId(String userId) => 'balsm.file_key.$userId';

  Future<List<int>> _keyFor(UserId user) async {
    final id = _keyId(user.value);
    final existing = await _keychain.readToken(id);
    if (existing != null && existing.isNotEmpty) return base64Decode(existing);
    final bytes = await (await _cipher.newSecretKey()).extractBytes();
    await _keychain.writeToken(id, base64Encode(bytes));
    return bytes;
  }

  UserId? _resolve(UserId? scope) => scope ?? activeUser();

  UserId _require(UserId? scope) {
    final user = _resolve(scope);
    if (user == null) throw const NoActiveUserException();
    return user;
  }

  /// Accepts the path [save] returned (`<user>/<name>.enc`) or a bare name;
  /// either way the record stays inside the user's partition.
  String _recordKey(UserId user, String relativeOrName) {
    final name = relativeOrName.split('/').last;
    if (name.isEmpty || name == '..' || relativeOrName.contains('..')) {
      throw StorageWriteException('invalid file path "$relativeOrName"');
    }
    return '${user.value}/$name';
  }

  Future<Uint8List?> _raw(String key) async {
    final stored = await _idb.run<JSAny?>(_files, (s) => s.get(key.toJS));
    return stored == null ? null : (stored as JSUint8Array).toDart;
  }

  Future<List<String>> _recordKeys(String userId) async {
    final keys = await _idb.run<JSArray<JSAny?>>(_files, (s) => s.getAllKeys(Idb.prefixed('$userId/')));
    return [for (final key in keys.toDart) (key as JSString).toDart];
  }

  Future<void> _dropPartition(String userId) =>
      _idb.run<JSAny?>(_files, (s) => s.delete(Idb.prefixed('$userId/')), write: true);

  @override
  Future<String> save(String fileName, Uint8List bytes, {UserId? scope}) async {
    final user = _require(scope);
    try {
      final box = await _cipher.encrypt(bytes, secretKey: SecretKey(await _keyFor(user)));
      final key = _recordKey(user, '$fileName.enc');
      await _idb.run<JSAny?>(_files, (s) => s.put(box.concatenation().toJS, key.toJS), write: true);
      return key;
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageWriteException('save "$fileName" failed', e);
    }
  }

  @override
  Future<Uint8List?> read(String path, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return null;
    final raw = await _raw(_recordKey(user, path));
    if (raw == null) return null;
    try {
      final box = SecretBox.fromConcatenation(raw, nonceLength: 12, macLength: 16);
      return Uint8List.fromList(await _cipher.decrypt(box, secretKey: SecretKey(await _keyFor(user))));
    } catch (e) {
      if (e is StorageException) rethrow;
      // Wrong key, truncated record, MAC failure — present but unreadable.
      throw StorageDecodeException('file "$path": undecryptable', e);
    }
  }

  @override
  Future<bool> exists(String path, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return false;
    return await _raw(_recordKey(user, path)) != null;
  }

  @override
  Future<void> delete(String path, {UserId? scope}) async {
    final user = _require(scope);
    final key = _recordKey(user, path);
    try {
      await _idb.run<JSAny?>(_files, (s) => s.delete(key.toJS), write: true);
    } catch (e) {
      throw StorageWriteException('delete "$path" failed', e);
    }
  }

  @override
  Future<void> clear({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return; // idempotent logout cleanup
    try {
      await _dropPartition(user.value);
    } catch (e) {
      throw StorageWriteException('clear partition failed', e);
    }
  }

  /// Moves every record and the file key from [from] to [to]. Each half is
  /// skipped when its source is already gone, so a retry after an interrupted
  /// run finishes the job. An unrelated key or any record already under [to]
  /// throws [StateError].
  @override
  Future<void> rekeyOwnerFiles({required String from, required String to}) async {
    _checkIds([from, to]);
    if (from == to) return;
    final fromKey = await _keychain.readToken(_keyId(from));
    final toKey = await _keychain.readToken(_keyId(to));
    final records = await _recordKeys(from);
    if (fromKey != null && toKey != null && toKey != fromKey) {
      throw StateError('target owner already has files');
    }
    // A resumed move has already carried some records over under the same key.
    if (records.isNotEmpty && toKey != fromKey && (await _recordKeys(to)).isNotEmpty) {
      throw StateError('target owner already has files');
    }
    if (fromKey != null && toKey == null) await _keychain.writeToken(_keyId(to), fromKey);
    for (final key in records) {
      final raw = await _raw(key);
      if (raw != null) {
        final moved = '$to/${key.split('/').last}';
        await _idb.run<JSAny?>(_files, (s) => s.put(raw.toJS, moved.toJS), write: true);
      }
      await _idb.run<JSAny?>(_files, (s) => s.delete(key.toJS), write: true);
    }
    if (fromKey != null) await _keychain.deleteToken(_keyId(from));
  }

  /// A target with neither a key nor records takes [from]'s wholesale.
  /// Otherwise each record is decrypted with [from]'s key, saved under [to]'s
  /// and removed, one at a time; an undecryptable record is dropped.
  @override
  Future<void> mergeOwnerFiles({required String from, required String to}) async {
    _checkIds([from, to]);
    if (from == to) return;
    if (await _keychain.readToken(_keyId(to)) == null && (await _recordKeys(to)).isEmpty) {
      return rekeyOwnerFiles(from: from, to: to);
    }
    final src = UserId.value(from);
    final dst = UserId.value(to);
    for (final key in await _recordKeys(from)) {
      final name = key.split('/').last;
      Uint8List? bytes;
      try {
        bytes = await read(name, scope: src);
      } on StorageDecodeException {
        bytes = null;
      }
      if (bytes != null && name.endsWith('.enc')) await save(name.substring(0, name.length - 4), bytes, scope: dst);
      await _idb.run<JSAny?>(_files, (s) => s.delete(key.toJS), write: true);
    }
    await _keychain.deleteToken(_keyId(from));
  }

  @override
  Future<void> deleteOwnerFiles({required String owner}) async {
    _checkIds([owner]);
    try {
      await _dropPartition(owner);
    } catch (e) {
      throw StorageWriteException('delete owner files failed', e);
    }
    await _keychain.deleteToken(_keyId(owner));
  }

  static void _checkIds(List<String> ids) {
    for (final id in ids) {
      if (id.isEmpty || id == '.' || id == '..' || id.contains('/') || id.contains(r'\')) {
        throw ArgumentError.value('<redacted>', 'id', 'must be a single path segment');
      }
    }
  }
}
