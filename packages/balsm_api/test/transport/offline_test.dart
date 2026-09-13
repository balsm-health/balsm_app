import 'dart:io';

import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

DioException _dio(DioExceptionType type, {int? status}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      response: status == null ? null : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status),
    );

void main() {
  group('isOfflineError', () {
    test('true for transport-level dio failures', () {
      expect(isOfflineError(_dio(DioExceptionType.connectionError)), isTrue);
      expect(isOfflineError(_dio(DioExceptionType.connectionTimeout)), isTrue);
      expect(isOfflineError(_dio(DioExceptionType.sendTimeout)), isTrue);
      expect(isOfflineError(_dio(DioExceptionType.receiveTimeout)), isTrue);
    });

    test('true for a raw SocketException', () {
      expect(isOfflineError(const SocketException('no route to host')), isTrue);
    });

    test('true for a SocketException wrapped by dio', () {
      expect(
        isOfflineError(DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.unknown,
          error: const SocketException('failed host lookup'),
        )),
        isTrue,
      );
    });

    test('false when the server answered', () {
      expect(isOfflineError(_dio(DioExceptionType.badResponse, status: 401)), isFalse);
      expect(isOfflineError(_dio(DioExceptionType.badResponse, status: 500)), isFalse);
    });

    test('false for a cancellation', () {
      expect(isOfflineError(_dio(DioExceptionType.cancel)), isFalse,
          reason: 'a superseded map pan is not the user being offline');
    });

    test('false for a parse error', () {
      expect(isOfflineError(const FormatException('bad json')), isFalse,
          reason: 'a malformed body means the server answered — serving stale '
              'data for it would hide a real bug');
    });
  });

  // Regression: NetworkManager converts every DioException into an
  // ApiException before a caller sees it. Classifying only raw dio errors
  // would mean no cache ever falls back, because no caller is ever handed a
  // DioException.
  test('isOfflineError sees through the ApiException wrapper', () {
    expect(isOfflineError(ApiException.fromDioException(_dio(DioExceptionType.connectionError))), isTrue);
    expect(isOfflineError(ApiException.fromDioException(_dio(DioExceptionType.badResponse, status: 500))), isFalse);
    expect(isOfflineError(const ApiException(code: 'unauthorized', statusCode: 401)), isFalse);
  });

  test('ApiException carries the verdict forward', () {
    expect(ApiException.fromDioException(_dio(DioExceptionType.connectionError)).isOffline, isTrue);
    expect(ApiException.fromDioException(_dio(DioExceptionType.badResponse, status: 500)).isOffline, isFalse);
    expect(ApiException.fromDioException(_dio(DioExceptionType.cancel)).isOffline, isFalse);
  });
}
