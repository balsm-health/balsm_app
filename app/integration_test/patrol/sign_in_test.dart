import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:core/core.dart';
import 'package:patrol/patrol.dart';

/// New-account sign-in must land on profile setup, because that is where the
/// fail-closed DOB/age gate runs. A build that sent new users straight to the
/// shell would bypass it — which is the whole reason this test exists.
void main() {
  patrolTest('a new account lands on profile setup', ($) async {
    final auth = FakeAuthApi()..nextIsNewUser = true;
    await app.bootstrap(extraOverrides: e2eApiOverrides(auth: auth));
    await $.pumpAndSettle();

    // First launch opens the walkthrough; skip it when present.
    if ($('Skip').exists) {
      await $('Skip').tap();
    }
    await $('Get started').tap();

    await $(#emailField).enterText(E2eFixture.email);
    await $(#passwordField).enterText('e2e-password');
    await $('Sign in').tap();

    // Profile setup asks for the date of birth; the shell never does.
    expect($('Date of birth'), findsOneWidget);
  });
}
