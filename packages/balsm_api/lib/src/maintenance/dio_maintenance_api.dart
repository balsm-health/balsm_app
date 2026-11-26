import 'package:dio/dio.dart' show CancelToken;

import '../api_routes.dart';
import '../transport/network_manager.dart';
import 'maintenance_api.dart';
import 'responses.dart';

class DioMaintenanceApi implements MaintenanceApi {
  const DioMaintenanceApi({required NetworkManager net}) : _net = net;

  final NetworkManager _net;

  @override
  Future<MaintenanceStatusResponse> getStatus({CancelToken? cancelToken}) async {
    final res = await _net.get(ApiRoutes.maintenance, cancelToken: cancelToken);
    // A decoded JSON object: its values are untyped until each field is read and checked.
    final body = res.data ?? const <String, dynamic>{};
    final data = body['data'];
    return MaintenanceStatusResponse.fromJson(data is Map<String, dynamic> ? data : body);
  }
}
