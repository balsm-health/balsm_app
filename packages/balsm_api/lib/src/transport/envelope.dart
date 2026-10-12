import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Unwraps the `{data, error}` envelope used by every Balsm endpoint,
/// auth included.
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

/// Nullable variant of [unwrapEnvelope]: returns null when `data` is null or
/// absent (e.g. `GET /emergency-qr/active` with no active token), instead of
/// collapsing to `{}` — callers distinguish "nothing" from "empty object".
Map<String, dynamic>? unwrapNullableEnvelope(Response<dynamic> response) {
  final body = response.data;
  if (body is! Map<String, dynamic>) return null;
  final error = body['error'];
  if (error != null) {
    throw ApiException.fromEnvelopeError(error, statusCode: response.statusCode);
  }
  final data = body['data'];
  return data is Map<String, dynamic> ? data : null;
}
