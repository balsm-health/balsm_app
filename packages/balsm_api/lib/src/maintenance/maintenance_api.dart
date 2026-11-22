import 'package:dio/dio.dart' show CancelToken;

import '../../balsm_api.dart' show ApiException;
import '../transport/api_exception.dart' show ApiException;
import 'responses.dart';

/// Platform maintenance flag (.NET host `MaintenanceController`).
/// Anonymous — safe before sign-in. Throws [ApiException] on transport errors.
abstract class MaintenanceApi {
  /// GET /api/v1/maintenance
  Future<MaintenanceStatusResponse> getStatus({CancelToken? cancelToken});
}
