/// Auth session aggregate — represents the current authentication state.
/// PHI constraint: no PII is logged; correlation IDs only.
sealed class AuthSession {
  const AuthSession();
}

/// The user is not authenticated.
class Unauthenticated extends AuthSession {
  const Unauthenticated();
}

/// The user has a valid session.
class Authenticated extends AuthSession {
  const Authenticated({
    required this.userId,
    required this.email,
    required this.provider,
    required this.accessToken,
    required this.refreshToken,
  });

  /// Opaque user ID (UUIDv7). Not logged per PHI constraint.
  final String userId;

  /// Email address. Not logged per PHI constraint.
  final String email;

  /// Identity provider: 'email' | 'google' | 'apple'.
  final String provider;

  /// Short-lived access JWT.
  final String accessToken;

  /// Long-lived refresh token.
  final String refreshToken;

  Authenticated copyWith({
    String? userId,
    String? email,
    String? provider,
    String? accessToken,
    String? refreshToken,
  }) {
    return Authenticated(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      provider: provider ?? this.provider,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}

/// The user is locked out due to too many failed attempts.
class LockedOut extends AuthSession {
  const LockedOut({
    required this.until,
    required this.identifier,
  });

  /// When the lockout expires (UTC).
  final DateTime until;

  /// Opaque identifier (not the raw email). Used for display/retry logic.
  final String identifier;
}
