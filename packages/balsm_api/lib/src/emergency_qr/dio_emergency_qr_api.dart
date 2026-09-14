import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/envelope.dart';
import '../transport/network_manager.dart';
import 'emergency_qr_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioEmergencyQrApi implements EmergencyQrApi {
  const DioEmergencyQrApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<MintQrResponse> mint(MintQrRequest request, {CancelToken? cancelToken}) async {
    final res = await _net.post(
      ApiRoutes.emergency_qr_mint,
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    return MintQrResponse.fromJson(unwrapEnvelope(res));
  }

  @override
  Future<ActiveQrResponse?> active({CancelToken? cancelToken}) async {
    final res = await _net.get(
      ApiRoutes.emergency_qr_active,
      cancelToken: cancelToken,
    );
    // `data` is null when the user has no active token — not an error.
    final data = unwrapNullableEnvelope(res);
    return data == null ? null : ActiveQrResponse.fromJson(data);
  }

  @override
  Future<ResolveQrResponse> resolve(String tokenId, {CancelToken? cancelToken}) async {
    final res = await _net.get(
      ApiRoutes.emergencyQrResolve(tokenId),
      cancelToken: cancelToken,
    );
    return ResolveQrResponse.fromJson(unwrapEnvelope(res));
  }

  @override
  Future<void> updateCiphertext(String tokenId, UpdateQrCiphertextRequest request, {CancelToken? cancelToken}) async {
    final res = await _net.put(
      ApiRoutes.emergencyQrCiphertext(tokenId),
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    unwrapEnvelope(res);
  }

  @override
  Future<void> revoke(String tokenId, {CancelToken? cancelToken}) async {
    final res = await _net.post(
      ApiRoutes.emergencyQrRevoke(tokenId),
      cancelToken: cancelToken,
    );
    unwrapEnvelope(res);
  }
}
