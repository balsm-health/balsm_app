import 'package:auth/src/infrastructure/api/auth_exception.dart';
import 'package:auth/src/infrastructure/api/balsm_auth_adapter.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _FakeGoogleRequest extends Fake implements GoogleSignInRequest {}

/// The adapter turns transport errors into display-safe messages. A body code
/// it knows picks the message; a server failure name it does not know falls
/// back to the HTTP status, never to "unexpected error".
void main() {
  setUpAll(() => registerFallbackValue(_FakeGoogleRequest()));

  late _MockAuthApi api;
  late BalsmAuthAdapter adapter;

  setUp(() {
    api = _MockAuthApi();
    adapter = BalsmAuthAdapter(api: api);
  });

  Future<AuthException> failWith(ApiException e) async {
    when(() => api.signInWithGoogle(any(), cancelToken: any(named: 'cancelToken'))).thenThrow(e);
    try {
      await adapter.signInWithGoogle('t', 'd', 'l', 'EG');
    } on AuthException catch (caught) {
      return caught;
    }
    fail('expected an AuthException');
  }

  test('429 RateLimitExceeded says rate limited and keeps the server code', () async {
    final e = await failWith(const ApiException(code: 'RateLimitExceeded', statusCode: 429));

    expect(e.code, 'RateLimitExceeded');
    expect(e.message, 'Too many requests. Please wait before trying again.');
  });

  test('an unknown body code falls back to the status-derived message', () async {
    final e = await failWith(const ApiException(code: 'CountryDenied', statusCode: 403));

    expect(e.code, 'CountryDenied', reason: 'callers still branch on the server code');
    expect(e.message, 'Access denied.');
  });

  test('a status-derived code keeps its own message', () async {
    final e = await failWith(const ApiException(code: 'not_found', statusCode: 404));

    expect(e.message, 'The requested resource was not found.');
  });
}
