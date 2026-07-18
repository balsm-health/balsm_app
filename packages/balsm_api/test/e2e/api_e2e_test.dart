@Tags(['e2e'])
library;

import 'dart:io';

import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

/// Live end-to-end tests against a REAL Balsm API, exercising the actual
/// snake_case client DTOs over the wire — no mocks, no fakes.
///
/// Opt-in: the suite is skipped unless `E2E_BASE_URL` is set, so `dart test`
/// and CI never hit the network by default. Run it explicitly:
///
///   # local API (dotnet run, SQLite):
///   E2E_BASE_URL=http://localhost:5050 dart test test/e2e/api_e2e_test.dart
///
///   # staging (requires the snake_case-enabled deployment):
///   E2E_BASE_URL=https://api-stg-balsm-health.mosalam.com \
///     dart test test/e2e/api_e2e_test.dart
///
/// Config via env (all optional except E2E_BASE_URL):
///   E2E_EMAIL      test account email          (default e2e-suite@example.com)
///   E2E_OTP        OTP code to submit          (default 123456)
///   E2E_DEVICE_ID  device id — must be a GUID  (default a fixed test GUID)
///   E2E_COUNTRY    ISO country code            (default EG)
void main() {
  final baseUrl = Platform.environment['E2E_BASE_URL'];
  final skip = (baseUrl == null || baseUrl.isEmpty)
      ? 'set E2E_BASE_URL to run live API E2E'
      : null;

  final email = Platform.environment['E2E_EMAIL'] ?? 'e2e-suite@example.com';
  final otp = Platform.environment['E2E_OTP'] ?? '123456';
  final deviceId = Platform.environment['E2E_DEVICE_ID'] ??
      '0b1e5c00-0000-4000-8000-00000000e2e5';
  final country = Platform.environment['E2E_COUNTRY'] ?? 'EG';
  final deviceLabel = 'e2e-suite';

  group('Balsm API E2E', () {
    late BalsmApiClient client;
    late AuthApi auth;
    late AccountApi account;
    late SessionsApi sessions;

    // Shared session state, populated by the auth journey below.
    String? accessToken;
    String? refreshToken;

    setUpAll(() {
      client = BalsmApiClient.create(baseUrl: baseUrl ?? 'http://invalid');
      final net = NetworkManager(dio: client.dio);
      auth = DioAuthApi(net: net);
      account = DioAccountApi(net: net);
      sessions = DioSessionsApi(net: net);
    });

    void bearer(String? token) {
      if (token == null) {
        client.dio.options.headers.remove('Authorization');
      } else {
        client.dio.options.headers['Authorization'] = 'Bearer $token';
      }
    }

    // ── Auth journey (ordered) ──────────────────────────────────────────────

    test('POST /auth/otp/request accepts the snake_case body', () async {
      await auth.requestOtp(
        RequestOtpRequest(email: email, countryCode: country),
      );
      // Completing without throwing == 2xx (NetworkManager maps non-2xx to
      // ApiException).
    }, skip: skip);

    test('POST /auth/otp/verify issues a token pair', () async {
      final res = await auth.verifyOtp(VerifyOtpRequest(
        email: email,
        code: otp,
        deviceId: deviceId,
        deviceLabel: deviceLabel,
      ));
      expect(res.accessToken, isNotEmpty);
      expect(res.refreshToken, isNotEmpty);
      expect(res.userId, isNotEmpty);
      accessToken = res.accessToken;
      refreshToken = res.refreshToken;
      bearer(accessToken);
    }, skip: skip);

    test('POST /auth/refresh rotates the token pair', () async {
      if (refreshToken == null) fail('no refresh token from verify step');
      final res = await auth.refresh(RefreshTokenRequest(
        refreshToken: refreshToken!,
        deviceId: deviceId,
      ));
      expect(res.accessToken, isNotEmpty);
      expect(res.refreshToken, isNotEmpty);
      accessToken = res.accessToken;
      refreshToken = res.refreshToken;
      bearer(accessToken);
    }, skip: skip);

    test('POST /auth/sign-out succeeds for the authenticated session', () async {
      if (accessToken == null) fail('no access token');
      await auth.signOut();
      bearer(null);
    }, skip: skip);

    // ── Authenticated read endpoints ────────────────────────────────────────
    // These require a signed-in session; they run after a fresh verify so they
    // are independent of the sign-out above.

    test('authenticated account + sessions endpoints', () async {
      final res = await auth.verifyOtp(VerifyOtpRequest(
        email: email,
        code: otp,
        deviceId: deviceId,
        deviceLabel: deviceLabel,
      ));
      bearer(res.accessToken);
      addTearDown(() => bearer(null));

      // GET /account/self — profile summary for the signed-in user.
      final self = await account.getSelf();
      expect(self, isNotNull);
      expect(self!.id, isNotEmpty);

      // GET /sessions — active sessions for this user.
      final list = await sessions.listSessions();
      expect(list, isA<List<SessionResponse>>());

      // GET /account/handle/available — availability probe.
      final avail = await account.checkHandleAvailability('e2e_handle_probe');
      expect(avail.available, isA<bool>());

      // PUT /account/language — write, then read back to confirm it persisted.
      await account.changeLanguage(
          const ChangeLanguageRequest(preferredLanguage: 'en'));
      final after = await account.getSelf();
      expect(after!.preferredLanguage, 'en');
    }, skip: skip);
  });
}
