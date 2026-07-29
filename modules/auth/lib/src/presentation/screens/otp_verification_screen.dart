import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/use_cases/sign_in_use_case.dart';
import '../providers/auth_providers.dart';

/// Step 2/3: verify the 6-digit OTP sent to [email].
///
/// Auto-submits on the 6th digit via [BalsmOtpRow]. Shows error state on
/// invalid/expired codes, and a resend link gated by a 30-second countdown.
/// On success, navigates to the post-disclosure / home destination.
/// On lockout (423), routes to the lockout screen.
///
/// PHI constraint: the email is masked for display and never logged.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.countryCode = 'EG',
    this.totalSteps = 3,
    this.currentStep = 2,
  });

  final String email;
  final String countryCode;
  final int totalSteps;
  final int currentStep;

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  static const _resendCooldown = Duration(seconds: 30);

  Key _otpKey = UniqueKey();
  String? _errorText;
  bool _verifying = false;
  int _secondsLeft = _resendCooldown.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  /// Returns "u•••@example.com" style mask — never the full address.
  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return 'your email';
    final name = parts.first;
    final head = name.substring(0, 1);
    return '$head${'•' * (name.length - 1).clamp(1, 6)}@${parts.last}';
  }

  Future<void> _verify(String code) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _errorText = null;
    });

    final useCase = ref.read(signInUseCaseProvider);
    final result = await useCase.verifyEmailOtp(email: widget.email, code: code);

    if (!mounted) return;
    setState(() => _verifying = false);

    result.fold(
      (signInResult) {
        switch (signInResult) {
          case SignInSuccess():
            context.goNamed('home');
          case SignInLockout(:final session):
            context.pushNamed(
              'auth.lockout',
              queryParameters: {
                'until': session.until.toIso8601String(),
              },
            );
        }
      },
      (failure) {
        setState(() {
          _errorText = failure.message;
          // Reset the OTP boxes so the user can retry cleanly.
          _otpKey = UniqueKey();
        });
      },
    );
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    setState(() {
      _errorText = null;
      _otpKey = UniqueKey();
    });
    final useCase = ref.read(signUpUseCaseProvider);
    final result = await useCase.requestEmailOtp(widget.email, widget.countryCode);
    if (!mounted) return;
    result.fold(
      (_) => _startCountdown(),
      (failure) => setState(() => _errorText = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    BalsmRoundButton(
                      icon: const Icon(Icons.arrow_back, size: 20),
                      onTap: () => Navigator.of(context).maybePop(),
                      semanticLabel: 'Back',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BalsmStepDots(
                      totalSteps: widget.totalSteps,
                      currentStep: widget.currentStep,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Enter your code',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: BalsmColors.ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We sent a 6-digit code to $_maskedEmail.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BalsmColors.ink600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: BalsmOtpRow(
                  key: _otpKey,
                  onCompleted: _verify,
                ),
              ),
              if (_verifying) ...[
                const SizedBox(height: 24),
                const BalsmLoadingIndicator(),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: BalsmErrorBanner(message: _errorText!),
                ),
              ],
              const SizedBox(height: 24),
              // Resend
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Resend code in ${_secondsLeft}s',
                        style: const TextStyle(
                          color: BalsmColors.ink500,
                          fontSize: 14,
                        ),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text(
                          'Resend code',
                          style: TextStyle(
                            color: BalsmColors.appAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
