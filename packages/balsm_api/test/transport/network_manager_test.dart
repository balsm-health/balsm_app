import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('get returns the decoded response and records path/query', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": {"a": 1}}'));
    final net = NetworkManager(dio: fakeDio(adapter));

    final res = await net.get('/thing', queryParameters: {'q': '1'});

    expect(res.data, {
      'data': {'a': 1}
    });
    expect(adapter.requests.single.path, '/thing');
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.queryParameters, {'q': '1'});
  });

  test('post forwards body + cancelToken and maps HTTP error to ApiException', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 500));
    final net = NetworkManager(dio: fakeDio(adapter));

    await expectLater(
      net.post('/thing', data: {'x': 1}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
    );
    expect(adapter.requests.single.data, {'x': 1});
  });

  test('maps a cancelled request to ApiException.isCancelled', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}'));
    final net = NetworkManager(dio: fakeDio(adapter));
    final token = CancelToken()..cancel();

    await expectLater(
      net.get('/thing', cancelToken: token),
      throwsA(isA<ApiException>().having((e) => e.isCancelled, 'isCancelled', isTrue)),
    );
  });
}
