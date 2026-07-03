import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/network_manager.dart';
import 'auth_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioAuthApi implements AuthApi {
  const DioAuthApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  /// Auth bodies are FLAT (no `{data, error}` envelope) — return them as-is.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    final res = await _net.post(path, data: body, cancelToken: cancelToken);
    return res.data ?? {};
  }

  @override
  Future<void> requestOtp(RequestOtpRequest request, {CancelToken? cancelToken}) =>
      _post(ApiRoutes.auth_otp_request, request.toJson(), cancelToken: cancelToken);

  @override
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request,
          {CancelToken? cancelToken}) async =>
      AuthTokensResponse.fromJson(
          await _post(ApiRoutes.auth_otp_verify, request.toJson(), cancelToken: cancelToken));

  @override
  Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request,
          {CancelToken? cancelToken}) async =>
      AuthTokensResponse.fromJson(
          await _post(ApiRoutes.auth_google, request.toJson(), cancelToken: cancelToken));

  @override
  Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request,
          {CancelToken? cancelToken}) async =>
      AuthTokensResponse.fromJson(
          await _post(ApiRoutes.auth_apple, request.toJson(), cancelToken: cancelToken));

  @override
  Future<void> signOut({CancelToken? cancelToken}) =>
      _post(ApiRoutes.auth_sign_out, {}, cancelToken: cancelToken);

  @override
  Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request,
          {CancelToken? cancelToken}) async =>
      RefreshedTokensResponse.fromJson(
          await _post(ApiRoutes.auth_refresh, request.toJson(), cancelToken: cancelToken));

  @override
  Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request,
          {CancelToken? cancelToken}) async =>
      RefreshedTokensResponse.fromJson(await _post(ApiRoutes.auth_recovery_claim,
          request.toJson(), cancelToken: cancelToken));
}
