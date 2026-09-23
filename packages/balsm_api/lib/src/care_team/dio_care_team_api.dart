import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'care_team_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioCareTeamApi implements CareTeamApi {
  const DioCareTeamApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<List<CareProviderResponse>> pull({
    required String healthProfileId,
    DateTime? since,
    CancelToken? cancelToken,
  }) async {
    final res = await _net.get(
      ApiRoutes.care_team_providers,
      queryParameters: {
        'health_profile_id': healthProfileId,
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
      cancelToken: cancelToken,
    );
    return unwrapEnvelopeList(res).map((e) => CareProviderResponse.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> upsert(UpsertCareProviderRequest request, {CancelToken? cancelToken}) async {
    final res = await _net.post(
      ApiRoutes.care_team_providers,
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    unwrapEnvelope(res);
  }

  @override
  Future<void> delete(String id, {CancelToken? cancelToken}) async {
    try {
      await _net.delete(ApiRoutes.careTeamProvider(id), cancelToken: cancelToken);
    } on ApiException catch (e) {
      // Already gone server-side is the outcome we wanted, not a failure to retry.
      if (e.statusCode == 404) return;
      rethrow;
    }
  }
}
