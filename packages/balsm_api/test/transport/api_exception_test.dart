import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

DioException _dioError({int? status, Object? data, Map<String, List<String>>? headers}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: status == null
        ? null
        : Response(
            requestOptions: req,
            statusCode: status,
            data: data,
            headers: Headers.fromMap(headers ?? {}),
          ),
  );
}

void main() {
  test('codeForStatus maps statuses like the legacy auth adapter', () {
    expect(ApiException.codeForStatus(null), 'network_error');
    expect(ApiException.codeForStatus(400), 'invalid_request');
    expect(ApiException.codeForStatus(401), 'unauthorized');
    expect(ApiException.codeForStatus(403), 'forbidden');
    expect(ApiException.codeForStatus(404), 'not_found');
    expect(ApiException.codeForStatus(409), 'conflict');
    expect(ApiException.codeForStatus(410), 'gone');
    expect(ApiException.codeForStatus(422), 'validation_error');
    expect(ApiException.codeForStatus(423), 'account_locked');
    expect(ApiException.codeForStatus(429), 'rate_limited');
    expect(ApiException.codeForStatus(500), 'server_error');
    expect(ApiException.codeForStatus(418), 'network_error');
  });

  test('fromDioException prefers body code, parses Retry-After', () {
    final e = ApiException.fromDioException(_dioError(
      status: 423,
      data: <String, dynamic>{'code': 'account_locked', 'message': 'locked'},
      headers: {'Retry-After': ['90']},
    ));
    expect(e.code, 'account_locked');
    expect(e.statusCode, 423);
    expect(e.serverMessage, 'locked');
    expect(e.retryAfterSeconds, 90);
    expect(e.fromEnvelope, isFalse);
  });

  test('fromDioException reads nested envelope error code', () {
    final e = ApiException.fromDioException(_dioError(
      status: 400,
      data: <String, dynamic>{
        'data': null,
        'error': <String, dynamic>{'code': 'otp_invalid', 'message': 'bad'},
      },
    ));
    expect(e.code, 'otp_invalid');
    expect(e.serverMessage, 'bad');
  });

  test('fromDioException falls back to status mapping', () {
    final e = ApiException.fromDioException(_dioError(status: 500, data: 'oops'));
    expect(e.code, 'server_error');
    expect(e.serverMessage, isNull);
  });

  test('network error (no response) maps to network_error', () {
    final e = ApiException.fromDioException(_dioError());
    expect(e.code, 'network_error');
    expect(e.statusCode, isNull);
  });

  test('toString never leaks serverMessage (PHI safety)', () {
    const e = ApiException(code: 'conflict', statusCode: 409, serverMessage: 'user a@b.c exists');
    expect(e.toString(), isNot(contains('a@b.c')));
  });

  test('isUnauthorized covers 401 and 403', () {
    expect(const ApiException(code: 'unauthorized', statusCode: 401).isUnauthorized, isTrue);
    expect(const ApiException(code: 'forbidden', statusCode: 403).isUnauthorized, isTrue);
    expect(const ApiException(code: 'conflict', statusCode: 409).isUnauthorized, isFalse);
  });
}
