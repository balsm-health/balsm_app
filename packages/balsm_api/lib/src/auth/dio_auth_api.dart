import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import 'auth_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioAuthApi implements AuthApi {
  const DioAuthApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> requestOtp(RequestOtpRequest request) =>
      _post('/auth/otp/request', request.toJson());

  @override
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request) async =>
      AuthTokensResponse.fromJson(await _post('/auth/otp/verify', request.toJson()));

  @override
  Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request) async =>
      AuthTokensResponse.fromJson(await _post('/auth/google', request.toJson()));

  @override
  Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request) async =>
      AuthTokensResponse.fromJson(await _post('/auth/apple', request.toJson()));

  @override
  Future<void> signOut() => _post('/auth/sign-out', {});

  @override
  Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request) async =>
      RefreshedTokensResponse.fromJson(await _post('/auth/refresh', request.toJson()));

  @override
  Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request) async =>
      RefreshedTokensResponse.fromJson(
          await _post('/auth/recovery/claim', request.toJson()));
}
