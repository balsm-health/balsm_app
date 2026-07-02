import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Unwraps the `{data, error}` envelope used by most Balsm endpoints
/// (auth is the exception — it returns flat bodies).
///
/// Throws [ApiException] when `error` is non-null. Returns `{}` when the
/// body carries no map `data`.
Map<String, dynamic> unwrapEnvelope(Response<dynamic> response) {
  final body = response.data;
  if (body is! Map<String, dynamic>) return const {};
  final error = body['error'];
  if (error != null) {
    throw ApiException.fromEnvelopeError(error, statusCode: response.statusCode);
  }
  final data = body['data'];
  return data is Map<String, dynamic> ? data : const {};
}

/// List variant of [unwrapEnvelope] (e.g. `GET /sessions`).
List<dynamic> unwrapEnvelopeList(Response<dynamic> response) {
  final body = response.data;
  if (body is! Map<String, dynamic>) return const [];
  final error = body['error'];
  if (error != null) {
    throw ApiException.fromEnvelopeError(error, statusCode: response.statusCode);
  }
  final data = body['data'];
  return data is List ? data : const [];
}
