import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'demo_kit.dart';

/// Mother & Child, pregnancy side: start tracking from Home, the pregnancy
/// screen with this week's guidance and the week-by-week list, twins, and
/// the pregnancy emergency card.
void main() {
  patrolTest('start a pregnancy, guidance, twins and the pregnancy card', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'pregnancy');
    await openTab(tester, t.nav.tab_home);

    // The prompt on Home (shown to a patient who is not male).
    await scrollToAndTap(tester, find.text(t.pregnancy.title));
    await tapWhenReady(tester, find.text(t.pregnancy.mode_due));
    await scrollToAndTap(tester, find.text(t.pregnancy.pick_date));
    // About four months ahead: within the due-date window.
    await pickDate(tester, monthsAhead: 4, day: 15);
    await scrollToAndTap(tester, find.text(t.pregnancy.start_cta));

    // The pregnancy screen.
    await pumpUntil(tester, find.text(t.pregnancy.add_baby).hitTestable());
    expectNoOverflowErrors(tester);

    // This week's guidance comes from the server; the list of weeks opens.
    await scrollToAndTap(tester, find.text(t.pregnancy.all_weeks));
    await pumpUntil(tester, find.text(t.pregnancy.weeks_title).hitTestable());
    expectNoOverflowErrors(tester);
    await goBack(tester);

    // Twins: the two baby cards share a row and must not cut their names.
    await scrollToAndTap(tester, find.text(t.pregnancy.add_baby));
    await settle(tester);
    expectNoOverflowErrors(tester);

    // The pregnancy emergency card.
    await scrollToAndTap(tester, find.text(t.pregnancy.card_row));
    await settle(tester);
    expectNoOverflowErrors(tester);
    await goBack(tester);
  });
}
