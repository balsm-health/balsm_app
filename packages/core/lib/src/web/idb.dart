import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// One IndexedDB database with a fixed set of object stores, each request in
/// its own transaction. Web only.
class Idb {
  Idb(this.name, this.stores);

  final String name;
  final List<String> stores;
  Future<web.IDBDatabase>? _db;

  Future<web.IDBDatabase> _open() => _db ??= () {
        final request = web.window.indexedDB.open(name, 1);
        request.onupgradeneeded = ((web.Event _) {
          final db = request.result as web.IDBDatabase;
          for (final store in stores) {
            db.createObjectStore(store);
          }
        }).toJS;
        return _await<web.IDBDatabase>(request);
      }();

  Future<T> _await<T extends JSAny?>(web.IDBRequest request) {
    final done = Completer<T>();
    request.onsuccess = ((web.Event _) => done.complete(request.result as T)).toJS;
    request.onerror = ((web.Event _) => done.completeError(StateError('$name: ${request.error?.message}'))).toJS;
    return done.future;
  }

  /// Runs one request against [store] and returns its result.
  Future<T> run<T extends JSAny?>(
    String store,
    web.IDBRequest Function(web.IDBObjectStore store) request, {
    bool write = false,
  }) async {
    final db = await _open();
    return _await<T>(request(db.transaction(store.toJS, write ? 'readwrite' : 'readonly').objectStore(store)));
  }

  /// Every key that starts with [prefix].
  static web.IDBKeyRange prefixed(String prefix) => web.IDBKeyRange.bound(prefix.toJS, '$prefix￿'.toJS);
}
