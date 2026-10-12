import 'package:dio/dio.dart' show CancelToken;

import 'responses.dart';

/// Account-deletion endpoints (.NET module: Deletion).
/// All methods throw [ApiException] on transport or envelope errors.
/// Pass a [CancelToken] to abort the request; a cancelled request throws
/// [ApiException] with `isCancelled == true`.
abstract class DeletionApi {
  /// POST /deletion/intake
  Future<DeletionIntakeResponse> requestIntake({CancelToken? cancelToken});

  /// POST /deletion/cancel
  Future<DeletionCancelResponse> cancel({CancelToken? cancelToken});
}
