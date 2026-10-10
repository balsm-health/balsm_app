import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool>? _claim;

/// Whether this tab owns the on-device database. The browser database keeps
/// the file in memory, so two tabs would overwrite each other's pages: the
/// first tab takes a lock for its lifetime and every later one gets `false`.
/// The lock frees itself when the owning tab closes or reloads.
///
/// Asked once per page load; the UI and the database open share the answer.
Future<bool> claimDatabaseTab() => _claim ??= () {
      final claimed = Completer<bool>();
      final held = Completer<JSAny?>();
      web.window.navigator.locks.request(
        'balsm.db',
        web.LockOptions(ifAvailable: true),
        ((web.Lock? lock) {
          claimed.complete(lock != null);
          // Never completes: the lock lives until the tab goes away.
          return lock == null ? null : held.future.toJS;
        }).toJS,
      );
      return claimed.future;
    }();

void reloadPage() => web.window.location.reload();
