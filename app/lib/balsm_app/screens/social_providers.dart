import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

enum SocialProvider { apple, google }

/// The social sign-in providers this build offers on [platform], ordered as
/// drawn: Apple first, then Google.
///
/// Apple is iOS only. Google runs on iOS, Android and macOS; on iOS it also
/// needs [FlavorConfig.googleIosClientId], whose reversed id must be a real
/// URL scheme. Nothing is offered on web or when the flag is off.
List<SocialProvider> availableSocialProviders({
  required FlavorConfig config,
  required TargetPlatform platform,
  required bool isWeb,
}) {
  if (isWeb || !config.socialSignInEnabled) return const [];
  final googleOnPlatform = switch (platform) {
    TargetPlatform.android || TargetPlatform.macOS => true,
    TargetPlatform.iOS => config.googleIosClientId.isNotEmpty,
    _ => false,
  };
  return [
    if (platform == TargetPlatform.iOS) SocialProvider.apple,
    if (config.googleServerClientId.isNotEmpty && googleOnPlatform) SocialProvider.google,
  ];
}
