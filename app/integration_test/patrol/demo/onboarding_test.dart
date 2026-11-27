import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'demo_kit.dart';

/// First run as a customer meets it: walkthrough → Welcome in Arabic →
/// create an account by email code → privacy notice → the app, then the
/// account details that personalise it.
void main() {
  patrolTest('walkthrough, sign-up and profile details in Arabic', ($) async {
    final tester = $.tester;
    await bootApp($, skipWalkthrough: false);

    // Walkthrough: skip straight to its last page, then start.
    await pumpUntil(
      tester,
      either(find.text(t.walkthrough.wt_skip), find.text(t.walkthrough.wt_start)),
      timeout: const Duration(seconds: 60),
    );
    if (find.text(t.walkthrough.wt_skip).hitTestable().evaluate().isNotEmpty) {
      await tapWhenReady(tester, find.text(t.walkthrough.wt_skip));
    }
    if (find.text(t.walkthrough.wt_start).hitTestable().evaluate().isNotEmpty) {
      await tapWhenReady(tester, find.text(t.walkthrough.wt_start));
    }

    // Welcome offers all three ways in, in Arabic.
    await pumpUntil(tester, find.text(t.onboarding.w_create).hitTestable(), timeout: const Duration(seconds: 60));
    expect(find.text(t.onboarding.w_signin), findsWidgets);
    expect(find.text(t.onboarding.w_device), findsOneWidget);

    await signUp($, tag: 'onboard');

    // The four tabs, labelled in Arabic.
    for (final tab in [t.nav.tab_home, t.nav.tab_map, t.nav.tab_meds, t.nav.tab_profile]) {
      expect(find.text(tab), findsWidgets, reason: 'tab "$tab"');
    }

    await completeProfile($);

    // Home greets the patient by name.
    await openTab(tester, t.nav.tab_home);
    await pumpUntil(tester, find.textContaining(testFirstName));
    expectNoOverflowErrors(tester);
  });
}
