import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test('scrubForTelemetry redacts non-allowlisted fields, keeps allowlisted', () {
    final scrubbed = PhiLeakInterceptor.scrubForTelemetry({
      'email': 'a@b.c',
      'status_code': 200,
    });
    expect(scrubbed['email'], '[redacted]');
    expect(scrubbed['status_code'], 200);
  });

  test('onRequest stashes scrubbed copy without mutating the outbound body', () {
    final options = RequestOptions(path: '/x', data: {'email': 'a@b.c'});
    PhiLeakInterceptor().onRequest(
      options,
      RequestInterceptorHandler(),
    );
    expect((options.data as Map)['email'], 'a@b.c'); // wire body untouched
    expect(
      (options.extra['phi_safe_body'] as Map)['email'],
      '[redacted]',
    );
  });
}
