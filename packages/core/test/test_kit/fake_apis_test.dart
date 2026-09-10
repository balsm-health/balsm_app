import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The e2e fakes stand in for the whole API layer so the on-device suites run
/// with no backend. Their knobs are the only way a test can reach a branch the
/// server would normally decide — a lockout, a rejected sign-in, a brand-new
/// account — so the knobs themselves need covering.
void main() {
  PasswordSignInRequest signIn() => const PasswordSignInRequest(
        email: 'a@b.c',
        password: 'pw',
        deviceId: 'd',
        deviceLabel: 'l',
      );

  group('FakeAuthApi', () {
    test('password sign-in returns the fixture session', () async {
      final api = FakeAuthApi();

      final r = await api.passwordSignIn(signIn());

      expect(r.userId, E2eFixture.userId);
      expect(r.isNewUser, isFalse);
    });

    test('nextIsNewUser drives the new-account branch', () async {
      final api = FakeAuthApi()..nextIsNewUser = true;

      final r = await api.passwordSignIn(signIn());

      expect(r.isNewUser, isTrue);
    });

    test('lockedOut throws account_locked with a Retry-After', () async {
      final api = FakeAuthApi()..lockedOut = true;

      await expectLater(
        () => api.passwordSignIn(signIn()),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'account_locked')
            .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 90)),
      );
    });

    test('failNextSignIn throws unauthorized once, then clears itself', () async {
      final api = FakeAuthApi()..failNextSignIn = true;

      await expectLater(
        () => api.passwordSignIn(signIn()),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unauthorized')),
      );

      // One-shot, so a test can assert the screen recovers on retry.
      final r = await api.passwordSignIn(signIn());
      expect(r.userId, E2eFixture.userId);
    });

    test('every session-issuing method honours the same knobs', () async {
      final api = FakeAuthApi()..lockedOut = true;

      await expectLater(
        () => api.verifyOtp(const VerifyOtpRequest(email: 'a@b.c', code: '1', deviceId: 'd', deviceLabel: 'l')),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        () => api.verifyLink(const VerifyLinkRequest(token: 't', deviceId: 'd', deviceLabel: 'l')),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('FakeAccountApi', () {
    test('getSelf returns the fixture and carries no health data', () async {
      final self = await FakeAccountApi().getSelf();

      expect(self!.id, E2eFixture.userId);
      expect(self.countryCode, E2eFixture.countryCode);
      expect(self.dateOfBirth, isNull, reason: 'the e2e fixture carries no PHI');
      expect(self.nationalId, isNull, reason: 'the e2e fixture carries no PII');
    });

    test('handle availability reflects the taken set', () async {
      final api = FakeAccountApi();

      expect((await api.checkHandleAvailability('balsm')).available, isFalse);
      expect((await api.checkHandleAvailability('BALSM')).available, isFalse, reason: 'case-insensitive');
      expect((await api.checkHandleAvailability('someone_new')).available, isTrue);
    });

    test('writes are readable back through getSelf', () async {
      final api = FakeAccountApi();

      await api.claimHandle(const ClaimHandleRequest(handle: 'claimed'));
      await api.updateProfile(const UpdateProfileRequest(firstName: 'Given', lastName: 'Family'));
      await api.changeLanguage(const ChangeLanguageRequest(preferredLanguage: 'ar'));
      await api.changeCountry(const ChangeCountryRequest(countryCode: 'SA'));

      final self = (await api.getSelf())!;
      expect(self.handle, 'claimed');
      expect(self.firstName, 'Given');
      expect(self.lastName, 'Family');
      expect(self.preferredLanguage, 'ar');
      expect(self.countryCode, 'SA');
    });
  });

  test('FakeGeofenceApi denies nothing by default', () async {
    // The fixture country must not be blocked, or every flow stops at the
    // geofence screen before it reaches what it meant to test.
    final denied = await FakeGeofenceApi().getDeniedCountries();

    expect(denied.deniedCodes, isEmpty);
  });

  test('e2eApiOverrides binds every Provider<XxxApi> to a fake', () {
    final container = ProviderContainer(overrides: e2eApiOverrides());
    addTearDown(container.dispose);

    expect(container.read(authApiProvider), isA<FakeAuthApi>());
    expect(container.read(accountApiProvider), isA<FakeAccountApi>());
    expect(container.read(sessionsApiProvider), isA<FakeSessionsApi>());
    expect(container.read(emergencyQrApiProvider), isA<FakeEmergencyQrApi>());
    expect(container.read(deletionApiProvider), isA<FakeDeletionApi>());
    expect(container.read(disclosureApiProvider), isA<FakeDisclosureApi>());
    expect(container.read(geofenceApiProvider), isA<FakeGeofenceApi>());
    expect(container.read(careDirectoryApiProvider), isA<FakeCareDirectoryApi>());
  });

  test('e2eApiOverrides accepts a pre-configured fake so a test can force state', () {
    final auth = FakeAuthApi()..lockedOut = true;
    final container = ProviderContainer(overrides: e2eApiOverrides(auth: auth));
    addTearDown(container.dispose);

    expect(identical(container.read(authApiProvider), auth), isTrue);
  });

  group('FakeCareDirectoryApi.nearby', () {
    // The fake has to narrow the way the real endpoint does. One that returned
    // everything regardless of the query would let a broken search pass e2e.
    final api = FakeCareDirectoryApi();

    test('returns every seeded place when the query is unfiltered', () async {
      final res = await api.nearby(const NearbyCareQuery(lat: 30.0444, lng: 31.2357));
      expect(res, isNotEmpty);
      expect(res.map((p) => p.type), contains('dentist'));
    });

    test('filters by type', () async {
      final res = await api.nearby(const NearbyCareQuery(lat: 30.0444, lng: 31.2357, type: 'pharmacy'));
      expect(res, hasLength(1));
      expect(res.single.type, 'pharmacy');
    });

    test('filters by radius', () async {
      final res = await api.nearby(const NearbyCareQuery(lat: 30.0444, lng: 31.2357, radiusKm: 1.0));
      expect(res.every((p) => (p.distanceKm ?? 0) <= 1.0), isTrue);
      expect(res.length, lessThan((await api.nearby(const NearbyCareQuery(lat: 30.0444, lng: 31.2357))).length));
    });

    test('matches free text in either script', () async {
      final en = await api.nearby(const NearbyCareQuery(lat: 30.0444, lng: 31.2357, query: 'dental'));
      expect(en.single.id, 'e2e-dentist-1');

      final ar = await api.nearby(const NearbyCareQuery(lat: 30.0444, lng: 31.2357, query: 'صيدلية'));
      expect(ar.single.type, 'pharmacy');
    });

    test('returns empty rather than everything when nothing matches', () async {
      final res = await api.nearby(const NearbyCareQuery(lat: 30.0444, lng: 31.2357, query: 'zzzz-no-match'));
      expect(res, isEmpty);
    });
  });
}
