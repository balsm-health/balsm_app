import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../application/use_cases/sign_in_use_case.dart';
import '../providers/auth_providers.dart';

/// Social sign-in: Google + Apple.
///
/// On success the obtained provider token is exchanged via [SignInUseCase],
/// which persists the Balsm session tokens and emits the sign-in event.
///
/// PHI constraint: provider tokens and email are never logged.
class SocialSignInScreen extends ConsumerStatefulWidget {
  const SocialSignInScreen({super.key, this.countryCode = 'EG'});

  final String countryCode;

  @override
  ConsumerState<SocialSignInScreen> createState() => _SocialSignInScreenState();
}

class _SocialSignInScreenState extends ConsumerState<SocialSignInScreen> {
  String? _errorText;
  bool _busy = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final account = await GoogleSignIn().signIn();
      if (account == null) {
        // User cancelled.
        if (mounted) setState(() => _busy = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _errorText = 'Could not get a Google sign-in token. Please try again.';
          });
        }
        return;
      }
      final result = await ref.read(signInUseCaseProvider).signInWithGoogle(
            idToken: idToken,
            email: account.email,
          );
      _handleResult(result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorText = 'Google sign-in failed. Please try again.';
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      final authCode = credential.authorizationCode;
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _errorText = 'Could not get an Apple sign-in token. Please try again.';
          });
        }
        return;
      }
      final result = await ref.read(signInUseCaseProvider).signInWithApple(
            idToken: idToken,
            authCode: authCode,
            email: credential.email ?? '',
          );
      _handleResult(result);
    } on SignInWithAppleAuthorizationException {
      // Includes user cancellation — fail quietly.
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorText = 'Apple sign-in failed. Please try again.';
        });
      }
    }
  }

  void _handleResult(AppResult<SignInResult> result) {
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (signInResult) {
        switch (signInResult) {
          case SignInSuccess():
            context.goNamed('home');
          case SignInLockout(:final session):
            context.pushNamed(
              'auth.lockout',
              queryParameters: {'until': session.until.toIso8601String()},
            );
        }
      },
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
                    Text(
                      'Continue with',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: BalsmColors.ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use your Google or Apple account to sign in securely.',
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
                child: BalsmButton(
                  label: 'Continue with Google',
                  variant: BalsmButtonVariant.secondary,
                  icon: Icons.login,
                  loading: _busy,
                  onPressed: _busy ? null : _signInWithGoogle,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: BalsmButton(
                  label: 'Continue with Apple',
                  variant: BalsmButtonVariant.secondary,
                  icon: Icons.apple,
                  loading: _busy,
                  onPressed: _busy ? null : _signInWithApple,
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: BalsmErrorBanner(message: _errorText!),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
