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
    required SecureStorageWrapper storage,
    required EventBus eventBus,
    required String Function() countryCode,
  })  : _signIn = signIn,
        _offline = offline,
        _disclosure = disclosure,
        _db = db,
        _storage = storage,
        _bus = eventBus,
        _countryCode = countryCode;

  final SignInUseCase _signIn;
  final OfflineAccountService _offline;
  final AcceptDisclosureUseCase _disclosure;
  final GeneratedDatabase _db;
  final SecureStorageWrapper _storage;
  final EventBus _bus;
  final String Function() _countryCode;

  static const kUserId = 'balsm.user_id';
  static const kPendingMergeTarget = 'balsm.pending_merge_target';

  /// The existing server account a [GoOnlineOutcome.needsMergeChoice] verify
  /// found. Also persisted under [kPendingMergeTarget] so the choice survives
  /// a restart.
  String? pendingTargetId;

  /// Set when the last verify hit a server lockout; the sheet shows the wait.
  DateTime? lockedUntil;

  Future<AppResult<void>> sendCode(String email) => _signIn.requestContinueOtp(email, _countryCode());

  Future<AppResult<GoOnlineOutcome>> verify({required String email, required String code}) async {
    lockedUntil = null;
    // Step 1: read before goOnline — it overwrites balsm.user_id with the
    // server's id when it persists the session.
    // (The pending credentials are read again by finishPasswordIfPending.)
    await _offline.pendingCredentials();
    final localId = await _storage.readToken(kUserId);
    if (localId == null || localId.isEmpty) {
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
        // Step 4: collision — move every local row to the server's id before
        // anyone is told the account changed.
        // All-or-nothing (one transaction); a failure leaves the account
        // device-only and is reported instead of thrown into the sheet.
        try {
          await rekeyOwner(_db, from: localId, to: userId, dropOutbox: false);
        } catch (_) {
          return AppResult.failure(const StorageFailure());
        }
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
    await _disclosure.resync(disclosureId: const DisclosureId.value(kDisclosureId), version: kDisclosureVersion);
    return AppResult.success(GoOnlineOutcome.online);
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
    storage: ref.watch(secureStorageProvider),
    eventBus: ref.watch(eventBusProvider),
    countryCode: () => ref.read(patientAppStateProvider).country.value,
  );
});
