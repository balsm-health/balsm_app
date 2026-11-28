import 'package:app/balsm_app/screens/social_providers.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

void main() {
  void init({bool enabled = true, String server = 'server-id', String ios = 'ios-id'}) {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
      socialSignInEnabled: enabled,
      googleServerClientId: server,
      googleIosClientId: ios,
    );
  }

  List<SocialProvider> available(TargetPlatform platform, {bool isWeb = false}) =>
      availableSocialProviders(config: FlavorConfig.current, platform: platform, isWeb: isWeb);

  test('ios_withAllIds_returnsAppleThenGoogle', () {
    init();
    expect(available(TargetPlatform.iOS), [SocialProvider.apple, SocialProvider.google]);
  });

  test('ios_withoutIosClientId_returnsAppleOnly', () {
    init(ios: '');
    expect(available(TargetPlatform.iOS), [SocialProvider.apple]);
  });

  test('android_returnsGoogleOnly', () {
    init(ios: '');
    expect(available(TargetPlatform.android), [SocialProvider.google]);
  });

  test('macos_returnsGoogleOnly', () {
    init(ios: '');
    expect(available(TargetPlatform.macOS), [SocialProvider.google]);
  });

  test('web_returnsEmpty', () {
    init();
    expect(available(TargetPlatform.iOS, isWeb: true), isEmpty);
  });

  test('flagOff_returnsEmpty', () {
    init(enabled: false);
    expect(available(TargetPlatform.iOS), isEmpty);
  });

  test('android_withoutServerClientId_returnsEmpty', () {
    init(server: '');
    expect(available(TargetPlatform.android), isEmpty);
  });

  test('windows_returnsEmpty', () {
    init();
    expect(available(TargetPlatform.windows), isEmpty);
  });
}
