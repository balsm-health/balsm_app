import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('verifyOtp posts snake_case body and parses the enveloped token response',
      () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"data": {"access_token": "at", "refresh_token": "rt", "user_id": "u1", "is_new_user": true}}'));
    final api = DioAuthApi(net: fakeNet(adapter));

    final res = await api.verifyOtp(const VerifyOtpRequest(
        email: 'a@b.c', code: '123456', deviceId: 'd1', deviceLabel: 'iPhone'));

    expect(adapter.requests.single.path, '/auth/otp/verify');
    expect(adapter.requests.single.data, {
      'email': 'a@b.c',
      'code': '123456',
      'device_id': 'd1',
      'device_label': 'iPhone',
    });
    expect(res.accessToken, 'at');
    expect(res.userId, 'u1');
    expect(res.isNewUser, isTrue);
  });

  test('is_new_user defaults to false', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"data": {"access_token": "at", "refresh_token": "rt", "user_id": "u1"}}'));
    final res = await DioAuthApi(net: fakeNet(adapter)).signInWithGoogle(
        const GoogleSignInRequest(idToken: 't', deviceId: 'd', deviceLabel: 'l'));
    expect(res.isNewUser, isFalse);
  });

  test('423 lockout carries account_locked code and Retry-After', () {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"code": "account_locked"}',
        status: 423,
        headers: {'Retry-After': ['120']}));
    final api = DioAuthApi(net: fakeNet(adapter));
    expect(
      api.verifyOtp(const VerifyOtpRequest(
          email: 'a@b.c', code: '1', deviceId: 'd', deviceLabel: 'l')),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'account_locked')
          .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 120)),
    );
  });

  test('server error code from flat body wins over status mapping', () {
    final adapter = FakeHttpAdapter(
        (_) => jsonResponse('{"code": "otp_expired"}', status: 400));
    final api = DioAuthApi(net: fakeNet(adapter));
    expect(
      api.requestOtp(const RequestOtpRequest(email: 'a@b.c', countryCode: 'EG')),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'otp_expired')),
    );
  });

  test('refresh and recoveryClaim parse the enveloped refreshed tokens', () async {
    final adapter = FakeHttpAdapter(
        (_) => jsonResponse('{"data": {"access_token": "at2", "refresh_token": "rt2"}}'));
    final api = DioAuthApi(net: fakeNet(adapter));

    final r1 = await api.refresh(
        const RefreshTokenRequest(refreshToken: 'rt', deviceId: 'd'));
    expect(r1.accessToken, 'at2');

    final r2 = await api.recoveryClaim(const RecoveryClaimRequest(
        recoveryToken: 'rec', newEmail: 'n@b.c', deviceId: 'd', deviceLabel: 'l'));
    expect(adapter.requests[1].data, {
      'recovery_token': 'rec',
      'new_email': 'n@b.c',
      'device_id': 'd',
      'device_label': 'l',
    });
    expect(r2.refreshToken, 'rt2');
  });

  test('signOut posts empty body', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}'));
    await DioAuthApi(net: fakeNet(adapter)).signOut();
    expect(adapter.requests.single.path, '/auth/sign-out');
    expect(adapter.requests.single.data, isEmpty);
  });
}
