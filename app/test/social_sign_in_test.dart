import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/auth_flow.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart'
    show DisclosureAcceptance, DisclosureDao, DisclosureId, disclosureDaoProvider;
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Google sign-in ships on Android/web/macOS only — iOS shows no third-party
/// sign-in at all (App Review 4.8), and the Apple provider stays off until
/// team ownership settles. A new social account enters the app directly; the
/// Profile tab's gaps card owns completion and everything DOB-gated stays
/// fail-closed until Personal details is saved.
class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockDisclosureDao extends Mock implements DisclosureDao {}

/// Returns a fixed result instead of touching the platform SDK.
class _StubCredentials implements SocialCredentialsPort {
  _StubCredentials(this.result);
  final SocialCredentialsResult result;
  var calls = 0;

  @override
  Future<SocialCredentialsResult> obtain() async {
    calls++;
    return result;
  }
}

const _googleTokens = SocialCredentials(
  idToken: 'google-id-token',
  authorizationCode: '',
  email: 'layla@example.com',
  givenName: 'Layla',
  familyName: 'Hassan',
);

void main() {
  late PatientAppState state;
  late _MockSignInUseCase signIn;
  late _MockDisclosureDao disclosure;

  setUpAll(() => registerFallbackValue(const DisclosureId.value('consolidated')));

  setUp(() {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
      socialSignInEnabled: true,
      googleServerClientId: 'web-client.apps.googleusercontent.com',
      googleIosClientId: 'ios-client.apps.googleusercontent.com',
    );
    state = PatientAppState();
    signIn = _MockSignInUseCase();
    disclosure = _MockDisclosureDao();
    when(() => disclosure.watchAcceptance(any(), any())).thenAnswer((_) => Stream<DisclosureAcceptance?>.value(null));
  });

  /// Runs [body] with the target platform overridden.
  ///
  /// The override has to stay set for the whole body — every rebuild re-reads
  /// it to decide whether the Apple button exists — and has to be cleared
  /// before the body returns, because the framework asserts on it there.
  Future<void> onPlatform(TargetPlatform platform, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    SocialCredentialsPort? apple,
    SocialCredentialsPort? google,
  }) async {
    // A tall phone surface: the welcome layout overflows the default 800×600,
    // and an overflow exception fails every finder that follows it.
    tester.view.physicalSize = const Size(402, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signInUseCaseProvider.overrideWithValue(signIn),
          disclosureDaoProvider.overrideWithValue(disclosure),
          if (apple != null) appleCredentialsPortProvider.overrideWithValue(apple),
          if (google != null) googleCredentialsPortProvider.overrideWithValue(google),
        ],
        child: MaterialApp(
          // Profile setup's TextFields need a Material ancestor; the screens
          // paint their own backgrounds, so a transparent one keeps layout
          // identical to the app, where the shell supplies it.
          home: Material(
            type: MaterialType.transparency,
            child: AppScope(state: state, child: const AuthRouter()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder appleButton() => find.text('Continue with Apple');
  Finder googleButton() => find.text('Continue with Google');

  void stubGoogle(AppResult<SignInResult> result) {
    when(() => signIn.signInWithGoogle(
          idToken: any(named: 'idToken'),
          email: any(named: 'email'),
          countryCode: any(named: 'countryCode'),
        )).thenAnswer((_) async => result);
  }

  /// Taps Google and lets the awaits in the handler settle.
  Future<void> tapGoogle(WidgetTester tester) async {
    await tester.tap(googleButton());
    await tester.pumpAndSettle();
  }

  group('button availability', () {
    testWidgets('iOS offers NO third-party sign-in (App Review 4.8)', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester);

        expect(appleButton(), findsNothing);
        expect(googleButton(), findsNothing);
      });
    });

    testWidgets('Android offers Google only — Apple stays off', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await pump(tester);

        expect(appleButton(), findsNothing);
        expect(googleButton(), findsOneWidget);
      });
    });

    testWidgets('neither provider is offered while social sign-in is disabled', (tester) async {
      // The shipped default. Both flows stay implemented and tested; the switch
      // is what decides whether users can reach them.
      FlavorConfig.init(
        brand: AppBrand.balsm,
        flavor: Flavor.dev,
        servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
        socialSignInEnabled: false,
        googleServerClientId: 'web-client.apps.googleusercontent.com',
        googleIosClientId: 'ios-client.apps.googleusercontent.com',
      );

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester);

        expect(appleButton(), findsNothing);
        expect(googleButton(), findsNothing);
      });
    });

    testWidgets('Google is hidden without a configured server client id', (tester) async {
      FlavorConfig.init(
        brand: AppBrand.balsm,
        flavor: Flavor.dev,
        servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
        socialSignInEnabled: true,
        googleServerClientId: '',
      );

      await onPlatform(TargetPlatform.android, () async {
        await pump(tester);

        expect(googleButton(), findsNothing);
      });
    });
  });

  group('routing after a successful exchange', () {
    testWidgets('a new account enters the app — completion is the gaps card', (tester) async {
      stubGoogle(AppResult.success(const SignInSuccess(isNewUser: true)));

      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(_googleTokens));
        await tapGoogle(tester);
      });

      expect(state.route, isNot('profile'), reason: 'profile setup left the registration flow');
      expect(state.socialGivenName, 'Layla', reason: 'the provider name prefills Personal details');
    });

    testWidgets('a returning account goes straight through', (tester) async {
      stubGoogle(AppResult.success(const SignInSuccess()));

      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(_googleTokens));
        await tapGoogle(tester);
      });

      expect(state.route, isNot('profile'));
      expect(state.socialGivenName, isNull, reason: 'no prefill for an existing account');
    });

    testWidgets('the exchange carries the account country', (tester) async {
      stubGoogle(AppResult.success(const SignInSuccess(isNewUser: true)));
      state.country = CountryCode.fromCode('SA');

      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(_googleTokens));
        await tapGoogle(tester);
      });

      verify(() => signIn.signInWithGoogle(
            idToken: 'google-id-token',
            email: 'layla@example.com',
            countryCode: 'SA',
          )).called(1);
    });
  });

  group('provider outcomes that never reach the exchange', () {
    testWidgets('cancelling stays on welcome and shows nothing', (tester) async {
      final port = _StubCredentials(const SocialCredentialsCancelled());

      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: port);
        await tapGoogle(tester);

        expect(find.text('Sign-in failed. Please try again.'), findsNothing);
      });

      expect(port.calls, 1);
      expect(state.route, 'welcome');
      verifyNever(() => signIn.signInWithGoogle(
            idToken: any(named: 'idToken'),
            email: any(named: 'email'),
            countryCode: any(named: 'countryCode'),
          ));
    });

    testWidgets('a missing ID token reads as unavailable, not as the user failing', (tester) async {
      // On Android this is the signature of an unconfigured serverClientId.
      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(const SocialCredentialsFailure(missingToken: true)));
        await tapGoogle(tester);

        expect(find.text('Sign-in is unavailable right now. Use your email instead.'), findsOneWidget);
      });

      expect(state.route, 'welcome');
    });

    testWidgets('a failed flow shows the retry message', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(const SocialCredentialsFailure()));
        await tapGoogle(tester);

        expect(find.text('Sign-in failed. Please try again.'), findsOneWidget);
      });
    });
  });

  testWidgets('a lockout surfaces the countdown instead of navigating', (tester) async {
    stubGoogle(AppResult.success(
      SignInLockout(
        session: LockedOut(until: DateTime.now().add(const Duration(seconds: 90)), identifier: 'x'),
      ),
    ));

    await onPlatform(TargetPlatform.android, () async {
      await pump(tester, google: _StubCredentials(_googleTokens));
      await tapGoogle(tester);

      expect(find.textContaining('Account temporarily locked'), findsOneWidget);
    });

    expect(state.route, 'welcome');
  });
}
