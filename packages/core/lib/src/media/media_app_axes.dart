import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// The app's own values for media app axes, from [context]: `theme` (the
/// app theme's brightness; the app is light-only today), `locale` (the app language) and `platform`. An
/// axis the app cannot tell is left out, so it matches only renditions
/// that do not name it.
Map<String, String> mediaAppAxes(BuildContext context) {
  final platform = kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'ios',
          TargetPlatform.android => 'android',
          _ => null,
        };
  return {
    'theme': Theme.of(context).brightness == Brightness.dark ? 'dark' : 'light',
    if (Localizations.maybeLocaleOf(context) case final locale?) 'locale': locale.languageCode,
    if (platform != null) 'platform': platform,
  };
}
