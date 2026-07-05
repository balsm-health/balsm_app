import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';

/// Step 1/3 of email sign-up: collect the email address and request an OTP.
///
/// On "Continue" the [SignUpUseCase.requestEmailOtp] is invoked; on success the
/// router navigates to the OTP verification screen, passing the email along.
///
/// PHI constraint: the email address is never logged.
class EmailSignUpScreen extends ConsumerStatefulWidget {
  const EmailSignUpScreen({
    super.key,
    this.countryCode = 'EG',
    this.totalSteps = 3,
    this.currentStep = 1,
  });

  /// ISO 3166-1 alpha-2 country code chosen in the previous step.
  final String countryCode;
  final int totalSteps;
  final int currentStep;

  @override
  ConsumerState<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends ConsumerState<EmailSignUpScreen> {
  final _emailController = TextEditingController();
  String _email = '';
  String? _errorText;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _isValidEmail {
    final value = _email.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _continue() async {
    if (!_isValidEmail) {
      setState(() => _errorText = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final useCase = ref.read(signUpUseCaseProvider);
    final result = await useCase.requestEmailOtp(_email.trim(), widget.countryCode);

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (_) => context.pushNamed(
        'auth.otpVerification',
        queryParameters: {'email': _email.trim()},
      ),
      (failure) => setState(() => _errorText = failure.message),
    );
  }

  void _continueWithSocial() {
    context.pushNamed('auth.socialSignIn');
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
              // Header
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
                      'What\'s your email?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: BalsmColors.ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We\'ll send you a 6-digit code to confirm it\'s you.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: BalsmColors.ink600,
                      ),
                    ),
                  ],
                ),
              ),
              // Email field
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: BalsmField.email(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _emailController,
                  errorText: _errorText,
                  autofocus: true,
                  enabled: !_submitting,
                  onChanged: (v) => setState(() {
                    _email = v;
                    if (_errorText != null) _errorText = null;
                  }),
                  onSubmitted: (_) => _continue(),
                ),
              ),
              const SizedBox(height: 24),
              // Continue CTA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: BalsmButton(
                  label: 'Continue',
                  loading: _submitting,
                  onPressed: _submitting ? null : _continue,
                ),
              ),
              const SizedBox(height: 24),
              // Divider "or continue with"
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: BalsmColors.border)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or continue with',
                        style: TextStyle(color: BalsmColors.ink500, fontSize: 13),
                      ),
                    ),
                    Expanded(child: Divider(color: BalsmColors.border)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: BalsmButton(
                  label: 'Google or Apple',
                  variant: BalsmButtonVariant.secondary,
                  onPressed: _submitting ? null : _continueWithSocial,
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
