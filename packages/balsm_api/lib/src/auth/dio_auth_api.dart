import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import 'auth_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioAuthApi implements AuthApi {
  const DioAuthApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        cancelToken: cancelToken,
      );
      return response.data ?? {};
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> requestOtp(RequestOtpRequest request, {CancelToken? cancelToken}) =>
      _post('/auth/otp/request', request.toJson(), cancelToken: cancelToken);

  @override
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request,
          {CancelToken? cancelToken}) async =>
      AuthTokensResponse.fromJson(
          await _post('/auth/otp/verify', request.toJson(), cancelToken: cancelToken));

  @override
  Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request,
          {CancelToken? cancelToken}) async =>
      AuthTokensResponse.fromJson(
          await _post('/auth/google', request.toJson(), cancelToken: cancelToken));

  @override
  Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request,
          {CancelToken? cancelToken}) async =>
      AuthTokensResponse.fromJson(
          await _post('/auth/apple', request.toJson(), cancelToken: cancelToken));

  @override
  Future<void> signOut({CancelToken? cancelToken}) =>
      _post('/auth/sign-out', {}, cancelToken: cancelToken);

  @override
  Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request,
          {CancelToken? cancelToken}) async =>
      RefreshedTokensResponse.fromJson(
          await _post('/auth/refresh', request.toJson(), cancelToken: cancelToken));

  @override
  Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request,
          {CancelToken? cancelToken}) async =>
      RefreshedTokensResponse.fromJson(await _post('/auth/recovery/claim',
          request.toJson(), cancelToken: cancelToken));
}
