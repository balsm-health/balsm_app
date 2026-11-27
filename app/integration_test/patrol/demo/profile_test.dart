import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
// The app's TextField is material_ui's, not Flutter's.
import 'package:material_ui/material_ui.dart';
import 'package:patrol/patrol.dart';

import 'demo_kit.dart';

/// The patient's own profile: the medical profile behind the emergency card,
/// the emergency QR code, every Profile row, and the Nearby map.
void main() {
  patrolTest('medical profile: blood type and an allergy', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'medical');

    await openTab(tester, t.nav.tab_profile);
    await scrollToAndTap(tester, find.text(t.profile.p_cond));
    await scrollToAndTap(tester, find.text('O+'));

    final allergy = find.byWidgetPredicate(
      (w) =>
          w is TextField && {for (final g in Gender.values) t.profile.pd_add_alg(g)}.contains(w.decoration?.hintText),
    );
    await scrollTo(tester, allergy);
    await tester.enterText(allergy.hitTestable().first, 'بنسلين');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, 5);
    await pumpUntil(tester, find.text('بنسلين').hitTestable());

    await scrollToAndTap(tester, find.text(t.profile.pd_save));
    await pumpUntil(tester, find.text(t.profile.pd_saved));
    expectNoOverflowErrors(tester);
  });

  patrolTest('emergency QR: generate the code', ($) async {
    final tester = $.tester;
    // The code is refused until a date of birth is saved: startSignedIn
    // fills the profile first.
    await startSignedIn($, tag: 'qr');

    await openTab(tester, t.nav.tab_profile);
    await tapWhenReady(tester, find.bySemanticsLabel(t.common.a11y_qr));
    await tapWhenReady(tester, find.text(t.emergency.eqr_generate), timeout: const Duration(seconds: 60));
    // Once minted, the sheet offers copy / save / share.
    await pumpUntil(tester, find.text(t.emergency.eqr_copy).hitTestable(), timeout: const Duration(seconds: 60));
    expectNoOverflowErrors(tester);
  });

  patrolTest('every Profile row opens and comes back', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'rows');
    await openTab(tester, t.nav.tab_profile);

    for (final row in [
      t.profile.p_personal,
      t.profile.p_cond,
      t.profile.p_care,
      t.profile.p_emergency,
      t.profile.p_privacy,
    ]) {
      await scrollToAndTap(tester, find.text(row));
      await settle(tester);
      expectNoOverflowErrors(tester);
      await goBack(tester);
      await pumpUntil(tester, find.text(t.nav.tab_profile).hitTestable());
    }

    // Language opens a sheet; Arabic stays chosen.
    await scrollToAndTap(tester, find.text(t.profile.p_lang));
    await pumpUntil(tester, textAnyGender(t.settings.choose_lang));
    expectNoOverflowErrors(tester);
  });

  patrolTest('Nearby: the map opens with its search', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'nearby', withProfile: false);

    await openTab(tester, t.nav.tab_map);
    await grantPermissionIfAsked($);
    final search = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == t.care.map_search_ph);
    await pumpUntil(tester, search, timeout: const Duration(seconds: 60));
    await settle(tester, 30);
    expectNoOverflowErrors(tester);
  });
}
