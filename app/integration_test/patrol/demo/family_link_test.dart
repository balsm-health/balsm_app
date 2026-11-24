import 'package:app/balsm_app/screens/family/profile_bar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'demo_kit.dart';

/// Family link by QR, as far as one phone allows: the scan screen opens with
/// the camera, and its manual fallback leads to the manual form. Completing
/// a link needs a second phone showing the other account's QR code.
void main() {
  patrolTest('scan their QR code: camera screen and manual fallback', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'link');
    await openTab(tester, t.nav.tab_home);
    await tapWhenReady(tester, find.byType(ProfileBar));
    await tapWhenReady(tester, find.text(t.family.manage_family));

    await tapWhenReady(tester, find.text(t.family.add_member));
    await tapWhenReady(tester, find.text(t.family.scan_t));
    await grantPermissionIfAsked($);
    await pumpUntil(tester, find.text(t.common.fam_scan_title).hitTestable());
    expectNoOverflowErrors(tester);

    await tapWhenReady(tester, find.text(t.common.fam_manual_instead));
    await pumpUntil(tester, find.text(t.family.pick_daughter).hitTestable());
    expectNoOverflowErrors(tester);
  });
}
