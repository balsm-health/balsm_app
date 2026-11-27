import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'demo_kit.dart';

/// The everyday actions: a quick reading from the centre button, a
/// medication with a dose marked, and a record added from Home.
void main() {
  /// The centre + of the tab bar (no label of its own).
  Finder quickLogButton() => find.byElementPredicate((e) => e.widget.runtimeType.toString() == '_QuickLog');

  patrolTest('quick log: a weight reading from the centre button', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'quicklog');

    await tapWhenReady(tester, quickLogButton());
    await pumpUntil(tester, find.text(t.checkin.ql_title).hitTestable());
    await scrollToAndTap(tester, find.text(t.profile.m_weight));

    await typeOnNumPad(tester, '62');
    // Save is the body button (the header repeats it as an unlabelled ✓).
    await scrollToAndTap(tester, find.text(t.checkin.ql_save));
    await pumpUntil(tester, find.text(t.checkin.ql_saved));
    expectNoOverflowErrors(tester);
  });

  patrolTest('meds: add a medication and mark a dose taken', ($) async {
    final tester = $.tester;
    const medName = 'دواء اختبار';
    await startSignedIn($, tag: 'meds');

    await openTab(tester, t.nav.tab_meds);
    await tapWhenReady(tester, find.bySemanticsLabel(t.common.a11y_add));
    await pumpUntil(tester, find.text(t.meds.med_add_title).hitTestable());
    await enterByHint(tester, t.meds.rx_med_name_ph, medName);
    await enterByHint(tester, t.meds.rx_med_dose_ph, '500');
    await scrollToAndTap(tester, find.text(t.meds.med_add_btn));
    await pumpUntil(tester, find.text(t.meds.med_added));

    // The sheet closes itself; the med is listed.
    await pumpUntil(tester, find.text(medName).hitTestable());

    // A dose due today can be marked taken from its row.
    if (find.text(t.meds.due).hitTestable().evaluate().isNotEmpty) {
      await tapWhenReady(tester, find.text(t.meds.due));
      await tapWhenReady(tester, find.text(t.meds.taken));
      await pumpUntil(tester, find.text(t.meds.taken).hitTestable());
    }
    expectNoOverflowErrors(tester);
  });

  patrolTest('records: add a lab record without a file', ($) async {
    final tester = $.tester;
    const recTitle = 'تحليل اختبار';
    await startSignedIn($, tag: 'records');

    await openTab(tester, t.nav.tab_home);
    await scrollToAndTap(tester, find.text(t.home.sc_records));
    // A new account has no records: the empty state's button adds one.
    await tapWhenReady(tester, find.text(t.settings.add_record));
    await tapWhenReady(tester, find.text(t.records.rec_lab_one));
    await enterByHint(tester, t.records.rec_title_ph, recTitle);
    await scrollToAndTap(tester, find.text(t.settings.add_record));
    await pumpUntil(tester, find.text(t.records.rec_added));
    expectNoOverflowErrors(tester);
  });
}
