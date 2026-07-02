import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

void main() {
  test('create() configures baseUrl, timeouts, headers, PHI interceptor', () {
    final client = BalsmApiClient.create(baseUrl: 'https://api.example.com');
    expect(client.baseUrl, 'https://api.example.com');
    expect(client.dio.options.connectTimeout, const Duration(seconds: 10));
    expect(client.dio.options.receiveTimeout, const Duration(seconds: 30));
    expect(client.dio.options.headers['Accept'], 'application/json');
    expect(client.dio.options.headers['Content-Type'], 'application/json');
    expect(client.dio.interceptors.whereType<PhiLeakInterceptor>(), hasLength(1));
  });

  test('baseUrl setter re-points the shared Dio instance', () {
    final client = BalsmApiClient.create(baseUrl: 'https://a.example');
    client.baseUrl = 'https://b.example';
    expect(client.dio.options.baseUrl, 'https://b.example');
  });
}
