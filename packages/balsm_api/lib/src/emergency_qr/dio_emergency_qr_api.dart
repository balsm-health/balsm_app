import 'package:dio/dio.dart';

import '../transport/api_exception.dart';
import '../transport/envelope.dart';
import 'emergency_qr_api.dart';
import 'requests.dart';
import 'responses.dart';

class DioEmergencyQrApi implements EmergencyQrApi {
  const DioEmergencyQrApi({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<MintQrResponse> mint(MintQrRequest request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/emergency-qr/mint',
        data: request.toJson(),
      );
      return MintQrResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<ResolveQrResponse> resolve(String tokenId) async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/emergency-qr/resolve/$tokenId');
      return ResolveQrResponse.fromJson(unwrapEnvelope(res));
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  @override
  Future<void> revoke(RevokeQrRequest request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/emergency-qr/revoke',
        data: request.toJson(),
      );
      unwrapEnvelope(res);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
