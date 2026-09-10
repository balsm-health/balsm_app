import 'package:balsm_api/balsm_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_providers.dart';

/// The single synthetic identity every e2e run uses. Fixed values so assertions
/// can name them.
///
/// Carries NO health data: the flows under test stop at the home shell, so none
/// is needed, and inventing plausible-looking PHI is exactly what the repo's
/// agent rules forbid.
class E2eFixture {
  const E2eFixture._();

  static const userId = '00000000-0000-0000-0000-000000000001';
  static const email = 'e2e@balsm.test';
  static const countryCode = 'EG';
  static const language = 'en';
  static const displayName = 'E2E Tester';
  static const handle = 'e2e_tester';
  static const accessToken = 'e2e-access-token';
  static const refreshToken = 'e2e-refresh-token';
}

/// In-memory [AuthApi]. The public fields are the knobs a test flips to reach a
/// branch the server would normally decide — there is no server here to make
/// one happen.
class FakeAuthApi implements AuthApi {
  /// Every session-issuing call throws `account_locked` with a 90s Retry-After.
  bool lockedOut = false;

  /// The next session-issuing call throws a generic `unauthorized`, then clears
  /// itself — so a test can assert both that the error shows AND that a retry
  /// recovers, rather than latching into an error state.
  bool failNextSignIn = false;

  /// The next session reports a brand-new account, which routes the UI to
  /// profile setup and its fail-closed age gate.
  bool nextIsNewUser = false;

  AuthTokensResponse _session() {
    if (lockedOut) {
      throw const ApiException(code: 'account_locked', statusCode: 423, retryAfterSeconds: 90);
    }
    if (failNextSignIn) {
      failNextSignIn = false;
      throw const ApiException(code: 'unauthorized', statusCode: 401);
    }
    return AuthTokensResponse(
      accessToken: E2eFixture.accessToken,
      refreshToken: E2eFixture.refreshToken,
      userId: E2eFixture.userId,
      isNewUser: nextIsNewUser,
    );
  }

  @override
  Future<void> requestOtp(RequestOtpRequest request, {CancelToken? cancelToken}) async {}

  @override
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request, {CancelToken? cancelToken}) async => _session();

  @override
  Future<AuthTokensResponse> verifyLink(VerifyLinkRequest request, {CancelToken? cancelToken}) async => _session();

  @override
  Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request, {CancelToken? cancelToken}) async =>
      _session();

  @override
  Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request, {CancelToken? cancelToken}) async =>
      _session();

  @override
  Future<void> signOut({CancelToken? cancelToken}) async {}

  @override
  Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request, {CancelToken? cancelToken}) async =>
      const RefreshedTokensResponse(accessToken: E2eFixture.accessToken, refreshToken: E2eFixture.refreshToken);

  @override
  Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request, {CancelToken? cancelToken}) async =>
      const RefreshedTokensResponse(accessToken: E2eFixture.accessToken, refreshToken: E2eFixture.refreshToken);

  @override
  Future<AuthTokensResponse> passwordSignIn(PasswordSignInRequest request, {CancelToken? cancelToken}) async =>
      _session();

  @override
  Future<void> setPassword(SetPasswordRequest request, {CancelToken? cancelToken}) async {}

  @override
  Future<void> resetPassword(ResetPasswordRequest request, {CancelToken? cancelToken}) async {}
}

/// In-memory [AccountApi] over a single mutable fixture account. Writes are
/// readable back through [getSelf], so a flow that edits the profile sees its
/// own change the way it would against the real server.
class FakeAccountApi implements AccountApi {
  /// Handles this fake reports as taken; everything else is available.
  final taken = <String>{'balsm', 'admin'};

  String? _handle = E2eFixture.handle;
  String? _firstName;
  String? _lastName;
  String _language = E2eFixture.language;
  String _countryCode = E2eFixture.countryCode;

  @override
  Future<AccountSelfResponse?> getSelf({CancelToken? cancelToken}) async => AccountSelfResponse(
        id: E2eFixture.userId,
        handle: _handle,
        firstName: _firstName,
        lastName: _lastName,
        displayName: E2eFixture.displayName,
        countryCode: _countryCode,
        preferredLanguage: _language,
      );

  @override
  Future<ClaimHandleResponse> claimHandle(ClaimHandleRequest request, {CancelToken? cancelToken}) async {
    _handle = request.handle;
    return ClaimHandleResponse(handle: _handle);
  }

  @override
  Future<void> updateProfile(UpdateProfileRequest request, {CancelToken? cancelToken}) async {
    // Null means "leave unchanged" on the real endpoint; mirror that.
    _firstName = request.firstName ?? _firstName;
    _lastName = request.lastName ?? _lastName;
  }

  @override
  Future<void> changeLanguage(ChangeLanguageRequest request, {CancelToken? cancelToken}) async {
    _language = request.preferredLanguage;
  }

  @override
  Future<void> changeCountry(ChangeCountryRequest request, {CancelToken? cancelToken}) async {
    _countryCode = request.countryCode;
  }

  @override
  Future<HandleAvailabilityResponse> checkHandleAvailability(String handle, {CancelToken? cancelToken}) async =>
      HandleAvailabilityResponse(available: !taken.contains(handle.toLowerCase()));
}

class FakeSessionsApi implements SessionsApi {
  @override
  Future<List<SessionResponse>> listSessions({CancelToken? cancelToken}) async => const [];

  @override
  Future<void> revokeSession(String sessionId, {CancelToken? cancelToken}) async {}

  @override
  Future<RevokeAllSessionsResponse> revokeAllSessions({CancelToken? cancelToken}) async =>
      const RevokeAllSessionsResponse(revokedCount: 0);
}

/// Emergency QR is outside the flows these suites drive. Throwing rather than
/// returning a plausible token keeps an accidental dependency loud instead of
/// letting a test pass against invented data.
class FakeEmergencyQrApi implements EmergencyQrApi {
  @override
  Future<MintQrResponse> mint(MintQrRequest request, {CancelToken? cancelToken}) async =>
      throw const ApiException(code: 'not_implemented', statusCode: 501);

  @override
  Future<ResolveQrResponse> resolve(String tokenId, {CancelToken? cancelToken}) async =>
      throw const ApiException(code: 'not_found', statusCode: 404);

  @override
  Future<void> revoke(RevokeQrRequest request, {CancelToken? cancelToken}) async {}
}

/// Account deletion is outside these flows — see [FakeEmergencyQrApi].
class FakeDeletionApi implements DeletionApi {
  @override
  Future<DeletionIntakeResponse> requestIntake({CancelToken? cancelToken}) async =>
      throw const ApiException(code: 'not_implemented', statusCode: 501);

  @override
  Future<DeletionCancelResponse> cancel({CancelToken? cancelToken}) async =>
      throw const ApiException(code: 'not_implemented', statusCode: 501);
}

class FakeDisclosureApi implements DisclosureApi {
  /// Disclosure ids this fake was asked to accept, in order.
  final accepted = <String>[];

  @override
  Future<void> accept(AcceptDisclosureRequest request, {CancelToken? cancelToken}) async {
    accepted.add(request.disclosureId);
  }
}

class FakeGeofenceApi implements GeofenceApi {
  /// Empty by default: the fixture country must not be blocked, or every flow
  /// stops at the geofence screen before reaching what it meant to test.
  List<String> deniedCodes = const [];

  @override
  Future<DeniedCountriesResponse> getDeniedCountries({CancelToken? cancelToken}) async =>
      DeniedCountriesResponse(deniedCodes: deniedCodes);
}

/// Care directory with a few fixed places around the fallback map centre
/// (Cairo, 30.0444/31.2357).
///
/// Returning an empty list here left the map tab rendering tiles with no pins,
/// which reads as "the map is broken" and makes the screen impossible to test
/// offline. These are public business listings, not PHI.
class FakeCareDirectoryApi implements CareDirectoryApi {
  static const _places = [
    CareEntityResponse(
      id: 'e2e-hospital-1',
      type: 'hospital',
      nameEn: 'E2E General Hospital',
      nameAr: 'مستشفى الاختبار العام',
      addressEn: '1 Test Street, Cairo',
      addressAr: '١ شارع الاختبار، القاهرة',
      lat: 30.0459,
      lng: 31.2243,
      hours: '24/7',
      phone: '+20 2 0000 0001',
      distanceKm: 1.2,
      rating: 4.5,
    ),
    CareEntityResponse(
      id: 'e2e-pharmacy-1',
      type: 'pharmacy',
      nameEn: 'E2E Pharmacy',
      nameAr: 'صيدلية الاختبار',
      addressEn: '2 Test Street, Cairo',
      addressAr: '٢ شارع الاختبار، القاهرة',
      lat: 30.0402,
      lng: 31.2357,
      hours: '09:00–23:00',
      phone: '+20 2 0000 0002',
      distanceKm: 0.6,
      rating: 4.2,
    ),
    CareEntityResponse(
      id: 'e2e-lab-1',
      type: 'lab',
      nameEn: 'E2E Diagnostics Lab',
      nameAr: 'معمل تحاليل الاختبار',
      addressEn: '3 Test Street, Cairo',
      addressAr: '٣ شارع الاختبار، القاهرة',
      lat: 30.0512,
      lng: 31.2401,
      hours: '08:00–20:00',
      phone: '+20 2 0000 0003',
      distanceKm: 2.1,
      rating: 4.0,
    ),
    CareEntityResponse(
      id: 'e2e-dentist-1',
      type: 'dentist',
      nameEn: 'E2E Dental Clinic',
      nameAr: 'عيادة الاختبار للأسنان',
      addressEn: '4 Test Street, Cairo',
      addressAr: '٤ شارع الاختبار، القاهرة',
      lat: 30.0480,
      lng: 31.2290,
      hours: '10:00–18:00',
      phone: '+20 2 0000 0004',
      distanceKm: 1.8,
      rating: 4.7,
    ),
  ];

  /// Applies the same narrowing the real endpoint does — radius, single type,
  /// and free text over both scripts — so search can be exercised offline. A
  /// fake that ignored the query would let a broken search look like it works.
  @override
  Future<List<CareEntityResponse>> nearby(NearbyCareQuery query, {CancelToken? cancelToken}) async {
    final text = query.query?.trim().toLowerCase() ?? '';
    return _places.where((p) {
      if (query.type != null && p.type != query.type) return false;
      if (query.radiusKm != null && (p.distanceKm ?? 0) > query.radiusKm!) return false;
      if (text.isEmpty) return true;
      return (p.nameEn ?? '').toLowerCase().contains(text) ||
          (p.nameAr ?? '').contains(query.query!.trim()) ||
          (p.addressEn ?? '').toLowerCase().contains(text);
    }).toList(growable: false);
  }
}

/// Binds every `Provider<XxxApi>` to a fake. Pass a pre-configured fake to force
/// a branch; omit it for a fresh default.
///
/// This is the canonical list — the e2e entrypoint and the Patrol tests both use
/// it, so they cannot drift apart.
List<Override> e2eApiOverrides({
  FakeAuthApi? auth,
  FakeAccountApi? account,
  FakeSessionsApi? sessions,
  FakeEmergencyQrApi? emergencyQr,
  FakeDeletionApi? deletion,
  FakeDisclosureApi? disclosure,
  FakeGeofenceApi? geofence,
  FakeCareDirectoryApi? careDirectory,
}) =>
    [
      authApiProvider.overrideWithValue(auth ?? FakeAuthApi()),
      accountApiProvider.overrideWithValue(account ?? FakeAccountApi()),
      sessionsApiProvider.overrideWithValue(sessions ?? FakeSessionsApi()),
      emergencyQrApiProvider.overrideWithValue(emergencyQr ?? FakeEmergencyQrApi()),
      deletionApiProvider.overrideWithValue(deletion ?? FakeDeletionApi()),
      disclosureApiProvider.overrideWithValue(disclosure ?? FakeDisclosureApi()),
      geofenceApiProvider.overrideWithValue(geofence ?? FakeGeofenceApi()),
      careDirectoryApiProvider.overrideWithValue(careDirectory ?? FakeCareDirectoryApi()),
    ];
