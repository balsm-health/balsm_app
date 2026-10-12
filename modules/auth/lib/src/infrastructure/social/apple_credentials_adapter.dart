import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../application/ports/social_credentials_port.dart';

/// Apple implementation of [SocialCredentialsPort], using the native iOS flow.
///
/// iOS only. The Android/web flow authenticates through a Service ID, whose id
/// becomes the token's `aud` — a different audience than the bundle id the API
/// validates, so it would need server-side support before it can be offered.
class AppleCredentialsAdapter implements SocialCredentialsPort {
  const AppleCredentialsAdapter();

  @override
  Future<SocialCredentialsResult> obtain() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) return const SocialCredentialsFailure(missingToken: true);

      return SocialCredentials(
        idToken: idToken,
        authorizationCode: credential.authorizationCode,
        email: credential.email ?? '',
        // Populated only on the first authorization for this Apple ID.
        givenName: credential.givenName,
        familyName: credential.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      // Dismissing the sheet raises the same exception type as a real error;
      // only `canceled` means the user chose to back out.
      return e.code == AuthorizationErrorCode.canceled
          ? const SocialCredentialsCancelled()
          : const SocialCredentialsFailure();
    } catch (_) {
      return const SocialCredentialsFailure();
    }
  }
}
