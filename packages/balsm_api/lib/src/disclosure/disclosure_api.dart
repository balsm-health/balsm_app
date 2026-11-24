import 'package:dio/dio.dart' show CancelToken;

import '../../balsm_api.dart' show ApiException;
import '../transport/api_exception.dart' show ApiException;
import 'requests.dart';

/// Disclosure endpoints (.NET module: Disclosure).
/// Throws [ApiException]; callers that treat acceptance sync as best-effort
/// (offline-tolerant) catch and swallow in their own layer.
/// Pass a [CancelToken] to abort the request.
// Port interface; the real client and the test fakes are swapped per environment.
// ignore: one_member_abstracts
abstract class DisclosureApi {
  /// POST /disclosure/accept
  Future<void> accept(AcceptDisclosureRequest request, {CancelToken? cancelToken});
}
