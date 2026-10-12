import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Re-finding the server mid-session, when the machine it was on moved.
void main() {
  DioException connectionError() => DioException(
        requestOptions: RequestOptions(path: '/account/self', baseUrl: 'http://192.168.1.24:5050'),
        type: DioExceptionType.connectionError,
      );

  test('re-finds the host and replays the request once', () async {
    var lookups = 0;
    final replayed = <String>[];
    final interceptor = DevHostInterceptor(
      rediscover: () async {
        lookups++;
        return 'http://192.168.1.31:5050';
      },
      retry: (options) async {
        replayed.add(options.baseUrl);
        return Response<dynamic>(requestOptions: options, statusCode: 200);
      },
    );

    final err = connectionError();
    final handler = _Handler();
    await interceptor.onError(err, handler);

    expect(lookups, 1);
    expect(replayed, ['http://192.168.1.31:5050']);
    expect(handler.resolved?.statusCode, 200);
  });

  test('a request that already retried is not retried again', () async {
    var lookups = 0;
    final interceptor = DevHostInterceptor(
      rediscover: () async {
        lookups++;
        return 'http://192.168.1.31:5050';
      },
      retry: (options) async => Response<dynamic>(requestOptions: options, statusCode: 200),
    );

    final err = connectionError()..requestOptions.extra['balsm.dev_host_retried'] = true;
    final handler = _Handler();
    await interceptor.onError(err, handler);

    expect(lookups, 0, reason: 'the second failure is a real one');
    expect(handler.passed, isNotNull);
  });

  test('a server that answers badly is left alone', () async {
    var lookups = 0;
    final interceptor = DevHostInterceptor(
      rediscover: () async {
        lookups++;
        return 'http://192.168.1.31:5050';
      },
      retry: (options) async => Response<dynamic>(requestOptions: options, statusCode: 200),
    );

    // A 500 is a server that was found. Repointing would hide it.
    final err = DioException(
      requestOptions: RequestOptions(path: '/account/self'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(requestOptions: RequestOptions(path: '/account/self'), statusCode: 500),
    );
    final handler = _Handler();
    await interceptor.onError(err, handler);

    expect(lookups, 0);
    expect(handler.passed?.response?.statusCode, 500);
  });

  test('passes the original failure through when nothing is found', () async {
    final interceptor = DevHostInterceptor(
      rediscover: () async => null,
      retry: (options) async => Response<dynamic>(requestOptions: options, statusCode: 200),
    );

    final handler = _Handler();
    await interceptor.onError(connectionError(), handler);
    expect(handler.passed?.type, DioExceptionType.connectionError);
  });
}

/// Captures which arm of the handler the interceptor took.
class _Handler extends ErrorInterceptorHandler {
  Response<dynamic>? resolved;
  DioException? passed;

  @override
  void resolve(Response<dynamic> response) => resolved = response;

  @override
  void next(DioException err) => passed = err;
}
