import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'account_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioAccountApi implements AccountApi {
  const DioAccountApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<AccountSelfResponse?> getSelf({CancelToken? cancelToken}) async {
    try {
      final res = await _net.get(ApiRoutes.accountSelf, cancelToken: cancelToken);
      final data = unwrapEnvelope(res);
      if (data.isEmpty) return null;
      return AccountSelfResponse.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<ClaimHandleResponse> claimHandle(ClaimHandleRequest request,
      {CancelToken? cancelToken}) async {
    final res = await _net.post(
      ApiRoutes.accountHandleClaim,
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    return ClaimHandleResponse.fromJson(unwrapEnvelope(res));
  }

  @override
  Future<void> changeLanguage(ChangeLanguageRequest request,
      {CancelToken? cancelToken}) async {
    final res = await _net.post(
      ApiRoutes.accountLanguage,
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    unwrapEnvelope(res);
  }

  @override
  Future<void> changeCountry(ChangeCountryRequest request,
      {CancelToken? cancelToken}) async {
    final res = await _net.post(
      ApiRoutes.accountCountry,
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    unwrapEnvelope(res);
  }

  @override
  Future<HandleAvailabilityResponse> checkHandleAvailability(String handle,
      {CancelToken? cancelToken}) async {
    final res = await _net.get(
      ApiRoutes.accountHandleAvailable,
      queryParameters: {'handle': handle},
      cancelToken: cancelToken,
    );
    return HandleAvailabilityResponse.fromJson(unwrapEnvelope(res));
  }
}
