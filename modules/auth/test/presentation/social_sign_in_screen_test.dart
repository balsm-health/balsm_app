import 'package:auth/src/presentation/screens/social_sign_in_screen.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _googleClientId = 'server-client-id.apps.googleusercontent.com';

void main() {
  setUp(() {
    LocalizationUtil.setLocale(const Locale('en'));
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
      socialSignInEnabled: true,
      googleServerClientId: _googleClientId,
      googleIosClientId: 'ios-client-id.apps.googleusercontent.com',
    );
  });

  /// The test framework asserts every foundation debug variable is back to null
  /// by the time the test body returns, so the override is scoped per pump.
  Future<void> pumpOn(WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SocialSignInScreen(countryCode: 'EG')),
      ),
    );
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('offers both providers on iOS', (tester) async {
    await pumpOn(tester, TargetPlatform.iOS);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });
  testWidgets('hides Apple on Android — the native flow is iOS-only', (tester) async {
    await pumpOn(tester, TargetPlatform.android);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
  });
  testWidgets('hides Google when no server client id is configured', (tester) async {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
      socialSignInEnabled: true,
      googleServerClientId: '',
      googleIosClientId: '',
    );
    await pumpOn(tester, TargetPlatform.android);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('offers neither provider while social sign-in is disabled', (tester) async {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
      socialSignInEnabled: false,
      googleServerClientId: _googleClientId,
      googleIosClientId: 'ios-client-id.apps.googleusercontent.com',
    );

    await pumpOn(tester, TargetPlatform.iOS);

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
  });
}
