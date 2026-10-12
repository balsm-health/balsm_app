import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'go_online_controller.dart';

/// Secure-storage keys the go-online flow keeps for a device-only account,
/// on top of [OfflineAccountService]'s own. Removing the account (or finding
/// it left over from an uninstalled copy of the app) deletes these too.
const kDeviceAccountFlowKeys = [
  GoOnlineController.kLocalId,
  GoOnlineController.kDisclosurePending,
  GoOnlineController.kPendingMergeTarget,
  GoOnlineController.kPendingMergeChoice,
];

/// Session tokens a go-online that never finished may have stored.
const _kSessionTokens = ['balsm.access_token', 'balsm.refresh_token'];

/// "Remove this account from this phone" for a device-only account — what
/// Profile offers instead of Sign out, and what Unlock's "Forgot password?
/// Start over" runs.
///
/// A device-only account exists only here, so signing out of it would just
/// strand its data (and leave `balsm.account_mode = deviceOnly` behind to
/// lock the next account out). This deletes everything instead: the
/// account's rows ([discardOwner], which lifts only the approved FR-019
/// dose-history guard), its vault partition and file key
/// ([UserFileStore.deleteOwnerFiles]), and every offline-account key. It never
/// calls the server — there is no server session to end.
///
/// PHI constraint: never logs ids, email or password.
class DeviceAccountRemover {
  DeviceAccountRemover({
    required OfflineAccountService offline,
    required GeneratedDatabase db,
    required UserFileStore files,
    required SecureStorageWrapper storage,
    required EventBus eventBus,
  })  : _offline = offline,
        _db = db,
        _files = files,
        _storage = storage,
        _bus = eventBus;

  final OfflineAccountService _offline;
  final GeneratedDatabase _db;
  final UserFileStore _files;
  final SecureStorageWrapper _storage;
  final EventBus _bus;

  /// Deletes the device-only account and all its data. Throws [StateError]
  /// for an online account (that one signs out normally). Idempotent: a
  /// re-run after a crash finds less to delete and finishes the rest.
  Future<void> remove() async {
    if (await _offline.mode() != AccountMode.deviceOnly) {
      throw StateError('not a device-only account');
    }
    // The id the rows and files belong to. While a go-online is half done,
    // `balsm.user_id` may already hold a server id; the pinned local id is
    // the device's own. Rows a server account already had on this phone are
    // never touched.
    final pinned = await _storage.readToken(GoOnlineController.kLocalId);
    final current = await _storage.readToken(OfflineAccountService.kUserId);
    final owner = (pinned != null && pinned.isNotEmpty) ? pinned : current;
    if (owner != null && owner.isNotEmpty) {
      await discardOwner(_db, owner: owner);
      await _files.deleteOwnerFiles(owner: owner);
    }
    for (final k in [...kDeviceAccountFlowKeys, ..._kSessionTokens]) {
      await _storage.deleteToken(k);
    }
    // Last: until the mode is gone, a crash lands back on Unlock and this
    // can run again.
    await _offline.wipe();
    // Same sweep as a sign-out (caches, permanent QR, analytics identity).
    _bus.publish(UserSignedOut(userId: UserId.value(owner ?? '')));
  }
}

final deviceAccountRemoverProvider = Provider<DeviceAccountRemover>((ref) {
  return DeviceAccountRemover(
    offline: ref.watch(offlineAccountServiceProvider),
    db: ref.watch(appDatabaseProvider),
    files: ref.watch(userFileStoreProvider),
    storage: ref.watch(secureStorageProvider),
    eventBus: ref.watch(eventBusProvider),
  );
});
