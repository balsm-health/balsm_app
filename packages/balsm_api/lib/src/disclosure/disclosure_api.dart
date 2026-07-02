import 'package:dio/dio.dart' show CancelToken;

import 'requests.dart';

/// Disclosure endpoints (.NET module: Disclosure).
/// Throws [ApiException]; callers that treat acceptance sync as best-effort
/// (offline-tolerant) catch and swallow in their own layer.
/// Pass a [CancelToken] to abort the request.
abstract class DisclosureApi {
  /// POST /disclosure/accept
  Future<void> accept(AcceptDisclosureRequest request, {CancelToken? cancelToken});
}
