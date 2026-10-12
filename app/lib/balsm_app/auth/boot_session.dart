import 'package:auth/auth.dart';
import 'package:core/core.dart';

import '../prefs.dart';
import 'device_account_remover.dart' show kDeviceAccountFlowKeys;
import 'go_online_controller.dart';

/// What the keychain says about the session at app start, after the
/// clean-ups below. Feeds `PatientAppState.load` and the container.
class BootSession {
  const BootSession({
    required this.sessionUserId,
    required this.accountMode,
    required this.pendingMerge,
    required this.hasOfflinePassword,
  });

  /// The account whose data this session shows (null: signed out).
  final UserId? sessionUserId;
  final AccountMode accountMode;
  final bool pendingMerge;

  /// `balsm.offline.pw_hash` is present: the device password guards entry.
  final bool hasOfflinePassword;
}

/// Reads the session from secure storage at boot, repairing the states a
/// crash or a reinstall can leave behind:
///
/// 1. A `create()` that never finished ([OfflineAccountService.discardIncompleteCreate]).
/// 2. A reinstall. iOS keeps keychain items across an uninstall while the
///    app-shell prefs (and the database and vault files) are deleted with
///    the app. A device-only account found with an empty prefs group is
///    therefore a dead account from a previous install whose data is gone:
///    without this the new install would boot to an Unlock screen whose
///    password the patient may not even remember, guarding nothing. Its
///    offline keys and file keys are deleted.
/// 3. An online id with no refresh token (an interrupted sign-out).
/// 4. A go-online killed between storing the server's session and moving
///    the local data: `balsm.user_id` already holds the server id while the
///    rows are still owned by the pinned `balsm.offline.local_id`. The
///    session uses the local id so the data stays visible; going online
///    again from Profile finishes the move from that same pinned id.
Future<BootSession> resolveBootSession({
  required SecureStorageWrapper storage,
  required PatientAppPrefs prefs,
  required OfflineAccountService offline,
}) async {
  await offline.discardIncompleteCreate();

  if (await storage.readToken(kAccountModeKey) != null && await prefs.isFreshInstall()) {
    await _forgetPreviousInstall(storage, offline);
  }

  final userId = await storage.readToken(OfflineAccountService.kUserId);
  final accountMode = AccountMode.fromWire(await storage.readToken(kAccountModeKey));
  final pendingMerge = await offline.pendingMerge();
  final hasOfflinePassword = await storage.readToken(OfflineAccountService.kHash) != null;

  // A session needs a REFRESH token to be revivable, not just an id — unless
  // the account is device-only, which has an id and no tokens by design. With
  // an online id alone the shell opens signed-in and stays broken: every read
  // resolves to nothing, and the interceptor cannot mint a new access token.
  final refreshToken = await storage.readToken(OfflineAccountService.kRefreshToken);
  final hasId = userId != null && userId.isNotEmpty;
  final revivable =
      hasId && (accountMode == AccountMode.deviceOnly || (refreshToken != null && refreshToken.isNotEmpty));
  if (hasId && !revivable) {
    // Unrecoverable remnant. Clear it so the next launch agrees with the
    // keychain rather than repeating this.
    await storage.deleteToken(OfflineAccountService.kUserId);
    await storage.deleteToken('balsm.access_token');
  }

  var sessionId = revivable ? userId : null;
  if (revivable && accountMode == AccountMode.deviceOnly) {
    final pinned = await storage.readToken(GoOnlineController.kLocalId);
    if (pinned != null && pinned.isNotEmpty && pinned != userId) sessionId = pinned;
  }

  return BootSession(
    sessionUserId: UserId.fromString(sessionId),
    accountMode: accountMode,
    pendingMerge: pendingMerge,
    hasOfflinePassword: hasOfflinePassword,
  );
}

Future<void> _forgetPreviousInstall(SecureStorageWrapper storage, OfflineAccountService offline) async {
  final deviceOnly = AccountMode.fromWire(await storage.readToken(kAccountModeKey)) == AccountMode.deviceOnly;
  final ids = {
    await storage.readToken(OfflineAccountService.kUserId),
    await storage.readToken(GoOnlineController.kLocalId),
  }.whereType<String>().where((id) => id.isNotEmpty);
  // The files these keys decrypted went with the uninstalled app.
  for (final id in ids) {
    await storage.deleteToken('balsm.file_key.$id');
  }
  for (final k in kDeviceAccountFlowKeys) {
    await storage.deleteToken(k);
  }
  // A device-only account's tokens can only be a go-online that never
  // finished; an online account's are left for its next sign-in to replace.
  if (deviceOnly) {
    await storage.deleteToken('balsm.access_token');
    await storage.deleteToken(OfflineAccountService.kRefreshToken);
  }
  await offline.wipe();
}

/// The id telemetry (Sentry, PostHog) may know the patient by. A
/// device-only account's id never leaves the phone (spec §6), so it is
/// null until the account goes online.
String? telemetryUserId(AccountMode mode, UserId? id) => mode == AccountMode.deviceOnly ? null : id?.value;

/// [telemetryUserId] for a just-announced sign-in. A `'device'` sign-in is a
/// device-only account being created; any other reads the stored mode, which
/// go-online flips to online before it announces the sign-in.
Future<String?> telemetryUserIdAfterSignIn(SecureStorageWrapper storage, UserSignedIn e) async {
  if (e.provider == 'device') return null;
  return telemetryUserId(AccountMode.fromWire(await storage.readToken(kAccountModeKey)), e.userId);
}
