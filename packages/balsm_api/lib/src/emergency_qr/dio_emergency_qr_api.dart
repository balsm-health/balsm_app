import 'package:dio/dio.dart' show CancelToken;

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
      '/emergency-qr/mint',
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    return MintQrResponse.fromJson(unwrapEnvelope(res));
  }

  @override
  Future<ResolveQrResponse> resolve(String tokenId, {CancelToken? cancelToken}) async {
    final res = await _net.get(
      '/emergency-qr/resolve/$tokenId',
      cancelToken: cancelToken,
    );
    return ResolveQrResponse.fromJson(unwrapEnvelope(res));
  }

  @override
  Future<void> revoke(RevokeQrRequest request, {CancelToken? cancelToken}) async {
    final res = await _net.post(
      '/emergency-qr/revoke',
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    unwrapEnvelope(res);
  }
}
