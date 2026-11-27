import 'package:core/core.dart' show BalsmField, BalsmRoundButton;
import 'package:marionette_flutter/marionette_flutter.dart';

import '../balsm_app/kit.dart' show PButton, PSwitch, Pressable;

/// Teaches Marionette the app's own design-system widgets, which zero-config
/// setup does not recognise. Imported only by the e2e entrypoint, so release
/// builds carry none of it.
MarionetteConfiguration balsmMarionetteConfiguration() => MarionetteConfiguration(
      isInteractiveElement: (element) => switch (element.widget) {
        PButton() || PSwitch() || Pressable() || BalsmRoundButton() || BalsmField() => true,
        _ => false,
      },
      extractText: (element) => switch (element.widget) {
        PButton(:final label) => label,
        BalsmField(:final label) => label,
        _ => null,
      },
    );
