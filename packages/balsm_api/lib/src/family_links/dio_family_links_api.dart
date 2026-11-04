import 'package:dio/dio.dart' show CancelToken, Response;

import '../api_routes.dart';
import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'family_links_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioFamilyLinksApi implements FamilyLinksApi {
  const DioFamilyLinksApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<void> create(CreateFamilyLinkRequest request, {CancelToken? cancelToken}) async {
    final res = await _net.post(ApiRoutes.family_links, data: request.toJson(), cancelToken: cancelToken);
    unwrapEnvelope(res);
  }

  @override
  Future<List<FamilyLinkResponse>> incoming({String? status, CancelToken? cancelToken}) async {
    final res = await _net.get(
      ApiRoutes.family_links_incoming,
      queryParameters: {if (status != null) 'status': status},
      cancelToken: cancelToken,
    );
    return _rows(res, 'incoming');
  }

  @override
  Future<List<FamilyLinkResponse>> outgoing({CancelToken? cancelToken}) async {
    final res = await _net.get(ApiRoutes.family_links_outgoing, cancelToken: cancelToken);
    return _rows(res, 'outgoing');
  }

  @override
  Future<FamilyLinkResponse> get(String id, {CancelToken? cancelToken}) async {
    final res = await _net.get(ApiRoutes.familyLink(id), cancelToken: cancelToken);
    return FamilyLinkResponse.fromJson(unwrapEnvelope(res));
  }

  @override
  Future<void> approve(String id, FamilyLinkKeyRequest request, {CancelToken? cancelToken}) async {
    final res = await _net.post(ApiRoutes.familyLinkApprove(id), data: request.toJson(), cancelToken: cancelToken);
    unwrapEnvelope(res);
  }

  @override
  Future<void> decline(String id, {CancelToken? cancelToken}) async {
    final res = await _net.post(ApiRoutes.familyLinkDecline(id), cancelToken: cancelToken);
    unwrapEnvelope(res);
  }

  @override
  Future<void> delete(String id, {CancelToken? cancelToken}) =>
      _goneIsFine(() => _net.delete(ApiRoutes.familyLink(id), cancelToken: cancelToken));

  @override
  Future<void> putKeys(String id, FamilyLinkKeyRequest request, {CancelToken? cancelToken}) async {
    await _net.put(ApiRoutes.familyLinkKeys(id), data: request.toJson(), cancelToken: cancelToken);
  }

  @override
  Future<void> putCard(String id, PutSealedCardRequest request, {CancelToken? cancelToken}) async {
    await _net.put(ApiRoutes.familyLinkCard(id), data: request.toJson(), cancelToken: cancelToken);
  }

  @override
  Future<SealedCardResponse?> getCard(String id, {CancelToken? cancelToken}) async {
    try {
      final res = await _net.get(ApiRoutes.familyLinkCard(id), cancelToken: cancelToken);
      final data = unwrapNullableEnvelope(res);
      return data == null ? null : SealedCardResponse.fromJson(data);
    } on ApiException catch (e) {
      // "None shared" is an answer, not a failure.
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> deleteCard(String id, {CancelToken? cancelToken}) =>
      _goneIsFine(() => _net.delete(ApiRoutes.familyLinkCard(id), cancelToken: cancelToken));

  /// The list endpoints are paged; rows arrive as `data` itself or as
  /// `data.items`.
  static List<FamilyLinkResponse> _rows(Response<dynamic> res, String direction) {
    final body = res.data;
    final data = body is Map<String, dynamic> ? body['data'] : null;
    final rows = data is Map<String, dynamic> ? data['items'] : null;
    final list = rows is List ? rows : unwrapEnvelopeList(res);
    return [
      for (final row in list) FamilyLinkResponse.fromJson(row as Map<String, dynamic>, fallbackDirection: direction),
    ];
  }

  /// A delete whose target is already gone reached the outcome the caller wanted.
  static Future<void> _goneIsFine(Future<Object?> Function() call) async {
    try {
      await call();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return;
      rethrow;
    }
  }
}
