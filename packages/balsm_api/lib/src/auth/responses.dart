/// Auth endpoints return FLAT bodies — token fields at the top level,
/// no {data, error} envelope.
class AuthTokensResponse {
  const AuthTokensResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    this.isNewUser = false,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final bool isNewUser;

  factory AuthTokensResponse.fromJson(Map<String, dynamic> json) =>
      AuthTokensResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        userId: json['user_id'] as String,
        isNewUser: (json['is_new_user'] as bool?) ?? false,
      );
}

class RefreshedTokensResponse {
  const RefreshedTokensResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  factory RefreshedTokensResponse.fromJson(Map<String, dynamic> json) =>
      RefreshedTokensResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
      );
}
