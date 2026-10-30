import 'package:app/balsm_app/routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screen recording may only run before any health data is on screen.
void main() {
  test('only the walkthrough and sign-in funnel are recordable', () {
    expect(kReplayAllowedRoutes, {AppRoutes.walkthrough, AppRoutes.welcome, AppRoutes.phone, AppRoutes.otp});
  });

  test('the signed-in app, profile setup and unlock are never recorded', () {
    for (final r in [AppRoutes.app, AppRoutes.profileSetup, AppRoutes.unlock, AppRoutes.mergeOrDiscard]) {
      expect(kReplayAllowedRoutes, isNot(contains(r)));
    }
  });
}
