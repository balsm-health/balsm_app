import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../screens/auth_flow.dart' show kDisclosureId, kDisclosureVersion;

/// Where a successful go-online verify leaves the account.
enum GoOnlineOutcome {
  /// The device-only account is now the online account.
  online,

  /// The email already had a server account: the patient must choose to merge
  /// this device's data into it or discard it (the merge-or-discard screen).
  needsMergeChoice,
}

/// Takes a device-only account online: email → OTP → claim the id.
///
/// The session tokens are persisted by [SignInUseCase.goOnline]; this owns
/// everything around it — re-keying local rows when the server assigned a
/// different id, flipping the account mode, announcing the sign-in, handing
/// the offline password to the server, and re-sending the disclosure
/// acceptance that was recorded while no server could receive it.
///
/// PHI constraint: never logs the email, ids, the code or the password.
class GoOnlineController {
  GoOnlineController({
    required SignInUseCase signIn,
    required OfflineAccountService offline,
    required AcceptDisclosureUseCase disclosure,
    required GeneratedDatabase db,
    required UserFileStore files,
    required SecureStorageWrapper storage,
    required EventBus eventBus,
    required String Function() countryCode,
  })  : _signIn = signIn,
        _offline = offline,
        _disclosure = disclosure,
        _db = db,
        _files = files,
        _storage = storage,
        _bus = eventBus,
        _countryCode = countryCode;

  final SignInUseCase _signIn;
  final OfflineAccountService _offline;
  final AcceptDisclosureUseCase _disclosure;
  final GeneratedDatabase _db;
  final UserFileStore _files;
  final SecureStorageWrapper _storage;
  final EventBus _bus;
  final String Function() _countryCode;

  static const kUserId = 'balsm.user_id';
  static const kPendingMergeTarget = 'balsm.pending_merge_target';

  /// The id the device's local rows and files are owned by, pinned before
  /// [SignInUseCase.goOnline] overwrites `balsm.user_id` with a server id.
  /// Read from here on every attempt so a retry (or the merge screen) never
  /// works from the server's id by mistake. Cleared once the flow completes
  /// here; after a merge/discard, that screen clears it.
  static const kLocalId = 'balsm.offline.local_id';

  /// Set while the disclosure acceptance recorded offline has not reached
  /// the server yet; [retryPending] tries again at launch.
  static const kDisclosurePending = 'balsm.offline.disclosure_pending';

  /// The existing server account a [GoOnlineOutcome.needsMergeChoice] verify
  /// found. Also persisted under [kPendingMergeTarget] so the choice survives
  /// a restart.
  String? pendingTargetId;

  /// Set when the last verify hit a server lockout; the sheet shows the wait.
  DateTime? lockedUntil;

  Future<AppResult<void>> sendCode(String email) => _signIn.requestContinueOtp(email, _countryCode());

  Future<AppResult<GoOnlineOutcome>> verify({required String email, required String code}) async {
    lockedUntil = null;
    // Step 1: the device's own id, pinned before goOnline overwrites
    // balsm.user_id with the server's id when it persists the session.
    final localId = await _localId();
    if (localId == null) {
      return AppResult.failure(const ValidationFailure('No device account'));
    }

    // Step 2.
    final r = await _signIn.goOnline(email: email, code: code, clientAccountId: localId);
    if (r.isFailure) return AppResult.failure(r.error);

    final String finalId;
    switch (r.value) {
      case GoOnlineAdopted():
        // Step 3: the server kept the device's id — nothing to re-key.
        finalId = localId;
      case GoOnlineNewId(:final userId):
        // Step 4: collision — move every local row, then the vault files and
        // their key, to the server's id before anyone is told the account
        // changed. Both are idempotent, so a failure is reported (not thrown
        // into the sheet) and a retry re-runs both from the pinned local id.
        // Only once both have landed does the pin move to the new id.
        try {
          await rekeyOwner(_db, from: localId, to: userId, dropOutbox: false);
          await _files.rekeyOwnerFiles(from: localId, to: userId);
        } catch (_) {
          return AppResult.failure(const StorageFailure());
        }
        await _storage.writeToken(kLocalId, userId);
        finalId = userId;
      case GoOnlineExistingAccount(:final userId):
        // Step 6: the merge-or-discard screen finishes this; the account is
        // NOT online yet, and nobody is told it signed in.
        await _offline.setPendingMerge(true);
        pendingTargetId = userId;
        await _storage.writeToken(kPendingMergeTarget, userId);
        return AppResult.success(GoOnlineOutcome.needsMergeChoice);
      case GoOnlineLockout(:final session):
        lockedUntil = session.until;
        return AppResult.failure(const UnauthorizedFailure('Account locked'));
    }

    // Step 5.
    await _offline.markOnline();
    _bus.publish(UserSignedIn(userId: UserId.value(finalId), email: email, provider: 'email'));
    await finishPasswordIfPending();
    await _storage.writeToken(kDisclosurePending, 'true');
    await _resyncDisclosure();
    await _storage.deleteToken(kLocalId);
    return AppResult.success(GoOnlineOutcome.online);
  }

  /// Merge-or-discard, choice 1: adds this phone's data to the existing
  /// account the verify found ([kPendingMergeTarget]).
  ///
  /// Rows move with [mergeOwner] (profile consolidated, outbox dropped) and
  /// files with [UserFileStore.mergeOwnerFiles]. The existing account keeps
  /// its own password (D2): the offline one is discarded, never sent. The
  /// disclosure acceptance recorded offline is re-sent like [verify] does.
  ///
  /// Resumable: the pending keys are cleared only after everything else, so
  /// a crash anywhere lands back on the merge screen and a re-run finishes
  /// (both moves find nothing left under the device id). A storage failure
  /// returns [StorageFailure] and changes nothing past the data moves.
  Future<AppResult<void>> merge() => _resolvePending((localId, target) async {
        await mergeOwner(_db, from: localId, to: target);
        await _files.mergeOwnerFiles(from: localId, to: target);
      }, resyncDisclosure: true);

  /// Merge-or-discard, choice 2: deletes everything this phone holds for the
  /// device-only account — every row it owns (and their dependants) and its
  /// vault files and key — then continues as the existing account. The
  /// screen confirms twice before calling this. Resumable like [merge].
  Future<AppResult<void>> discard() => _resolvePending((localId, target) async {
        // Never delete the account being signed in to.
        if (localId == target) throw StateError('device id is the target');
        await discardOwner(_db, owner: localId);
        await _files.deleteOwnerFiles(owner: localId);
      }, resyncDisclosure: false);

  Future<AppResult<void>> _resolvePending(
    Future<void> Function(String localId, String target) moveData, {
    required bool resyncDisclosure,
  }) async {
    final localId = await _storage.readToken(kLocalId);
    final target = await _storage.readToken(kPendingMergeTarget);
    if (localId == null || localId.isEmpty || target == null || target.isEmpty) {
      return AppResult.failure(const ValidationFailure('No pending merge'));
    }
    try {
      await moveData(localId, target);
    } catch (_) {
      return AppResult.failure(const StorageFailure());
    }
    // Read before markOnline() deletes it; empty on a resume past that point.
    final email = await _storage.readToken(OfflineAccountService.kEmail) ?? '';
    await _storage.writeToken(kUserId, target);
    await _offline.clearPlainPassword();
    await _offline.markOnline();
    if (resyncDisclosure) await _storage.writeToken(kDisclosurePending, 'true');
    _bus.publish(UserSignedIn(userId: UserId.value(target), email: email, provider: 'email'));
    await _offline.setPendingMerge(false);
    await _storage.deleteToken(kPendingMergeTarget);
    await _storage.deleteToken(kLocalId);
    pendingTargetId = null;
    if (resyncDisclosure) await _resyncDisclosure();
    return AppResult.success(null);
  }

  /// [kLocalId] if pinned; otherwise pins the current `balsm.user_id`.
  Future<String?> _localId() async {
    final pinned = await _storage.readToken(kLocalId);
    if (pinned != null && pinned.isNotEmpty) return pinned;
    final current = await _storage.readToken(kUserId);
    if (current == null || current.isEmpty) return null;
    await _storage.writeToken(kLocalId, current);
    return current;
  }

  Future<void> _resyncDisclosure() async {
    final ok =
        await _disclosure.resync(disclosureId: const DisclosureId.value(kDisclosureId), version: kDisclosureVersion);
    if (ok) await _storage.deleteToken(kDisclosurePending);
  }

  /// Launch-time retry for an account that is already online: the offline
  /// password that never reached the server, and the disclosure acceptance
  /// that never synced. Never throws — a keychain or network error just
  /// leaves both for the next launch.
  Future<void> retryPending() async {
    try {
      await finishPasswordIfPending();
    } catch (_) {}
    try {
      if (await _storage.readToken(kDisclosurePending) == 'true') await _resyncDisclosure();
    } catch (_) {}
  }

  /// Sets the password chosen offline as the server password. On failure the
  /// plaintext is kept, and this runs again at the next launch.
  Future<void> finishPasswordIfPending() async {
    final creds = await _offline.pendingCredentials();
    if (creds == null) return;
    final r = await _signIn.setPassword(password: creds.password);
    if (r.isSuccess) await _offline.clearPlainPassword();
  }
}

final goOnlineControllerProvider = Provider<GoOnlineController>((ref) {
  return GoOnlineController(
    signIn: ref.watch(signInUseCaseProvider),
    offline: ref.watch(offlineAccountServiceProvider),
    disclosure: ref.watch(acceptDisclosureUseCaseProvider),
    db: ref.watch(appDatabaseProvider),
    files: ref.watch(userFileStoreProvider),
    storage: ref.watch(secureStorageProvider),
    eventBus: ref.watch(eventBusProvider),
    countryCode: () => ref.read(patientAppStateProvider).country.value,
  );
});
