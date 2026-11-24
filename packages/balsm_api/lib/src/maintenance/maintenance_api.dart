import 'package:dio/dio.dart' show CancelToken;

import '../../balsm_api.dart' show ApiException;
import '../transport/api_exception.dart' show ApiException;
import 'responses.dart';

/// Platform maintenance flag (.NET host `MaintenanceController`).
/// Anonymous — safe before sign-in. Throws [ApiException] on transport errors.
// Port interface; the real client and the test fakes are swapped per environment.
// ignore: one_member_abstracts
abstract class MaintenanceApi {
  /// GET /api/v1/maintenance
  Future<MaintenanceStatusResponse> getStatus({CancelToken? cancelToken});
}
