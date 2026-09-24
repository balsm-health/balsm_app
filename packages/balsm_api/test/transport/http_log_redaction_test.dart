import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

/// What the debug HTTP log is allowed to print.
///
/// The log exists to be pasted — into a terminal, a bug report, a chat with
/// someone helping. Anything in it travels. Bodies and headers carry bearer
/// tokens, passwords, and one-time codes, and none of those are needed to
/// debug the request that carried them.
void main() {
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
