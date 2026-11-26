import 'dart:async';

import 'package:auth/auth.dart';
import 'package:core/core.dart' show AccountMode, AppResult, ConflictFailure, NetworkFailure;
import 'package:disclosure/disclosure.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/auth_flow.dart' show kDisclosureId, kDisclosureVersion;
import 'go_online_controller.dart';

/// Typed auth-flow errors. The screens map kinds onto localized strings —
/// controllers never touch the string bundles.
///
/// [AuthErrorKind.failed] is the generic "that did not work, try again" each
/// screen words for its own step (device create, unlock, merge, go online,
/// Google). It never carries the exception's own text.
enum AuthErrorKind { lockout, invalidCredentials, emailRegistered, server, socialUnavailable, failed, removeFailed }

@immutable
class AuthError {
  const AuthError.lockout(this.lockoutSecs)
      : kind = AuthErrorKind.lockout,
        message = null;
  const AuthError.invalidCredentials()
      : kind = AuthErrorKind.invalidCredentials,
        message = null,
        lockoutSecs = 0;
  const AuthError.emailRegistered()
      : kind = AuthErrorKind.emailRegistered,
        message = null,
        lockoutSecs = 0;
  const AuthError.server(this.message)
      : kind = AuthErrorKind.server,
        lockoutSecs = 0;

  /// The provider sign-in returned no usable token (not the patient's fault).
  const AuthError.socialUnavailable()
      : kind = AuthErrorKind.socialUnavailable,
        message = null,
        lockoutSecs = 0;
  const AuthError.failed()
      : kind = AuthErrorKind.failed,
        message = null,
        lockoutSecs = 0;

  /// Removing the device-only account (Start over) did not go through.
  const AuthError.removeFailed()
      : kind = AuthErrorKind.removeFailed,
        message = null,
        lockoutSecs = 0;

  final AuthErrorKind kind;

  /// Server-provided text (already display-safe) for [AuthErrorKind.server].
  final String? message;
  final int lockoutSecs;

  @override
  bool operator ==(Object other) =>
      other is AuthError && other.kind == kind && other.message == message && other.lockoutSecs == lockoutSecs;

  @override
  int get hashCode => Object.hash(kind, message, lockoutSecs);
}

int _lockoutSecs(SignInLockout lockout) => lockout.session.until.difference(DateTime.now()).inSeconds.clamp(0, 3600);

/// Seconds before a new email code may be asked for.
const kResendSecs = 28;

/// A once-a-second countdown to zero, owned by a notifier: the notifier
/// writes each tick into its state and cancels this in `ref.onDispose`.
///
/// Shared by the sign-up code step, the go-online sheet and the unlock
/// lockout, which each used to run their own copy of the same timer.
class Countdown {
  Countdown(this._onTick);

  /// Receives the seconds left after each tick; 0 is the last call.
  final void Function(int secs) _onTick;
  Timer? _timer;

  /// Counts down from [secs]; the caller has already put [secs] in its state.
  void start(int secs) {
    cancel();
    if (secs <= 0) return;
    var left = secs;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      left -= 1;
      if (left <= 0) t.cancel();
      _onTick(left);
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Marks a `copyWith` argument that was not passed, so a nullable field can
/// still be set to null on purpose.
const Object _unset = Object();

// ── Welcome: Google sign-in ─────────────────────────────────────────────────

@immutable
class GoogleSignInState {
  const GoogleSignInState({this.busy = false, this.error});
  final bool busy;
  final AuthError? error;

  @override
  bool operator ==(Object other) => other is GoogleSignInState && other.busy == busy && other.error == error;

  @override
  int get hashCode => Object.hash(busy, error);
}

/// A finished Google sign-in. The names are the provider's, handed over so a
/// new account can prefill Personal details.
typedef GoogleSignedIn = ({bool isNewUser, String? givenName, String? familyName});

/// The native Google flow, then the Balsm token exchange. The screen
/// navigates on the returned success; refusals land in state.
class GoogleSignInController extends Notifier<GoogleSignInState> {
  @override
  GoogleSignInState build() => const GoogleSignInState();

  /// Null when the patient backed out, or when it failed (the error is in
  /// state).
  Future<GoogleSignedIn?> signIn({required String countryCode}) async {
    if (state.busy) return null;
    state = const GoogleSignInState(busy: true);
    final credentials = await ref.read(googleCredentialsPortProvider).obtain();
    if (!ref.mounted) return null;
    switch (credentials) {
      case SocialCredentialsCancelled():
        // The patient backed out of the provider sheet — say nothing.
        state = const GoogleSignInState();
        return null;
      case SocialCredentialsFailure(:final missingToken):
        state = GoogleSignInState(
          error: missingToken ? const AuthError.socialUnavailable() : const AuthError.failed(),
        );
        return null;
      case SocialCredentials():
        break;
    }
    final result = await ref.read(signInUseCaseProvider).signInWithGoogle(
          idToken: credentials.idToken,
          email: credentials.email,
          countryCode: countryCode,
        );
    if (!ref.mounted) return null;
    return result.fold(
      (signIn) {
        switch (signIn) {
          case SignInSuccess(:final isNewUser):
            state = const GoogleSignInState();
            return (isNewUser: isNewUser, givenName: credentials.givenName, familyName: credentials.familyName);
          case SignInLockout():
            state = GoogleSignInState(error: AuthError.lockout(_lockoutSecs(signIn)));
            return null;
        }
      },
      (f) {
        state = GoogleSignInState(error: AuthError.server(f.message));
        return null;
      },
    );
  }
}

final NotifierProvider<GoogleSignInController, GoogleSignInState> googleSignInControllerProvider =
    NotifierProvider.autoDispose<GoogleSignInController, GoogleSignInState>(GoogleSignInController.new);

// ── Credentials step ────────────────────────────────────────────────────────

@immutable
class CredentialsState {
  const CredentialsState({this.submitting = false, this.error});
  final bool submitting;
  final AuthError? error;

  @override
  bool operator ==(Object other) => other is CredentialsState && other.submitting == submitting && other.error == error;

  @override
  int get hashCode => Object.hash(submitting, error);
}

/// Data controller for the email + password step: password sign-in, the
/// sign-up OTP request and the device-only create. The screen keeps text
/// controllers and the password-visibility toggle (view state).
class CredentialsController extends Notifier<CredentialsState> {
  @override
  CredentialsState build() => const CredentialsState();

  /// True → session established (caller navigates). Failures land in state.
  Future<bool> signIn({required String email, required String password}) async {
    state = const CredentialsState(submitting: true);
    final result = await ref.read(signInUseCaseProvider).passwordSignIn(email: email, password: password);
    if (!ref.mounted) return false;
    return result.fold(
      (signIn) => switch (signIn) {
        SignInSuccess() => () {
            state = const CredentialsState();
            return true;
          }(),
        SignInLockout() => () {
            state = CredentialsState(error: AuthError.lockout(_lockoutSecs(signIn)));
            return false;
          }(),
      },
      (_) {
        state = const CredentialsState(error: AuthError.invalidCredentials());
        return false;
      },
    );
  }

  /// True → the code is on its way (caller routes to the verification step).
  ///
  /// Requested only after a sign-in that failed on credentials, and only when
  /// the patient taps: every failed attempt would otherwise email whoever owns
  /// that address, which is a mail-bomb aimed by anyone who knows it.
  Future<bool> requestContinueOtp({required String email, required String countryCode}) async {
    state = const CredentialsState(submitting: true);
    final result = await ref.read(signInUseCaseProvider).requestContinueOtp(email, countryCode);
    if (!ref.mounted) return false;
    return result.fold(
      (_) {
        state = const CredentialsState();
        return true;
      },
      (f) {
        state = CredentialsState(error: AuthError.server(f.message));
        return false;
      },
    );
  }

  /// True → OTP sent (caller routes to the verification step).
  Future<bool> requestSignupOtp({required String email, required String countryCode}) async {
    state = const CredentialsState(submitting: true);
    final result = await ref.read(signUpUseCaseProvider).requestEmailOtp(email, countryCode);
    if (!ref.mounted) return false;
    return result.fold(
      (_) {
        state = const CredentialsState();
        return true;
      },
      (f) {
        state = CredentialsState(
          error: f is ConflictFailure ? const AuthError.emailRegistered() : AuthError.server(f.message),
        );
        return false;
      },
    );
  }

  /// Device-only path: no network round-trip, no OTP. True → the account
  /// exists on this device (caller switches the mode and runs the disclosure
  /// gate). A failure is [AuthError.failed], never the exception's own text:
  /// it could be a secure-storage error, with nothing to surface or log.
  Future<bool> createOnDevice({required String email, required String password}) async {
    if (state.submitting) return false;
    state = const CredentialsState(submitting: true);
    try {
      await ref.read(offlineAccountServiceProvider).create(email: email, password: password);
    } on Object catch (_) {
      if (ref.mounted) state = const CredentialsState(error: AuthError.failed());
      return false;
    }
    if (ref.mounted) state = const CredentialsState();
    return true;
  }
}

final NotifierProvider<CredentialsController, CredentialsState> credentialsControllerProvider =
    NotifierProvider.autoDispose<CredentialsController, CredentialsState>(CredentialsController.new);

// ── OTP verification step ───────────────────────────────────────────────────

/// Something after a good code that did not work: the session is live, only
/// the password typed before the code did not stick. Not an auth error, so it
/// does not clear the boxes.
enum OtpNotice {
  /// A new account's password could not be set.
  passwordNotSet,

  /// An existing account's password could not be replaced by the typed one.
  passwordNotAdopted,
}

@immutable
class OtpState {
  const OtpState({this.secs = kResendSecs, this.verifying = false, this.resending = false, this.error, this.notice});
  final int secs;
  final bool verifying;
  final bool resending;
  final AuthError? error;
  final OtpNotice? notice;

  OtpState copyWith({int? secs, bool? verifying, bool? resending, Object? error = _unset, Object? notice = _unset}) =>
      OtpState(
        secs: secs ?? this.secs,
        verifying: verifying ?? this.verifying,
        resending: resending ?? this.resending,
        error: identical(error, _unset) ? this.error : error as AuthError?,
        notice: identical(notice, _unset) ? this.notice : notice as OtpNotice?,
      );

  @override
  bool operator ==(Object other) =>
      other is OtpState &&
      other.secs == secs &&
      other.verifying == verifying &&
      other.resending == resending &&
      other.error == error &&
      other.notice == notice;

  @override
  int get hashCode => Object.hash(secs, verifying, resending, error, notice);
}

/// Data controller for the six-digit verification step: the resend countdown
/// and the verify call. On success the use case has already persisted the
/// session; the screen only navigates.
class OtpController extends Notifier<OtpState> {
  Countdown? _countdown;

  @override
  OtpState build() {
    final countdown = _countdown = Countdown((secs) => state = state.copyWith(secs: secs));
    ref.onDispose(countdown.cancel);
    countdown.start(kResendSecs);
    return const OtpState();
  }

  /// Requests a new code for the same address, which also retires the
  /// previous email's code and link. The countdown restarts only once the
  /// server has accepted; a refusal stays on screen with Resend still offered
  /// (#116). True when a new code is on its way.
  Future<bool> resend({required String email, required String countryCode}) async {
    if (state.resending || state.verifying || state.secs > 0) return false;
    state = state.copyWith(resending: true, error: null);
    final result = await ref.read(signUpUseCaseProvider).requestEmailOtp(email, countryCode);
    if (!ref.mounted) return false;
    return result.fold(
      (_) {
        state = state.copyWith(resending: false, secs: kResendSecs);
        _countdown?.start(kResendSecs);
        return true;
      },
      (f) {
        state = state.copyWith(
          resending: false,
          error: f is ConflictFailure ? const AuthError.emailRegistered() : AuthError.server(f.message),
        );
        return false;
      },
    );
  }

  /// Null → verified; the success carries `isNewUser`. Non-null result means
  /// the error is in state and the caller clears the boxes.
  Future<bool?> verify({required String email, required String code}) async {
    if (state.verifying) return null;
    state = state.copyWith(verifying: true, error: null);
    final result = await ref.read(signInUseCaseProvider).verifyEmailOtp(email: email, code: code);
    if (!ref.mounted) return null;
    return result.fold(
      (signInResult) => switch (signInResult) {
        SignInSuccess(:final isNewUser) => () {
            state = state.copyWith(verifying: false);
            return isNewUser;
          }(),
        SignInLockout() => () {
            state = state.copyWith(verifying: false, error: AuthError.lockout(_lockoutSecs(signInResult)));
            return null;
          }(),
      },
      (f) {
        state = state.copyWith(verifying: false, error: AuthError.server(f.message));
        return null;
      },
    );
  }

  /// Makes [password] the account's password once the code has proven the
  /// mailbox. A failure becomes a [OtpNotice] in state; the session stays.
  Future<void> applyPassword(String password, {required bool isNewUser}) async {
    final result = await ref.read(signInUseCaseProvider).setPassword(password: password);
    if (!ref.mounted || result.isSuccess) return;
    state = state.copyWith(notice: isNewUser ? OtpNotice.passwordNotSet : OtpNotice.passwordNotAdopted);
  }
}

final NotifierProvider<OtpController, OtpState> otpControllerProvider =
    NotifierProvider.autoDispose<OtpController, OtpState>(OtpController.new);

// ── Forgot-password sheet ───────────────────────────────────────────────────

enum ResetStep { email, code, done }

@immutable
class PasswordResetState {
  const PasswordResetState({this.step = ResetStep.email, this.busy = false, this.error});
  final ResetStep step;
  final bool busy;
  final AuthError? error;

  @override
  bool operator ==(Object other) =>
      other is PasswordResetState && other.step == step && other.busy == busy && other.error == error;

  @override
  int get hashCode => Object.hash(step, busy, error);
}

/// Step machine behind the forgot-password sheet: request the reset code,
/// then set the new password. Sheet keeps its text controllers.
class PasswordResetController extends Notifier<PasswordResetState> {
  @override
  PasswordResetState build() => const PasswordResetState();

  Future<void> sendCode({required String email, required String countryCode}) async {
    if (state.busy) return;
    state = const PasswordResetState(busy: true);
    final r = await ref.read(signInUseCaseProvider).requestEmailOtp(email, countryCode);
    if (!ref.mounted) return;
    state = r.fold(
      (_) => const PasswordResetState(step: ResetStep.code),
      (f) => PasswordResetState(error: AuthError.server(f.message)),
    );
  }

  Future<void> reset({required String email, required String code, required String newPassword}) async {
    if (state.busy) return;
    state = const PasswordResetState(step: ResetStep.code, busy: true);
    final r = await ref.read(signInUseCaseProvider).resetPassword(email: email, code: code, newPassword: newPassword);
    if (!ref.mounted) return;
    state = r.fold(
      (_) => const PasswordResetState(step: ResetStep.done),
      (f) => PasswordResetState(step: ResetStep.code, error: AuthError.server(f.message)),
    );
  }
}

final NotifierProvider<PasswordResetController, PasswordResetState> passwordResetControllerProvider =
    NotifierProvider.autoDispose<PasswordResetController, PasswordResetState>(PasswordResetController.new);

// ── Unlock (device-only cold start) ─────────────────────────────────────────

@immutable
class UnlockState {
  const UnlockState({this.busy = false, this.error, this.lockSecs = 0});
  final bool busy;
  final AuthError? error;

  /// Seconds left in a lockout, rounded up; 0 when not locked.
  final int lockSecs;

  bool get locked => lockSecs > 0;

  UnlockState copyWith({bool? busy, Object? error = _unset, int? lockSecs}) => UnlockState(
        busy: busy ?? this.busy,
        error: identical(error, _unset) ? this.error : error as AuthError?,
        lockSecs: lockSecs ?? this.lockSecs,
      );

  @override
  bool operator ==(Object other) =>
      other is UnlockState && other.busy == busy && other.error == error && other.lockSecs == lockSecs;

  @override
  int get hashCode => Object.hash(busy, error, lockSecs);
}

/// Where a password unlock leads.
enum UnlockOutcome {
  /// Into the app.
  app,

  /// A go-online that found an existing account still waits for its
  /// merge-or-discard choice: that screen, not the app.
  mergeOrDiscard,

  /// Wrong password, a lockout or an error; the reason is in state.
  refused,
}

/// Unlocks a device-only account with its on-device password, and counts a
/// lockout down. "Start over" deletes the account; the screen confirms first.
class UnlockController extends Notifier<UnlockState> {
  Countdown? _countdown;

  @override
  UnlockState build() {
    final countdown = _countdown = Countdown((secs) => state = state.copyWith(lockSecs: secs));
    ref.onDispose(countdown.cancel);
    unawaited(_checkLockout());
    return const UnlockState();
  }

  Future<void> _checkLockout() async {
    final LockedUntil? locked;
    try {
      locked = await ref.read(offlineAccountServiceProvider).lockout();
    } on Object catch (_) {
      return;
    }
    if (!ref.mounted || locked == null) return;
    _startLockout(locked.until);
  }

  /// Seeds the countdown from a single clock read, then ticks down once a
  /// second rather than re-reading the clock on every tick. The seconds round
  /// UP (a 29.9s wait still reads "30s") — never less time than is left.
  void _startLockout(DateTime until) {
    final ms = until.difference(DateTime.now().toUtc()).inMilliseconds;
    final secs = ms <= 0 ? 0 : (ms / 1000).ceil();
    state = state.copyWith(lockSecs: secs);
    _countdown?.start(secs);
  }

  /// Null while locked, busy or with no password typed.
  Future<UnlockOutcome?> unlock(String password) async {
    if (state.locked || state.busy || password.isEmpty) return null;
    state = state.copyWith(busy: true, error: null);
    final offline = ref.read(offlineAccountServiceProvider);
    try {
      final result = await offline.unlock(password);
      if (!ref.mounted) return null;
      switch (result) {
        case Unlocked():
          final pendingMerge = await offline.pendingMerge();
          if (!ref.mounted) return null;
          state = state.copyWith(busy: false);
          return pendingMerge ? UnlockOutcome.mergeOrDiscard : UnlockOutcome.app;
        case WrongPassword():
          state = state.copyWith(busy: false, error: const AuthError.invalidCredentials());
          return UnlockOutcome.refused;
        case LockedUntil(:final until):
          state = state.copyWith(busy: false);
          _startLockout(until);
          return UnlockOutcome.refused;
      }
    } on Object catch (_) {
      // Never the exception's own text (could be a secure-storage failure).
      if (!ref.mounted) return null;
      state = state.copyWith(busy: false, error: const AuthError.failed());
      return UnlockOutcome.refused;
    }
  }

  /// Runs [remove] (the account removal, which also routes to Welcome) with
  /// the screen held busy. False → it failed and the error is in state.
  Future<bool> startOver(Future<bool> Function() remove) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, error: null);
    final ok = await remove();
    if (!ref.mounted) return ok;
    state = state.copyWith(busy: false, error: ok ? null : const AuthError.removeFailed());
    return ok;
  }
}

final NotifierProvider<UnlockController, UnlockState> unlockControllerProvider =
    NotifierProvider.autoDispose<UnlockController, UnlockState>(UnlockController.new);

// ── Merge or discard ────────────────────────────────────────────────────────

@immutable
class MergeChoiceState {
  const MergeChoiceState({this.busy = false, this.error, this.started});
  final bool busy;
  final AuthError? error;

  /// A choice a previous attempt started and did not finish. Once one has
  /// begun only it is offered — after a merge's rows committed, Remove would
  /// delete the merged records' attachments.
  final MergeChoice? started;

  MergeChoiceState copyWith({bool? busy, Object? error = _unset, Object? started = _unset}) => MergeChoiceState(
        busy: busy ?? this.busy,
        error: identical(error, _unset) ? this.error : error as AuthError?,
        started: identical(started, _unset) ? this.started : started as MergeChoice?,
      );

  @override
  bool operator ==(Object other) =>
      other is MergeChoiceState && other.busy == busy && other.error == error && other.started == started;

  @override
  int get hashCode => Object.hash(busy, error, started);
}

/// Runs the merge-or-discard choice through [GoOnlineController] and keeps
/// the choice already in progress, read from storage.
class MergeOrDiscardController extends Notifier<MergeChoiceState> {
  @override
  MergeChoiceState build() {
    unawaited(_loadStarted());
    return const MergeChoiceState();
  }

  Future<void> _loadStarted() async {
    final MergeChoice? started;
    try {
      started = await ref.read(goOnlineControllerProvider).pendingChoice();
    } on Object catch (_) {
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(started: started);
  }

  /// True → the account is online; it stays busy while the caller enters the
  /// app, and [settle] releases it. False → the error is in state.
  Future<bool> run(MergeChoice choice) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, error: null);
    final controller = ref.read(goOnlineControllerProvider);
    AppResult<void>? r;
    try {
      r = await switch (choice) {
        MergeChoice.merge => controller.merge(),
        MergeChoice.discard => controller.discard(),
      };
    } on Object catch (_) {
      // Never the exception's text; the choice can simply be made again.
      r = null;
    }
    if (!ref.mounted) return false;
    if (r != null && r.isSuccess) return true;
    state = state.copyWith(busy: false, error: const AuthError.failed());
    await _loadStarted();
    return false;
  }

  /// The caller finished entering the app after a successful [run].
  void settle() => state = state.copyWith(busy: false);
}

final NotifierProvider<MergeOrDiscardController, MergeChoiceState> mergeOrDiscardControllerProvider =
    NotifierProvider.autoDispose<MergeOrDiscardController, MergeChoiceState>(MergeOrDiscardController.new);

// ── Disclosure gate ─────────────────────────────────────────────────────────

@immutable
class DisclosureAcceptState {
  const DisclosureAcceptState({this.submitting = false, this.error});
  final bool submitting;
  final AuthError? error;

  @override
  bool operator ==(Object other) =>
      other is DisclosureAcceptState && other.submitting == submitting && other.error == error;

  @override
  int get hashCode => Object.hash(submitting, error);
}

/// Records the disclosure acceptance through the real use case: on-device
/// persist (FR-040 snapshots), cloud sync and the domain event.
class DisclosureAcceptController extends Notifier<DisclosureAcceptState> {
  @override
  DisclosureAcceptState build() => const DisclosureAcceptState();

  /// True → persisted (the caller unlocks the app). False → error in state.
  Future<bool> accept({
    required String countryCode,
    required String supervisoryAuthority,
    required String preferredLanguage,
  }) async {
    if (state.submitting) return false;
    state = const DisclosureAcceptState(submitting: true);
    final result = await ref.read(acceptDisclosureUseCaseProvider).execute(
          disclosureId: const DisclosureId.value(kDisclosureId),
          version: kDisclosureVersion,
          countryCode: countryCode,
          supervisoryAuthority: supervisoryAuthority,
          preferredLanguage: preferredLanguage,
        );
    if (!ref.mounted) return result.isSuccess;
    // Success keeps the button busy while the gate closes.
    state = result.fold(
      (_) => const DisclosureAcceptState(submitting: true),
      (f) => DisclosureAcceptState(error: AuthError.server(f.message)),
    );
    return result.isSuccess;
  }
}

final NotifierProvider<DisclosureAcceptController, DisclosureAcceptState> disclosureAcceptControllerProvider =
    NotifierProvider.autoDispose<DisclosureAcceptController, DisclosureAcceptState>(DisclosureAcceptController.new);

// ── Go-online sheet ─────────────────────────────────────────────────────────

enum GoOnlineStep { email, code, done }

@immutable
class GoOnlineSheetState {
  const GoOnlineSheetState({this.step = GoOnlineStep.email, this.busy = false, this.error, this.secs = 0, this.email});
  final GoOnlineStep step;
  final bool busy;
  final AuthError? error;

  /// Seconds until Resend; 0 offers it.
  final int secs;

  /// The device-only account's email — the one it will be claimed under —
  /// read from storage to prefill the field. Null until read.
  final String? email;

  GoOnlineSheetState copyWith({GoOnlineStep? step, bool? busy, Object? error = _unset, int? secs, String? email}) =>
      GoOnlineSheetState(
        step: step ?? this.step,
        busy: busy ?? this.busy,
        error: identical(error, _unset) ? this.error : error as AuthError?,
        secs: secs ?? this.secs,
        email: email ?? this.email,
      );

  @override
  bool operator ==(Object other) =>
      other is GoOnlineSheetState &&
      other.step == step &&
      other.busy == busy &&
      other.error == error &&
      other.secs == secs &&
      other.email == email;

  @override
  int get hashCode => Object.hash(step, busy, error, secs, email);
}

/// What the sheet does after a verify.
enum GoOnlineVerifyResult {
  /// The account is online; the sheet shows its done step.
  online,

  /// The email already has an account: close the sheet, open merge-or-discard.
  needsMergeChoice,

  /// Refused (wrong code, lockout); the reason is in state.
  refused,

  /// Something unexpected; the reason is in state.
  failed,

  /// Something unexpected, but storage says the account did go online, so
  /// the app's gates should say so too.
  failedButOnline,
}

/// Step machine behind the go-online sheet: email → code → done, with the
/// resend countdown. [GoOnlineController] does the work.
class GoOnlineSheetController extends Notifier<GoOnlineSheetState> {
  Countdown? _countdown;

  @override
  GoOnlineSheetState build() {
    final countdown = _countdown = Countdown((secs) => state = state.copyWith(secs: secs));
    ref.onDispose(countdown.cancel);
    unawaited(_prefill());
    return const GoOnlineSheetState();
  }

  Future<void> _prefill() async {
    try {
      final creds = await ref.read(offlineAccountServiceProvider).pendingCredentials();
      if (!ref.mounted || creds == null) return;
      state = state.copyWith(email: creds.email);
    } on Object catch (_) {
      // Prefill is a convenience; the field stays editable.
    }
  }

  /// True → the code is on its way and the sheet is on the code step.
  Future<bool> sendCode(String email) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, error: null);
    final r = await ref.read(goOnlineControllerProvider).sendCode(email);
    if (!ref.mounted) return false;
    if (r.isFailure) {
      state = state.copyWith(busy: false, error: AuthError.server(r.error.message));
      return false;
    }
    state = state.copyWith(busy: false, step: GoOnlineStep.code, secs: kResendSecs);
    _countdown?.start(kResendSecs);
    return true;
  }

  /// Null while busy. The result is returned even when the sheet was
  /// dismissed mid-verify, so the caller can still update the app's gates.
  Future<GoOnlineVerifyResult?> verify({required String email, required String code}) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true, error: null);
    final controller = ref.read(goOnlineControllerProvider);
    final offline = ref.read(offlineAccountServiceProvider);
    final AppResult<GoOnlineOutcome> r;
    try {
      r = await controller.verify(email: email, code: code);
    } on Object catch (_) {
      // Unexpected (e.g. a keychain error part-way). The account may already
      // be online in storage — the caller makes the UI agree with it.
      final online = await _storedOnline(offline);
      if (ref.mounted) state = state.copyWith(busy: false, error: const AuthError.failed());
      return online ? GoOnlineVerifyResult.failedButOnline : GoOnlineVerifyResult.failed;
    }
    if (r.isFailure) {
      if (ref.mounted) {
        state = state.copyWith(
          busy: false,
          // Server text (invalid/expired code), display-safe as in sign-in.
          error: switch (r.error) {
            NetworkFailure(:final message) => AuthError.server(message),
            _ => const AuthError.failed(),
          },
        );
      }
      return GoOnlineVerifyResult.refused;
    }
    switch (r.value) {
      case GoOnlineOnline():
        _countdown?.cancel();
        if (ref.mounted) state = state.copyWith(busy: false, step: GoOnlineStep.done);
        return GoOnlineVerifyResult.online;
      case GoOnlineNeedsMergeChoice():
        if (ref.mounted) state = state.copyWith(busy: false);
        return GoOnlineVerifyResult.needsMergeChoice;
      case GoOnlineLockedOut(:final until):
        if (ref.mounted) {
          final secs = until.difference(DateTime.now()).inSeconds.clamp(0, 3600);
          state = state.copyWith(busy: false, error: AuthError.lockout(secs));
        }
        return GoOnlineVerifyResult.refused;
    }
  }

  static Future<bool> _storedOnline(OfflineAccountService offline) async {
    try {
      return await offline.mode() == AccountMode.online;
    } on Object catch (_) {
      return false;
    }
  }
}

final NotifierProvider<GoOnlineSheetController, GoOnlineSheetState> goOnlineSheetControllerProvider =
    NotifierProvider.autoDispose<GoOnlineSheetController, GoOnlineSheetState>(GoOnlineSheetController.new);
