import 'dart:async';

import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Typed auth-flow errors. The screens map kinds onto localized strings —
/// controllers never touch the string bundles.
enum AuthErrorKind { lockout, invalidCredentials, server }

@immutable
class AuthError {
  const AuthError.lockout(this.lockoutSecs)
      : kind = AuthErrorKind.lockout,
        message = null;
  const AuthError.invalidCredentials()
      : kind = AuthErrorKind.invalidCredentials,
        message = null,
        lockoutSecs = 0;
  const AuthError.server(this.message)
      : kind = AuthErrorKind.server,
        lockoutSecs = 0;

  final AuthErrorKind kind;

  /// Server-provided text (already display-safe) for [AuthErrorKind.server].
  final String? message;
  final int lockoutSecs;
}

int _lockoutSecs(SignInLockout lockout) => lockout.session.until.difference(DateTime.now()).inSeconds.clamp(0, 3600);

// ── Credentials step ────────────────────────────────────────────────────────

@immutable
class CredentialsState {
  const CredentialsState({this.submitting = false, this.error});
  final bool submitting;
  final AuthError? error;
}

/// Data controller for the email + password step: password sign-in and the
/// sign-up OTP request. The screen keeps text controllers and the
/// password-visibility toggle (view state).
class CredentialsController extends AutoDisposeNotifier<CredentialsState> {
  @override
  CredentialsState build() => const CredentialsState();

  /// True → session established (caller navigates). Failures land in state.
  Future<bool> signIn({required String email, required String password}) async {
    state = const CredentialsState(submitting: true);
    final result = await ref.read(signInUseCaseProvider).passwordSignIn(email: email, password: password);
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

  /// True → OTP sent (caller routes to the verification step).
  Future<bool> requestSignupOtp({required String email, required String countryCode}) async {
    state = const CredentialsState(submitting: true);
    final result = await ref.read(signUpUseCaseProvider).requestEmailOtp(email, countryCode);
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
}

final credentialsControllerProvider =
    NotifierProvider.autoDispose<CredentialsController, CredentialsState>(CredentialsController.new);

// ── OTP verification step ───────────────────────────────────────────────────

@immutable
class OtpState {
  const OtpState({this.secs = 28, this.verifying = false, this.error});
  final int secs;
  final bool verifying;
  final AuthError? error;

  OtpState copyWith({int? secs, bool? verifying, Object? error = _unset}) => OtpState(
        secs: secs ?? this.secs,
        verifying: verifying ?? this.verifying,
        error: identical(error, _unset) ? this.error : error as AuthError?,
      );
  static const _unset = Object();
}

/// Data controller for the six-digit verification step: the resend countdown
/// and the verify call. On success the use case has already persisted the
/// session; the screen only navigates.
class OtpController extends AutoDisposeNotifier<OtpState> {
  Timer? _timer;

  @override
  OtpState build() {
    ref.onDispose(() => _timer?.cancel());
    _startCountdown();
    return const OtpState();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (state.secs <= 0) {
        t.cancel();
        return;
      }
      state = state.copyWith(secs: state.secs - 1);
    });
  }

  void resend() {
    state = state.copyWith(secs: 28);
    _startCountdown();
  }

  /// Null → verified; the success carries `isNewUser`. Non-null result means
  /// the error is in state and the caller clears the boxes.
  Future<bool?> verify({required String email, required String code}) async {
    if (state.verifying) return null;
    state = state.copyWith(verifying: true, error: null);
    final result = await ref.read(signInUseCaseProvider).verifyEmailOtp(email: email, code: code);
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
}

final otpControllerProvider = NotifierProvider.autoDispose<OtpController, OtpState>(OtpController.new);

// ── Forgot-password sheet ───────────────────────────────────────────────────

enum ResetStep { email, code, done }

@immutable
class PasswordResetState {
  const PasswordResetState({this.step = ResetStep.email, this.busy = false, this.error});
  final ResetStep step;
  final bool busy;
  final AuthError? error;
}

/// Step machine behind the forgot-password sheet: request the reset code,
/// then set the new password. Sheet keeps its text controllers.
class PasswordResetController extends AutoDisposeNotifier<PasswordResetState> {
  @override
  PasswordResetState build() => const PasswordResetState();

  Future<void> sendCode({required String email, required String countryCode}) async {
    if (state.busy) return;
    state = const PasswordResetState(busy: true);
    final r = await ref.read(signInUseCaseProvider).requestEmailOtp(email, countryCode);
    state = r.fold(
      (_) => const PasswordResetState(step: ResetStep.code),
      (f) => PasswordResetState(error: AuthError.server(f.message)),
    );
  }

  Future<void> reset({required String email, required String code, required String newPassword}) async {
    if (state.busy) return;
    state = const PasswordResetState(step: ResetStep.code, busy: true);
    final r = await ref.read(signInUseCaseProvider).resetPassword(email: email, code: code, newPassword: newPassword);
    state = r.fold(
      (_) => const PasswordResetState(step: ResetStep.done),
      (f) => PasswordResetState(step: ResetStep.code, error: AuthError.server(f.message)),
    );
  }
}

final passwordResetControllerProvider =
    NotifierProvider.autoDispose<PasswordResetController, PasswordResetState>(PasswordResetController.new);
