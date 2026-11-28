import 'dart:async';

import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import 'auth_flow.dart' show enterAfterSignIn;
import 'social_providers.dart';

/// Sign in with Apple and Google, then "or with email" — auth.jsx
/// `SocialButtons` + `OrDivider` on the Welcome and email screens.
///
/// Draws nothing, and holds no space, when this build offers no provider
/// ([availableSocialProviders]). A provider's outcome: cancel says nothing;
/// a failure says why under the divider; success enters the app directly
/// (a new account's name, when the provider gave one, prefills Personal
/// details — the Profile tab's gaps card owns completion).
class SocialSignInBlock extends ConsumerStatefulWidget {
  const SocialSignInBlock({super.key, required this.compact});

  /// The email screen's denser variant: 48 px buttons instead of 52, and an
  /// 18 px gap to the email field instead of 14 px to "Create an account".
  final bool compact;

  @override
  ConsumerState<SocialSignInBlock> createState() => _SocialSignInBlockState();
}

class _SocialSignInBlockState extends ConsumerState<SocialSignInBlock> {
  /// The provider whose flow is running; both buttons are inert while set.
  SocialProvider? _busy;
  String? _error;

  Future<void> _signIn(PatientAppState s, SocialProvider provider) async {
    if (_busy != null) return;
    setState(() {
      _busy = provider;
      _error = null;
    });

    final port = switch (provider) {
      SocialProvider.apple => ref.read(appleCredentialsPortProvider),
      SocialProvider.google => ref.read(googleCredentialsPortProvider),
    };
    final credentials = await port.obtain();
    if (!mounted) return;

    switch (credentials) {
      case SocialCredentialsCancelled():
        // The user backed out of the provider sheet — say nothing.
        setState(() => _busy = null);
        return;
      case SocialCredentialsFailure(:final missingToken):
        setState(() {
          _busy = null;
          _error = missingToken ? s.strings.auth.social_unavailable : s.strings.auth.social_failed;
        });
        return;
      case SocialCredentials():
        break;
    }

    final useCase = ref.read(signInUseCaseProvider);
    final AppResult<SignInResult> result;
    try {
      result = await switch (provider) {
        SocialProvider.apple => useCase.signInWithApple(
            idToken: credentials.idToken,
            authCode: credentials.authorizationCode,
            nonce: credentials.nonce,
            email: credentials.email,
            countryCode: s.country.value,
          ),
        SocialProvider.google => useCase.signInWithGoogle(
            idToken: credentials.idToken,
            email: credentials.email,
            countryCode: s.country.value,
          ),
      };
    } on Object catch (_) {
      // The use case reports failures as values; this is a bug or a platform
      // fault. Never surface the exception's text — say it failed and stop.
      if (mounted) setState(() => _error = s.strings.auth.social_failed);
      return;
    } finally {
      // Cleared even if the use case throws, so the buttons never stay inert.
      if (mounted) setState(() => _busy = null);
    }
    if (!mounted) return;

    result.fold(
      (signInResult) {
        switch (signInResult) {
          case SignInSuccess(:final isNewUser):
            if (isNewUser) {
              // The provider hands the name over now (Apple only on the first
              // authorization) — prefill Personal details.
              s.setSocialName(givenName: credentials.givenName, familyName: credentials.familyName);
            }
            unawaited(enterAfterSignIn(context, ref, s));
          case SignInLockout(:final session):
            final secsLeft = session.until.difference(DateTime.now()).inSeconds.clamp(0, 3600);
            setState(() => _error = s.strings.auth.auth_locked_retry(secsLeft.toString()));
        }
      },
      (failure) => setState(
        () => _error = switch (failure) {
          // Not offered (404: e.g. switched off for new accounts) or not in
          // this country (403 CountryDenied): point at email instead.
          NotFoundFailure() || GeofenceFailure() => s.strings.auth.social_unavailable,
          // The provider's token did not check out (401): try again.
          UnauthorizedFailure() => s.strings.auth.social_failed,
          _ => failure.message,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providers = availableSocialProviders(
      config: FlavorConfig.current,
      platform: defaultTargetPlatform,
      isWeb: kIsWeb,
    );
    if (providers.isEmpty) return const SizedBox.shrink();

    final s = AppScope.of(context);
    final height = widget.compact ? 48.0 : 52.0;
    return Column(
      children: [
        for (final (i, provider) in providers.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          _SocialButton(
            provider: provider,
            label: switch (provider) {
              SocialProvider.apple => s.strings.onboarding.w_apple,
              SocialProvider.google => s.strings.onboarding.w_google,
            },
            height: height,
            busy: _busy == provider,
            onTap: _busy == null ? () => unawaited(_signIn(s, provider)) : null,
          ),
        ],
        const SizedBox(height: 14),
        _OrDivider(label: s.strings.onboarding.w_or_email, ar: s.rtl),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: Typo.meta(ar: s.rtl).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        SizedBox(height: widget.compact ? 18 : 14),
      ],
    );
  }
}

/// auth.jsx `OrDivider`: the label between two ink-200 hairlines. Hidden from
/// screen readers, as in the design — the buttons and fields say it all.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label, required this.ar});
  final String label;
  final bool ar;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Row(
          children: [
            const Expanded(child: ColoredBox(color: AppColors.ink200, child: SizedBox(height: 1))),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
              child: Text(label, style: Typo.meta(ar: ar)),
            ),
            const Expanded(child: ColoredBox(color: AppColors.ink200, child: SizedBox(height: 1))),
          ],
        ),
      );
}

/// auth.jsx `SocialButtons` button: Apple black with a white mark, Google
/// white with an ink-200 border and the four-colour "G".
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.provider,
    required this.label,
    required this.height,
    required this.onTap,
    required this.busy,
  });
  final SocialProvider provider;
  final String label;
  final double height;

  /// Spinner in place of the mark + label while this provider's flow runs.
  final bool busy;

  /// Null while any provider flow is in flight, so neither button re-enters.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final dark = provider == SocialProvider.apple;
    final foreground = dark ? AppColors.white : AppColors.textPrimary;
    // Inactive because the OTHER provider's flow is running: dim it, as PButton does.
    final dimmed = onTap == null && !busy;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      // Screen readers hear progress while this provider's flow runs.
      value: busy ? s.strings.common.loading : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: dark ? AppColors.nearBlack : AppColors.white,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: dark ? AppColors.nearBlack : AppColors.ink200),
            ),
            child: busy
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.string(dark ? _kAppleSvg : _kGoogleGSvg, width: 18, height: 18),
                      const SizedBox(width: 10),
                      // Flexible, not bare: the label is translated and text-scaled,
                      // so a fixed-width row overflows on a narrow phone in Arabic.
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: foreground),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// auth.jsx `AppleIcon`, its `currentColor` fixed to the button's white.
const _kAppleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#FFFFFF" d="M17.05 20.28c-.98.95-2.05.86-3.08.38-1.08-.49-2.07-.48-3.2 0-1.42.61-2.17.44-3.05-.38C2.38 14.9 3.2 7.05 9.32 6.72c1.35.07 2.28.74 3.07.8 1.16-.22 2.27-.92 3.5-.83 1.5.12 2.63.72 3.36 1.82-3.1 1.86-2.37 5.95.48 7.1-.57 1.53-1.31 3.04-2.68 4.67zM12.03 6.65c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/>
</svg>
''';

const _kGoogleGSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
</svg>
''';
