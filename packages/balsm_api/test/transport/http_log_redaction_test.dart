import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

/// What the debug HTTP log is allowed to print.
///
/// The log exists to be pasted — into a terminal, a bug report, a chat with
/// someone helping. Anything in it travels. Bodies and headers carry bearer
/// tokens, passwords, and one-time codes, and none of those are needed to
/// debug the request that carried them.
void main() {
  group('the switch', () {
    test('debug logging is raw by default — nothing is hidden', () {
      // The point of this log is to see exactly what went over the wire.
      // Redaction is opt-in, for the times a log is going somewhere else.
      expect(const HttpLogInterceptor().redact, isFalse);
    });

    test('asking for it turns it on', () {
      expect(const HttpLogInterceptor(redact: true).redact, isTrue);
    });
  });

  group('body', () {
    test('keeps the fields that identify a request', () {
      final out = HttpLogInterceptor.redactBody({'email': 'patient@example.test', 'device_label': 'iPhone'}) as Map;

      expect(out, {'email': 'patient@example.test', 'device_label': 'iPhone'});
    });

    test('hides a password', () {
      final out = HttpLogInterceptor.redactBody({'email': 'patient@example.test', 'password': 'hunter2'}) as Map;

      expect(out['password'], isNot(contains('hunter2')));
      expect(out['email'], 'patient@example.test', reason: 'still useful for debugging');
    });

    test('hides a one-time code, a new password, and a token', () {
      final out = HttpLogInterceptor.redactBody({
        'code': '123456',
        'new_password': 'hunter2',
        'refresh_token': 'rt_abcdef',
        'id_token': 'eyJhbGciOi',
      }) as Map;

      expect(out.values.join(), isNot(contains('123456')));
      expect(out.values.join(), isNot(contains('hunter2')));
      expect(out.values.join(), isNot(contains('rt_abcdef')));
      expect(out.values.join(), isNot(contains('eyJhbGciOi')));
    });

    test('keeps an error code — that is the answer, not a secret', () {
      // The server names failures: InvalidCredentials, RateLimitExceeded,
      // AccountLocked. Hiding those leaves a log that says a request failed
      // and refuses to say how.
      final out = HttpLogInterceptor.redactBody({
        'error': {'code': 'InvalidCredentials', 'message': 'Invalid email or password.'}
      }) as Map;

      expect((out['error'] as Map)['code'], 'InvalidCredentials');
      expect((out['error'] as Map)['message'], 'Invalid email or password.');
    });

    test('keeps a country code', () {
      final out = HttpLogInterceptor.redactBody({'country_code': 'EG'}) as Map;

      expect(out['country_code'], 'EG');
    });

    test('keeps a numeric status code', () {
      final out = HttpLogInterceptor.redactBody({'status_code': 429}) as Map;

      expect(out['status_code'], 429);
    });

    test('still hides a six-digit one-time code', () {
      final out = HttpLogInterceptor.redactBody({'code': '123456'}) as Map;

      expect(out['code'], isNot('123456'));
    });

    test('reaches nested maps and lists', () {
      final out = HttpLogInterceptor.redactBody({
        'data': {
          'session': {'access_token': 'at_secret'},
          'devices': [
            {'password': 'hunter2'}
          ],
        },
      }) as Map;

      expect(out.toString(), isNot(contains('at_secret')));
      expect(out.toString(), isNot(contains('hunter2')));
    });

    test('leaves a non-map body alone rather than guessing', () {
      expect(HttpLogInterceptor.redactBody('plain text'), 'plain text');
      expect(HttpLogInterceptor.redactBody(null), isNull);
    });
  });

  group('headers', () {
    test('hides the bearer, keeps the scheme', () {
      final out = HttpLogInterceptor.redactHeaders({
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig',
        'Content-Type': 'application/json',
      });

      expect(out['Authorization'], isNot(contains('payload')));
      expect(out['Authorization'].toString(), contains('Bearer'), reason: 'which scheme is worth seeing');
      expect(out['Content-Type'], 'application/json');
    });

    test('matches the header however it is cased', () {
      final out = HttpLogInterceptor.redactHeaders({'authorization': 'Bearer secret-token'});

      expect(out.values.join(), isNot(contains('secret-token')));
    });

    test('hides a cookie', () {
      final out = HttpLogInterceptor.redactHeaders({'set-cookie': 'session=abc123; HttpOnly'});

      expect(out.values.join(), isNot(contains('abc123')));
    });
  });
}
