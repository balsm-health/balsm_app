import 'package:go_router/go_router.dart';

import 'screens/auth_recovery_claim_screen.dart';
import 'screens/auth_recovery_explainer_screen.dart';
import 'screens/auth_under_eighteen_screen.dart';
import 'screens/country_picker_screen.dart';
import 'screens/email_sign_up_screen.dart';
import 'screens/lockout_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/social_sign_in_screen.dart';

/// go_router fragment for the auth bounded context.
///
/// Wired into the app shell's router (the shell owns the root `GoRouter`).
/// Country code flows through query parameters so the email/OTP steps can apply
/// the correct data-protection rules without holding global state.
final authRoutes = <RouteBase>[
  GoRoute(
    path: '/auth/country',
    name: 'auth.countryPicker',
    builder: (context, state) => CountryPickerScreen(
      onCountrySelected: (code) => context.pushNamed(
        'auth.emailSignUp',
        queryParameters: {'country': code},
      ),
    ),
  ),
  GoRoute(
    path: '/auth/email',
    name: 'auth.emailSignUp',
    builder: (context, state) => EmailSignUpScreen(
      countryCode: state.uri.queryParameters['country'] ?? 'EG',
    ),
  ),
  GoRoute(
    path: '/auth/otp',
    name: 'auth.otpVerification',
    builder: (context, state) => OtpVerificationScreen(
      email: state.uri.queryParameters['email'] ?? '',
      countryCode: state.uri.queryParameters['country'] ?? 'EG',
    ),
  ),
  GoRoute(
    path: '/auth/social',
    name: 'auth.socialSignIn',
    builder: (context, state) => SocialSignInScreen(
      countryCode: state.uri.queryParameters['country'] ?? 'EG',
    ),
  ),
  GoRoute(
    path: '/auth/lockout',
    name: 'auth.lockout',
    builder: (context, state) => LockoutScreen(
      lockedUntil: DateTime.tryParse(state.uri.queryParameters['until'] ?? '') ??
          DateTime.now().add(const Duration(minutes: 15)),
    ),
  ),
  GoRoute(
    path: '/auth/recovery',
    name: 'auth.recovery',
    builder: (context, state) => const AuthRecoveryExplainerScreen(),
  ),
  GoRoute(
    path: '/auth/recovery/claim',
    name: 'auth.recoveryClaim',
    builder: (context, state) => AuthRecoveryClaimScreen(
      token: state.uri.queryParameters['token'] ?? '',
    ),
  ),
  GoRoute(
    path: '/auth/under-18',
    name: 'auth.underEighteen',
    builder: (context, state) => const AuthUnderEighteenScreen(),
  ),
];
