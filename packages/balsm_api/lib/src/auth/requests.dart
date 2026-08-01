/// PHI constraint (all auth DTOs): never log or stringify these — they
/// carry emails, device identifiers, and tokens.

/// Why an OTP email is requested. The server sends an email only for these two
/// flows — email-OTP login was removed to conserve email quota.
enum OtpPurpose { register, reset }

class RequestOtpRequest {
  const RequestOtpRequest({
    required this.email,
    required this.countryCode,
    required this.purpose,
  });
  final String email;
  final String countryCode;
  final OtpPurpose purpose;
  Map<String, dynamic> toJson() => {'email': email, 'country_code': countryCode, 'purpose': purpose.name};
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

/// POST /auth/otp/verify-link — the magic sign-in link's single-use token
/// (extracted from the `balsm://auth/link?t=` deep link). No email: the token
/// alone identifies the challenge server-side.
class VerifyLinkRequest {
  const VerifyLinkRequest({
    required this.token,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String token;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'token': token,
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
  Map<String, dynamic> toJson() => {'refresh_token': refreshToken, 'device_id': deviceId};
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

class PasswordSignInRequest {
  const PasswordSignInRequest({
    required this.email,
    required this.password,
    required this.deviceId,
    required this.deviceLabel,
  });
  final String email;
  final String password;
  final String deviceId;
  final String deviceLabel;
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'device_id': deviceId,
        'device_label': deviceLabel,
      };
}

class SetPasswordRequest {
  const SetPasswordRequest({required this.password});
  final String password;
  Map<String, dynamic> toJson() => {'password': password};
}

class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.email,
    required this.code,
    required this.newPassword,
  });
  final String email;
  final String code;
  final String newPassword;
  Map<String, dynamic> toJson() => {'email': email, 'code': code, 'new_password': newPassword};
}
