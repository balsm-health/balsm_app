import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('CancelToken is re-exported from balsm_api (no dio import needed)', () {
    // Compiles using only `package:balsm_api/balsm_api.dart` above.
    expect(CancelToken(), isA<CancelToken>());
  });

  test('fromDioException maps a cancel to code "cancelled" / isCancelled', () {
    final e = ApiException.fromDioException(DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.cancel,
    ));
    expect(e.code, 'cancelled');
    expect(e.isCancelled, isTrue);
    expect(e.statusCode, isNull);
  });

  test('a cancelled request surfaces as ApiException.isCancelled end-to-end',
      () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": []}'));
    final api = DioSessionsApi(net: fakeNet(adapter));
    final token = CancelToken()..cancel('user aborted');

    await expectLater(
      api.listSessions(cancelToken: token),
      throwsA(isA<ApiException>()
          .having((e) => e.isCancelled, 'isCancelled', isTrue)),
    );
  });
}
