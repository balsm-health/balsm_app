import 'dart:async';

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/routes.dart';
import 'package:app/balsm_app/screens/auth_flow.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart'
    show DisclosureAcceptance, DisclosureDao, DisclosureId, disclosureDaoProvider;
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

/// Sign in with Apple and Google, per the Auth Flow design: the providers sit
/// above "Create an account" on Welcome and above the email field on the
/// sign-up / sign-in screens, Apple first. Which providers show is
/// `availableSocialProviders` (Apple on iOS only; Google on Android, macOS and
/// iOS with an iOS client id). A new social account enters the app directly;
/// the Profile tab's gaps card owns completion and everything DOB-gated stays
/// fail-closed until Personal details is saved.
class _MockSignInUseCase extends Mock implements SignInUseCase {}

class _MockDisclosureDao extends Mock implements DisclosureDao {}

/// Returns a fixed result instead of touching the platform SDK.
class _StubCredentials implements SocialCredentialsPort {
  _StubCredentials(this.result);
  final SocialCredentialsResult result;
  int calls = 0;

  @override
  Future<SocialCredentialsResult> obtain() async {
    calls++;
    return result;
  }
}

/// Holds the provider sheet open until the test completes it.
class _PendingCredentials implements SocialCredentialsPort {
  final completer = Completer<SocialCredentialsResult>();

  @override
  Future<SocialCredentialsResult> obtain() => completer.future;
}

const _appleTokens = SocialCredentials(
  idToken: 'apple-id-token',
  authorizationCode: 'apple-code',
  givenName: 'Layla',
  familyName: 'Hassan',
);

const _googleTokens = SocialCredentials(
  idToken: 'google-id-token',
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
    Size size = const Size(402, 1400),
  }) async {
    // A tall phone surface by default: the welcome layout overflows the
    // default 800×600, and an overflow exception fails every finder after it.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
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
  Finder orEmail() => find.text('or with email');

  void stubGoogle(AppResult<SignInResult> result) {
    when(
      () => signIn.signInWithGoogle(
        idToken: any(named: 'idToken'),
        email: any(named: 'email'),
        countryCode: any(named: 'countryCode'),
      ),
    ).thenAnswer((_) async => result);
  }

  void stubApple(AppResult<SignInResult> result) {
    when(
      () => signIn.signInWithApple(
        idToken: any(named: 'idToken'),
        authCode: any(named: 'authCode'),
        email: any(named: 'email'),
        countryCode: any(named: 'countryCode'),
      ),
    ).thenAnswer((_) async => result);
  }

  /// Taps [button] and lets the awaits in the handler settle.
  Future<void> tapAndSettle(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  void initFlavor({String googleIosClientId = 'ios-client.apps.googleusercontent.com'}) => FlavorConfig.init(
        brand: AppBrand.balsm,
        flavor: Flavor.dev,
        servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
        socialSignInEnabled: true,
        googleServerClientId: 'web-client.apps.googleusercontent.com',
        googleIosClientId: googleIosClientId,
      );

  group('welcome', () {
    testWidgets('welcome_onIos_showsAppleAboveGoogleAboveCreateAccount', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester);

        final apple = tester.getTopLeft(appleButton()).dy;
        final google = tester.getTopLeft(googleButton()).dy;
        final divider = tester.getTopLeft(orEmail()).dy;
        final create = tester.getTopLeft(find.text('Create an account')).dy;
        expect(apple, lessThan(google));
        expect(google, lessThan(divider));
        expect(divider, lessThan(create));
      });
    });

    testWidgets('welcome_onIosWithoutIosClientId_showsAppleOnly', (tester) async {
      initFlavor(googleIosClientId: '');

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester);

        expect(appleButton(), findsOneWidget);
        expect(googleButton(), findsNothing);
      });
    });

    testWidgets('welcome_onAndroid_showsGoogleOnly', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await pump(tester);

        expect(appleButton(), findsNothing);
        expect(googleButton(), findsOneWidget);
        expect(orEmail(), findsOneWidget);
      });
    });

    testWidgets('welcome_socialSignInDisabled_showsNoProviderAndNoDivider', (tester) async {
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
        expect(orEmail(), findsNothing);
      });
    });

    for (final (name, size) in [('402x900', const Size(402, 900)), ('a short phone', const Size(360, 700))]) {
      testWidgets('welcome_bothProvidersAndAnError_fitWithoutOverflowOn $name', (tester) async {
        await onPlatform(TargetPlatform.iOS, () async {
          await pump(tester, size: size, google: _StubCredentials(const SocialCredentialsFailure()));
          await tapAndSettle(tester, googleButton());

          expect(tester.takeException(), isNull);
          expect(find.text('Sign-in failed. Please try again.'), findsOneWidget);
        });
      });
    }
  });

  group('email screen', () {
    testWidgets('emailScreen_signIn_showsSocialBlock', (tester) async {
      state
        ..setAuthIntent(AuthIntent.signIn)
        ..go(AppRoutes.phone);

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester);

        expect(appleButton(), findsOneWidget);
        expect(googleButton(), findsOneWidget);
        expect(
          tester.getTopLeft(orEmail()).dy,
          lessThan(tester.getTopLeft(find.byType(TextField).first).dy),
          reason: 'the providers sit above the email field',
        );
      });
    });

    testWidgets('emailScreen_signUp_showsSocialBlock', (tester) async {
      state
        ..setAuthIntent(AuthIntent.signUp)
        ..go(AppRoutes.phone);

      await onPlatform(TargetPlatform.android, () async {
        await pump(tester);

        expect(googleButton(), findsOneWidget);
      });
    });

    testWidgets('emailScreen_deviceOnly_hidesSocialBlock', (tester) async {
      state
        ..setAuthIntent(AuthIntent.deviceOnly)
        ..go(AppRoutes.phone);

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester);

        expect(appleButton(), findsNothing);
        expect(googleButton(), findsNothing);
        expect(orEmail(), findsNothing);
      });
    });
  });

  group('Apple', () {
    testWidgets('apple_success_newUser_sendsAuthCodeAndPrefillsName', (tester) async {
      stubApple(AppResult.success(const SignInSuccess(isNewUser: true)));
      state.country = CountryCode.fromCode('SA');

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: _StubCredentials(_appleTokens));
        await tapAndSettle(tester, appleButton());
      });

      verify(
        () => signIn.signInWithApple(
          idToken: 'apple-id-token',
          authCode: 'apple-code',
          email: '',
          countryCode: 'SA',
        ),
      ).called(1);
      expect(state.route, isNot('profile'), reason: 'profile setup is not part of the social flow');
      expect(state.socialGivenName, 'Layla');
      expect(state.socialFamilyName, 'Hassan');
    });

    testWidgets('apple_cancelled_showsNoError', (tester) async {
      final port = _StubCredentials(const SocialCredentialsCancelled());

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: port);
        await tapAndSettle(tester, appleButton());

        expect(find.text('Sign-in failed. Please try again.'), findsNothing);
        expect(find.text('Sign-in is unavailable right now. Use your email instead.'), findsNothing);
      });

      expect(port.calls, 1);
      expect(state.route, 'welcome');
      verifyNever(
        () => signIn.signInWithApple(
          idToken: any(named: 'idToken'),
          authCode: any(named: 'authCode'),
          email: any(named: 'email'),
          countryCode: any(named: 'countryCode'),
        ),
      );
    });

    testWidgets('whileAppleRuns_googleTapDoesNothing', (tester) async {
      final apple = _PendingCredentials();
      final google = _StubCredentials(_googleTokens);

      await onPlatform(TargetPlatform.iOS, () async {
        await pump(tester, apple: apple, google: google);
        await tester.tap(appleButton());
        await tester.pump();

        await tester.tap(googleButton());
        await tester.pump();
        expect(google.calls, 0, reason: 'both buttons are disabled while one flow runs');
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        apple.completer.complete(const SocialCredentialsCancelled());
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });
  });

  group('Google', () {
    testWidgets('a returning account goes straight through without a prefill', (tester) async {
      stubGoogle(AppResult.success(const SignInSuccess()));

      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(_googleTokens));
        await tapAndSettle(tester, googleButton());
      });

      expect(state.route, isNot('profile'));
      expect(state.socialGivenName, isNull, reason: 'no prefill for an existing account');
    });

    testWidgets('a new account carries the country and prefills the name', (tester) async {
      stubGoogle(AppResult.success(const SignInSuccess(isNewUser: true)));
      state.country = CountryCode.fromCode('SA');

      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(_googleTokens));
        await tapAndSettle(tester, googleButton());
      });

      verify(
        () => signIn.signInWithGoogle(
          idToken: 'google-id-token',
          email: 'layla@example.com',
          countryCode: 'SA',
        ),
      ).called(1);
      expect(state.socialGivenName, 'Layla');
    });

    testWidgets('google_missingToken_showsUnavailable', (tester) async {
      // On Android this is the signature of an unconfigured serverClientId.
      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(const SocialCredentialsFailure(missingToken: true)));
        await tapAndSettle(tester, googleButton());

        expect(find.text('Sign-in is unavailable right now. Use your email instead.'), findsOneWidget);
      });

      expect(state.route, 'welcome');
    });

    testWidgets('a failed flow shows the retry message', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(const SocialCredentialsFailure()));
        await tapAndSettle(tester, googleButton());

        expect(find.text('Sign-in failed. Please try again.'), findsOneWidget);
      });
    });

    testWidgets('a lockout surfaces the countdown instead of navigating', (tester) async {
      stubGoogle(
        AppResult.success(
          SignInLockout(
            session: LockedOut(until: DateTime.now().add(const Duration(seconds: 90)), identifier: 'x'),
          ),
        ),
      );

      await onPlatform(TargetPlatform.android, () async {
        await pump(tester, google: _StubCredentials(_googleTokens));
        await tapAndSettle(tester, googleButton());

        expect(find.textContaining('Account temporarily locked'), findsOneWidget);
      });

      expect(state.route, 'welcome');
    });
  });
}
