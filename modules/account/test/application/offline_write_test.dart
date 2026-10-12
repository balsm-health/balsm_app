import 'package:account/account.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// What NetworkManager hands a caller when the request never left the device.
const _offline = ApiException(code: 'network_error', isOffline: true);

/// A server that answered. Also a null statusCode is possible here, which is
/// exactly why the offline check cannot be a `case null` in the status switch.
const _serverError = ApiException(code: 'server_error', statusCode: 500);
const _unauthorized = ApiException(code: 'unauthorized', statusCode: 401);
const _validation = ApiException(code: 'validation_error', statusCode: 422);

class _ThrowingApi extends Fake implements AccountApi {
  _ThrowingApi(this.error);
  final Object error;

  @override
  Future<void> changeLanguage(ChangeLanguageRequest request, {CancelToken? cancelToken}) async => throw error;
}

void main() {
  ChangeLanguageUseCase useCaseThrowing(Object error) =>
      ChangeLanguageUseCase(api: _ThrowingApi(error), bus: EventBus());

  Future<AppResult<String>> run(Object error) => useCaseThrowing(error).execute(
        userId: UserId.value('00000000-0000-0000-0000-0000000000a1'),
        oldLanguage: 'en',
        newLanguage: 'ar',
      );

  test('an offline write reports being offline', () async {
    final r = await run(_offline);
    expect(r.error, isA<OfflineFailure>(), reason: 'a generic "network error" hides that the fix is to reconnect');
  });

  test('a server error is still the catch-all', () async {
    final r = await run(_serverError);
    expect(r.error, isA<NetworkFailure>());
    expect(r.error, isNot(isA<OfflineFailure>()));
  });

  test('a 401 is still unauthorized', () async {
    expect((await run(_unauthorized)).error, isA<UnauthorizedFailure>());
  });

  test('a 422 is still a validation failure', () async {
    expect((await run(_validation)).error, isA<ValidationFailure>());
  });
}
