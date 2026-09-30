/// Auth token payloads. The wire body is enveloped (`{ data: { access_token,
/// … } }`); `DioAuthApi` unwraps the envelope, so these `fromJson` factories
/// receive the inner `data` map with the token fields at the top level.
class AuthTokensResponse {
  const AuthTokensResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    this.isNewUser = false,
    this.adoptedClientId = false,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final bool isNewUser;

  /// Whether the server kept the client-supplied `client_account_id` as the
  /// account's id (see [VerifyOtpRequest.clientAccountId]).
  final bool adoptedClientId;

  factory AuthTokensResponse.fromJson(Map<String, dynamic> json) => AuthTokensResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        userId: json['user_id'] as String,
        isNewUser: (json['is_new_user'] as bool?) ?? false,
        adoptedClientId: (json['adopted_client_id'] as bool?) ?? false,
      );
}

class RefreshedTokensResponse {
  const RefreshedTokensResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory RefreshedTokensResponse.fromJson(Map<String, dynamic> json) => RefreshedTokensResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      );
}
