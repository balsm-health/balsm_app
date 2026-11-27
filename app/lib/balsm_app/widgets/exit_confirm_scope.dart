import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../screens/family/family_kit.dart' show showFamilyConfirmSheet;

/// Asks before the system back button leaves the app.
///
/// On Android, back on the last screen (nothing left to pop) closes the app
/// at once, which is easy to do by accident. Wrap the root screen in this and
/// that back opens "Exit Balsm?" first; **Exit** closes the app, **Cancel**
/// stays. Screens and sheets pushed above the root still pop normally, because
/// the guard only speaks for the route it sits on.
///
/// [stepBack] lets a screen of the root that sits "above" another one (records
/// above Home) take the back itself: return true when it handled it, and no
/// question is asked. Other platforms have no system back to guard.
class ExitConfirmScope extends StatelessWidget {
  const ExitConfirmScope({required this.child, super.key, this.stepBack});

  final Widget child;
  final bool Function()? stepBack;

  /// Android is the only platform whose back button leaves the app.
  static bool get _guarding => defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_guarding,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || (stepBack?.call() ?? false)) return;
          unawaited(_confirmExit(context));
        },
        child: child,
      );

  Future<void> _confirmExit(BuildContext context) async {
    final c = AppScope.of(context).strings.common;
    final leave = await showFamilyConfirmSheet(context, title: c.exit_t, body: c.exit_b, confirmLabel: c.exit_cta);
    if (leave) await SystemNavigator.pop();
  }
}
