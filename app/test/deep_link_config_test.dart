import 'dart:convert';
import 'dart:io';

import 'package:app/balsm_app/deep_links.dart';
import 'package:app/balsm_app/routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deep linking is configured in four places that must agree, and until this
/// test existed they didn't: the Android intent-filters routed two stale paths,
/// the iOS association file carried a placeholder team and the wrong bundle id,
/// and the iOS entitlement expanded to an empty `applinks:` host. Each of those
/// fails silently — the link opens the browser, nothing crashes, nobody notices.
///
///   route table  lib/balsm_app/deep_links.dart          (what the app routes)
///   Android      android/app/src/main/AndroidManifest.xml (what opens the app)
///   iOS          web/.well-known/apple-app-site-association (what opens the app)
///   Android      web/.well-known/assetlinks.json          (who may open it)
void main() {
  const host = 'app.balsm.health';
  const bundleId = 'app.balsm.health';
  const teamId = '8F78S7D344';

  String read(String path) => File(path).readAsStringSync();

  /// One representative path per destination in the route table. Built from the
  /// table's own enums, so a new tab or screen is covered automatically.
  final routablePaths = <String>[
    '/t/01J8ABC',
    '/emergency/01J8ABC',
    '/${PublicQrPaths.deleteAccount}',
    '/${PublicQrPaths.deleteAccountCancel}',
    '/account/delete',
    '/account/delete-cancelled',
    '/auth/link',
    for (final tab in AppTab.values) '/${tab.id}',
    for (final screen in AppScreen.values) '/${screen.path}',
  ];

  test('every representative path really is routable (keeps this list honest)', () {
    for (final path in routablePaths) {
      final target = parseDeepLink(Uri.parse('https://$host$path'));
      expect(target, isNotNull, reason: path);
      expect(target, isNot(isA<UnknownTarget>()), reason: path);
    }
  });

  group('Android', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final prefixes = RegExp(r'android:pathPrefix="([^"]+)"').allMatches(manifest).map((m) => m.group(1)!).toList();

    test('the App Links filter is verified and bound to the app host', () {
      expect(manifest, contains('android:autoVerify="true"'));
      expect(read('android/app/build.gradle.kts'), contains('manifestPlaceholders["BASE_URL"] = "$host"'));
    });

    test('every routable path opens the app, not the browser', () {
      final missing = routablePaths.where((p) => !prefixes.any(p.startsWith)).toList();
      expect(missing, isEmpty, reason: 'add an android:pathPrefix for: $missing');
    });

    test('the balsm:// scheme accepts every route, not only auth', () {
      expect(RegExp(r'<data android:scheme="balsm"\s*/>').hasMatch(manifest), isTrue);
    });

    test('assetlinks.json names this app', () {
      final links = jsonDecode(read('web/.well-known/assetlinks.json')) as List;
      final target = (links.single as Map)['target'] as Map;
      expect(target['package_name'], bundleId);
    });

    final fingerprints = ((jsonDecode(read('web/.well-known/assetlinks.json')) as List).single as Map)['target']
        ['sha256_cert_fingerprints'] as List;
    final placeholder = fingerprints.any((f) => '$f'.contains('PLACEHOLDER'));
    test(
      'assetlinks.json carries a real signing-key fingerprint',
      () {
        final shape = RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$');
        for (final f in fingerprints) {
          expect(shape.hasMatch('$f'), isTrue, reason: '$f is not a SHA-256 fingerprint');
        }
      },
      // Skipped, loudly, rather than faked: until the Play App Signing SHA-256 is
      // filled in, Android refuses to verify the domain and every https link opens
      // the browser. The skip reason prints in every test run.
      skip: placeholder
          ? 'assetlinks.json still has PLACEHOLDER_FILLED_BY_CI — paste the Play Console '
              'app-signing SHA-256; until then Android App Links cannot verify.'
          : false,
    );
  });

  group('iOS', () {
    final aasa = jsonDecode(read('web/.well-known/apple-app-site-association')) as Map<String, dynamic>;
    final detail = ((aasa['applinks'] as Map)['details'] as List).single as Map;
    final patterns = (detail['components'] as List).map((c) => (c as Map)['/'] as String).toList();

    bool matches(String pattern, String path) =>
        pattern.endsWith('*') ? path.startsWith(pattern.substring(0, pattern.length - 1)) : path == pattern;

    test('the association file names this team and bundle id', () {
      expect(detail['appIDs'], ['$teamId.$bundleId']);
    });

    test('every routable path opens the app, not Safari', () {
      final missing = routablePaths.where((p) => !patterns.any((pat) => matches(pat, p))).toList();
      expect(missing, isEmpty, reason: 'add an applinks component for: $missing');
    });

    test('the entitlement host is defined for every build configuration', () {
      expect(read('ios/Runner/Runner.entitlements'), contains(r'applinks:$(BASE_URL)'));
      // Debug + Release cover Runner's Debug, Release and Profile configurations.
      for (final xcconfig in ['ios/Flutter/Debug.xcconfig', 'ios/Flutter/Release.xcconfig']) {
        expect(
          RegExp(r'^BASE_URL\s*=\s*' + RegExp.escape(host) + r'\s*$', multiLine: true).hasMatch(read(xcconfig)),
          isTrue,
          reason: '$xcconfig must define BASE_URL = $host, or applinks: expands to nothing',
        );
      }
    });

    test('every Runner build configuration signs with the entitlements file', () {
      // Without CODE_SIGN_ENTITLEMENTS the file above is dead text: no build
      // ever carried applinks:, so https links always opened Safari.
      final configs = RegExp(r'isa = XCBuildConfiguration;.*?name = ([^;]+);', dotAll: true)
          .allMatches(read('ios/Runner.xcodeproj/project.pbxproj'))
          .map((m) => m.group(0)!)
          .where((b) => b.contains('PRODUCT_BUNDLE_IDENTIFIER = app.balsm.health;'))
          .toList();
      expect(configs, isNotEmpty);
      for (final c in configs) {
        expect(c, contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'));
      }
    });

    test('a link that launches the app reaches app_links (UIScene lifecycle)', () {
      // app_links only reads the app delegate's launchOptions, which are empty
      // under UIScene. Without this forwarding every cold-start link is lost.
      final scene = read('ios/Runner/SceneDelegate.swift');
      expect(scene, contains('connectionOptions.urlContexts'));
      expect(scene, contains('connectionOptions.userActivities'));
      expect(scene, contains('AppLinks.shared.handleLink'));
    });

    test('the balsm:// scheme is registered', () {
      expect(read('ios/Runner/Info.plist'), contains('<string>balsm</string>'));
    });
  });

  // Flutter's built-in deep linking (on by default since 3.27) also pushes every
  // link as a Navigator route. With `home:` and no route table that route is a
  // second copy of the whole shell stacked over the real one: DeepLinkHandler's
  // screen opens underneath it, and the duplicate handler steals later links.
  // Found on the iOS simulator — the unit tests could not see it.
  group('Flutter built-in deep linking is off, so only DeepLinkHandler routes', () {
    test('iOS', () {
      expect(
        RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false/>').hasMatch(read('ios/Runner/Info.plist')),
        isTrue,
      );
    });

    test('Android (read from the activity, not the application)', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      final activity = RegExp(r'<activity[\s\S]*?</activity>').firstMatch(manifest)!.group(0)!;
      expect(activity, contains('<meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>'));
    });
  });
}
