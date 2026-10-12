/// Outcome of asking a social provider (Google, Apple) for credentials.
///
/// The three cases are distinguished because the UI must treat them
/// differently: a cancellation is not a failure and must stay silent, while a
/// missing ID token points at platform configuration rather than the user.
///
/// PHI constraint: never log or stringify these — they carry provider tokens
/// and the account email.
sealed class SocialCredentialsResult {
  const SocialCredentialsResult();
}

/// The provider authenticated the user and returned a usable ID token.
final class SocialCredentials extends SocialCredentialsResult {
  const SocialCredentials({
    required this.idToken,
    this.authorizationCode = '',
    this.email = '',
    this.givenName,
    this.familyName,
  });

  /// The OIDC ID token the API validates.
  final String idToken;

  /// Apple's single-use authorization code; empty for Google.
  final String authorizationCode;

  /// Empty when the provider withheld it (Apple's "Hide My Email" still returns
  /// a relay address, but the claim is absent on repeat authorizations).
  final String email;

  /// Apple returns the name **only on the very first authorization** for an
  /// Apple ID and never again, so a caller that wants it must capture it then.
  /// Google returns it on every sign-in.
  final String? givenName;
  final String? familyName;
}

/// The user dismissed the provider sheet. Not an error — show nothing.
final class SocialCredentialsCancelled extends SocialCredentialsResult {
  const SocialCredentialsCancelled();
}

/// The flow failed, or completed without a usable ID token.
final class SocialCredentialsFailure extends SocialCredentialsResult {
  const SocialCredentialsFailure({this.missingToken = false});

  /// True when the provider authenticated but handed back no ID token. On
  /// Android that is the signature of an unconfigured `serverClientId`.
  final bool missingToken;
}

/// Obtains native provider credentials for a social sign-in exchange.
///
/// The SDK lives behind this port so the app shell can drive the flow — and
/// tests can fake it — without depending on `google_sign_in` or
/// `sign_in_with_apple` itself.
abstract interface class SocialCredentialsPort {
  Future<SocialCredentialsResult> obtain();
}
