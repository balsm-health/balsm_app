import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'demo_kit.dart';

/// The daily check-in from Home: mood → blood pressure → glucose → saved,
/// then on to Trends and back Home.
void main() {
  patrolTest('full check-in: mood, blood pressure, glucose', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'checkin');
    await openTab(tester, t.nav.tab_home);

    await scrollToAndTap(tester, textAnyGender(t.home.hero_cta));
    await pumpUntil(tester, find.text(t.checkin.full_checkin).hitTestable());

    // Mood.
    await tapWhenReady(tester, textAnyGender(t.checkin.mood_4));
    await tapWhenReady(tester, find.text(t.common.continue_));

    // Blood pressure 120/80: digits go to the systolic box until it has
    // three, then to the diastolic one.
    await typeOnNumPad(tester, '120');
    await typeOnNumPad(tester, '80');
    await tapWhenReady(tester, find.text(t.common.continue_));

    // Glucose 95, fasting. Last step: the button reads Finish.
    await tapWhenReady(tester, find.text(t.checkin.glu_fast));
    await typeOnNumPad(tester, '95');
    await tapWhenReady(tester, find.text(t.common.finish));

    // Saved.
    await pumpUntil(tester, find.text(t.common.saved_t).hitTestable());
    expect(find.text(t.checkin.view_trends), findsOneWidget);
    expectNoOverflowErrors(tester);

    await tapWhenReady(tester, find.text(t.care.to_home));
    await pumpUntil(tester, find.text(t.nav.tab_meds).hitTestable());
  });
}
