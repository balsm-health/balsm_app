/// PHI constraint (all auth DTOs): never log or stringify these — they
/// carry emails, device identifiers, and tokens.
class RequestOtpRequest {
  const RequestOtpRequest({required this.email, required this.countryCode});
  final String email;
  final String countryCode;
  Map<String, dynamic> toJson() => {'email': email, 'country_code': countryCode};
}

class VerifyOtpRequest {
  const VerifyOtpRequest({
    required this.email,
    required this.code,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String email;
  final String code;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'email': email,
        'code': code,
        'device_id': deviceId,
        'device_label': deviceLabel,
      };
}

class GoogleSignInRequest {
  const GoogleSignInRequest({
    required this.idToken,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String idToken;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'id_token': idToken,
        'device_id': deviceId,
        'device_label': deviceLabel,
      };
}

class AppleSignInRequest {
  const AppleSignInRequest({
    required this.idToken,
    required this.authorizationCode,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String idToken;
  final String authorizationCode;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'id_token': idToken,
        'authorization_code': authorizationCode,
        'device_id': deviceId,
        'device_label': deviceLabel,
      };
}

class RefreshTokenRequest {
  const RefreshTokenRequest({required this.refreshToken, required this.deviceId});
  final String refreshToken;
  final String deviceId;
  Map<String, dynamic> toJson() =>
      {'refresh_token': refreshToken, 'device_id': deviceId};
}

class RecoveryClaimRequest {
  const RecoveryClaimRequest({
    required this.recoveryToken,
    required this.newEmail,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String recoveryToken;
  final String newEmail;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'recovery_token': recoveryToken,
        'new_email': newEmail,
        'device_id': deviceId,
        'device_label': deviceLabel,
      };
}
