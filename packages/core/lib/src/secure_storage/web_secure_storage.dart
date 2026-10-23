import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:web/web.dart' as web;

import '../web/idb.dart';

/// Replaces the stock web backend of flutter_secure_storage, so every
/// `SecureStorageWrapper.storage` caller gets it without changes. Call once at
/// startup, before the first read.
///
/// Why not the stock backend: it keeps its AES key exported in localStorage
/// next to the ciphertext, and its `deleteAll` empties the whole of
/// localStorage (shared_preferences included).
void installWebSecureStorage() {
  FlutterSecureStoragePlatform.instance = WebSecureStorage();
}

/// Secrets encrypted with an AES-GCM key the browser holds as a
/// NON-EXTRACTABLE `CryptoKey` in IndexedDB: script on this origin can use the
/// key, nothing can read its bytes. That protects a copied profile directory
/// or a storage dump; it does not protect against script running on the
/// origin, or someone sitting at an unlocked browser.
class WebSecureStorage extends FlutterSecureStoragePlatform {
  static const _dbName = 'balsm.secure';
  static const _values = 'kv';
  static const _keys = 'key';
  static const _wrapKeyId = 'wrap.v1';
  static const _ivLength = 12;

  final _idb = Idb(_dbName, const [_values, _keys]);
  Future<web.CryptoKey>? _key;

  Future<web.CryptoKey> _wrapKey() => _key ??= () async {
        final stored = await _idb.run<JSAny?>(_keys, (s) => s.get(_wrapKeyId.toJS));
        if (stored != null) return stored as web.CryptoKey;
        final fresh = await web.window.crypto.subtle
            .generateKey(
              {'name': 'AES-GCM', 'length': 256}.jsify()!,
              false,
              ['encrypt'.toJS, 'decrypt'.toJS].toJS,
            )
            .toDart;
        // `add` refuses to overwrite: if another tab won the race, its key is
        // the one read back below.
        try {
          await _idb.run<JSAny?>(_keys, (s) => s.add(fresh, _wrapKeyId.toJS), write: true);
        } on StateError {
          // Lost the race.
        }
        return (await _idb.run<JSAny?>(_keys, (s) => s.get(_wrapKeyId.toJS))) as web.CryptoKey;
      }();

  /// The entry name is bound in as associated data, so a ciphertext moved
  /// under another name fails to decrypt.
  JSAny _params(Uint8List iv, String key) => {
        'name': 'AES-GCM',
        'iv': iv.toJS,
        'additionalData': Uint8List.fromList(utf8.encode(key)).toJS,
      }.jsify()!;

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async {
    final random = Random.secure();
    final iv = Uint8List.fromList(List.generate(_ivLength, (_) => random.nextInt(256)));
    final sealed = await web.window.crypto.subtle
        .encrypt(_params(iv, key) as JSObject, await _wrapKey(), Uint8List.fromList(utf8.encode(value)).toJS)
        .toDart;
    final cipher = (sealed as JSArrayBuffer).toDart.asUint8List();
    final record = Uint8List(_ivLength + cipher.length)
      ..setAll(0, iv)
      ..setAll(_ivLength, cipher);
    await _idb.run<JSAny?>(_values, (s) => s.put(record.toJS, key.toJS), write: true);
  }

  Future<String?> _decrypt(String key, JSAny? stored) async {
    if (stored == null) return null;
    final record = (stored as JSUint8Array).toDart;
    try {
      final plain = await web.window.crypto.subtle
          .decrypt(
            _params(Uint8List.sublistView(record, 0, _ivLength), key) as JSObject,
            await _wrapKey(),
            Uint8List.sublistView(record, _ivLength).toJS,
          )
          .toDart;
      return utf8.decode((plain as JSArrayBuffer).toDart.asUint8List());
    } catch (_) {
      // Sealed under a key that is gone (site data partly cleared): the value
      // is unrecoverable, same as never stored.
      return null;
    }
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async =>
      _decrypt(key, await _idb.run<JSAny?>(_values, (s) => s.get(key.toJS)));

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      await read(key: key, options: options) != null;

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    await _idb.run<JSAny?>(_values, (s) => s.delete(key.toJS), write: true);
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async {
    final names = await _idb.run<JSArray<JSAny?>>(_values, (s) => s.getAllKeys());
    final all = <String, String>{};
    for (final name in names.toDart) {
      final key = (name as JSString).toDart;
      final value = await read(key: key, options: options);
      if (value != null) all[key] = value;
    }
    return all;
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    await _idb.run<JSAny?>(_values, (s) => s.clear(), write: true);
  }
}
