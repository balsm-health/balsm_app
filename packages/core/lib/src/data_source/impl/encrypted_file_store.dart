import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/value_objects/user_id.dart';
import '../../secure_storage/secure_storage_wrapper.dart';
import '../file_store.dart';
import '../storage_exceptions.dart';

/// [UserFileStore] with AES-256-GCM encryption at rest.
///
/// Layout: `<root>/<userId>/<fileName>.enc`, each file stored as the
/// SecretBox concatenation `nonce(12) ‖ ciphertext ‖ mac(16)`. The per-user
/// file key is minted on first use and injected via [keyFor] — production
/// wiring keeps it in the OS keychain ([EncryptedFileStore.withKeychainKey]);
/// tests inject a fixed key and a temp directory.
///
/// The [root] directory is injected too (composition root passes the app
/// documents dir), so core stays free of path_provider.
class EncryptedFileStore implements UserFileStore {
  EncryptedFileStore({
    required this.root,
    required this.activeUser,
    required this.keyFor,
  });

  /// Production factory: 32-byte per-user key persisted in the keychain
  /// under `balsm.file_key.<userId>` (secrets tier — never the DB or prefs).
  factory EncryptedFileStore.withKeychainKey({
    required Directory root,
    required UserId? Function() activeUser,
    required SecureStorageWrapper keychain,
  }) {
    return EncryptedFileStore(
      root: root,
      activeUser: activeUser,
      keyFor: (user) async {
        final id = 'balsm.file_key.${user.value}';
        final existing = await keychain.readToken(id);
        if (existing != null && existing.isNotEmpty) {
          return base64Decode(existing);
        }
        final key = await AesGcm.with256bits().newSecretKey();
        final bytes = await key.extractBytes();
        await keychain.writeToken(id, base64Encode(bytes));
        return bytes;
      },
    );
  }

  final Directory root;

  /// Resolves the active user at call time (null = signed out).
  final UserId? Function() activeUser;

  /// Returns the user's 32-byte file key (minting it if needed).
  final Future<List<int>> Function(UserId user) keyFor;

  static final _cipher = AesGcm.with256bits();

  UserId? _resolve(UserId? scope) => scope ?? activeUser();

  UserId _require(UserId? scope) {
    final user = _resolve(scope);
    if (user == null) throw const NoActiveUserException();
    return user;
  }

  Directory _partition(UserId user) =>
      Directory('${root.path}${Platform.pathSeparator}${user.value}');

  File _file(UserId user, String relativeOrName) {
    // Accept both the relative path returned by [save] ('<user>/<name>.enc')
    // and a bare name; either way the resolved file must stay inside the
    // user's partition (no traversal).
    final name = relativeOrName.split('/').last;
    if (name.isEmpty || name == '..' || relativeOrName.contains('..')) {
      throw StorageWriteException('invalid file path "$relativeOrName"');
    }
    return File('${_partition(user).path}${Platform.pathSeparator}$name');
  }

  @override
  Future<String> save(String fileName, Uint8List bytes,
      {UserId? scope}) async {
    final user = _require(scope);
    try {
      final key = SecretKey(await keyFor(user));
      final box = await _cipher.encrypt(bytes, secretKey: key);
      final file = _file(user, '$fileName.enc');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(box.concatenation(), flush: true);
      return '${user.value}/$fileName.enc';
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageWriteException('save "$fileName" failed', e);
    }
  }

  @override
  Future<Uint8List?> read(String path, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return null;
    final file = _file(user, path);
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsBytes();
      final box = SecretBox.fromConcatenation(raw,
          nonceLength: 12, macLength: 16);
      final key = SecretKey(await keyFor(user));
      final clear = await _cipher.decrypt(box, secretKey: key);
      return Uint8List.fromList(clear);
    } catch (e) {
      if (e is StorageException) rethrow;
      // Wrong key, truncated file, MAC failure — present but unreadable.
      throw StorageDecodeException('file "$path": undecryptable', e);
    }
  }

  @override
  Future<bool> exists(String path, {UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return false;
    return _file(user, path).exists();
  }

  @override
  Future<void> delete(String path, {UserId? scope}) async {
    final user = _require(scope);
    final file = _file(user, path);
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      throw StorageWriteException('delete "$path" failed', e);
    }
  }

  @override
  Future<void> clear({UserId? scope}) async {
    final user = _resolve(scope);
    if (user == null) return; // idempotent logout cleanup
    final dir = _partition(user);
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      throw StorageWriteException('clear partition failed', e);
    }
  }
}
