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

/// The welcome screen's Apple/Google buttons used to be decoys that dropped the
/// user into email sign-up. Now they run the real provider flow — and, on a new
/// account, must still land on profile setup, because that is where the
/// fail-closed DOB/age gate runs. A social sign-in that jumped straight to the
/// app shell would bypass it.
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

const _appleTokens = SocialCredentials(
  idToken: 'apple-id-token',
  authorizationCode: 'apple-auth-code',
  email: 'relay@privaterelay.appleid.com',
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

  void stubApple(AppResult<SignInResult> result) {
    when(() => signIn.signInWithApple(
          idToken: any(named: 'idToken'),
          authCode: any(named: 'authCode'),
          email: any(named: 'email'),
          countryCode: any(named: 'countryCode'),
        )).thenAnswer((_) async => result);
  }

  /// Taps Apple and lets the two awaits in the handler settle.
  Future<void> tapApple(WidgetTester tester) async {
    await tester.tap(appleButton());
    await tester.pumpAndSettle();
  }

  group('button availability', () {
    testWidgets('both providers are offered on iOS', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester);

        expect(appleButton(), findsOneWidget);
        expect(googleButton(), findsOneWidget);
      });
    });

    testWidgets('Apple is hidden on Android — the native flow is iOS-only', (tester) async {
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
    testWidgets('a new account goes to profile setup, where the age gate runs', (tester) async {
      stubApple(AppResult.success(const SignInSuccess(isNewUser: true)));

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: _StubCredentials(_appleTokens));
        await tapApple(tester);
      });

      expect(state.route, 'profile', reason: 'social sign-up must not skip the DOB/age gate');
    });

    testWidgets('the name Apple hands over once prefills profile setup', (tester) async {
      stubApple(AppResult.success(const SignInSuccess(isNewUser: true)));

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: _StubCredentials(_appleTokens));
        await tapApple(tester);

        expect(find.widgetWithText(TextField, 'Layla'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Hassan'), findsOneWidget);
      });

      expect(state.socialGivenName, isNull, reason: 'the one-shot prefill is consumed');
    });

    testWidgets('a returning account skips profile setup', (tester) async {
      stubApple(AppResult.success(const SignInSuccess()));

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: _StubCredentials(_appleTokens));
        await tapApple(tester);
      });

      expect(state.route, isNot('profile'));
    });

    testWidgets('the exchange carries the account country and the Apple auth code', (tester) async {
      stubApple(AppResult.success(const SignInSuccess(isNewUser: true)));
      state.country = CountryCode.fromCode('SA');

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: _StubCredentials(_appleTokens));
        await tapApple(tester);
      });

      verify(() => signIn.signInWithApple(
            idToken: 'apple-id-token',
            authCode: 'apple-auth-code',
            email: 'relay@privaterelay.appleid.com',
            countryCode: 'SA',
          )).called(1);
    });
  });

  group('provider outcomes that never reach the exchange', () {
    testWidgets('cancelling stays on welcome and shows nothing', (tester) async {
      final port = _StubCredentials(const SocialCredentialsCancelled());

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: port);
        await tapApple(tester);

        expect(find.text('Sign-in failed. Please try again.'), findsNothing);
      });

      expect(port.calls, 1);
      expect(state.route, 'welcome');
      verifyNever(() => signIn.signInWithApple(
            idToken: any(named: 'idToken'),
            authCode: any(named: 'authCode'),
            email: any(named: 'email'),
            countryCode: any(named: 'countryCode'),
          ));
    });

    testWidgets('a missing ID token reads as unavailable, not as the user failing', (tester) async {
      // On Android this is the signature of an unconfigured serverClientId.
      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: _StubCredentials(const SocialCredentialsFailure(missingToken: true)));
        await tapApple(tester);

        expect(find.text('Sign-in is unavailable right now. Use your email instead.'), findsOneWidget);
      });

      expect(state.route, 'welcome');
    });

    testWidgets('a failed flow shows the retry message', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: _StubCredentials(const SocialCredentialsFailure()));
        await tapApple(tester);

        expect(find.text('Sign-in failed. Please try again.'), findsOneWidget);
      });
    });
  });

  testWidgets('a lockout surfaces the countdown instead of navigating', (tester) async {
    stubApple(AppResult.success(
      SignInLockout(
        session: LockedOut(until: DateTime.now().add(const Duration(seconds: 90)), identifier: 'x'),
      ),
    ));

    await onPlatform(TargetPlatform.iOS, () async {
      await pump(tester, apple: _StubCredentials(_appleTokens));
      await tapApple(tester);

      expect(find.textContaining('Account temporarily locked'), findsOneWidget);
    });

    expect(state.route, 'welcome');
  });
}
