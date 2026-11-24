import 'package:app/balsm_app/screens/family/profile_bar.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
// The app's TextField is material_ui's, not Flutter's.
import 'package:material_ui/material_ui.dart';
import 'package:patrol/patrol.dart';

import 'demo_kit.dart';

/// Mother & Child, family side: a child and an adult (with the one-time
/// consent), the child's vaccinations and growth, and switching whose
/// profile the app shows.
void main() {
  const child = 'طفلة اختبار';
  const adult = 'أم اختبار';

  /// Home → the profile bar's people picker → Manage family.
  Future<void> openFamily(WidgetTester tester) async {
    await openTab(tester, t.nav.tab_home);
    await tapWhenReady(tester, find.byType(ProfileBar));
    await tapWhenReady(tester, find.text(t.family.manage_family));
  }

  /// Family → Add family member → Enter details manually.
  Future<void> openAddMember(WidgetTester tester) async {
    await tapWhenReady(tester, find.text(t.family.add_member));
    await tapWhenReady(tester, find.text(t.family.manual_t));
    await pumpUntil(tester, find.text(t.family.pick_daughter).hitTestable());
  }

  Future<void> enterName(WidgetTester tester, String name) async {
    final field = find.byWidgetPredicate(
      (w) => w is TextField && {for (final g in Gender.values) t.family.f_name_ph(g)}.contains(w.decoration?.hintText),
    );
    await tester.enterText(field.hitTestable().first, name);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 3);
  }

  /// Adds the child (the date picker opens five years back: a child).
  Future<void> addChild(WidgetTester tester) async {
    await openAddMember(tester);
    await tapWhenReady(tester, find.text(t.family.pick_daughter));
    await enterName(tester, child);
    await scrollToAndTap(tester, find.text(t.family.f_dob_ph));
    await pickDate(tester);
    await scrollToAndTap(tester, find.text('A+'));
    await scrollToAndTap(tester, find.text(t.family.save));
    await pumpUntil(tester, find.text(child).hitTestable());
  }

  patrolTest('Home Family card opens Family; add a child and an adult with consent', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'family');
    await openFamily(tester);
    await pumpUntil(tester, find.text(t.family.empty_t).hitTestable());

    await addChild(tester);

    // An adult: the save button becomes Next, then the consent step.
    await openAddMember(tester);
    await tapWhenReady(tester, find.text(t.family.pick_mother));
    await enterName(tester, adult);
    await scrollToAndTap(tester, find.text(t.family.f_dob_ph));
    await pickDate(tester, year: 1960, day: 1);
    await scrollToAndTap(tester, find.text(t.family.blood_unsure));
    await scrollToAndTap(tester, find.text(t.family.next));

    final add = find.text(t.family.add_cta('أم'));
    await pumpUntil(tester, add.hitTestable());
    // Refused until the box is ticked.
    await tester.tap(add.hitTestable().last);
    await settle(tester, 5);
    expect(
      find.text(t.family.add_cta('أم')).hitTestable(),
      findsWidgets,
      reason: 'consent step must not save unticked',
    );

    await tapWhenReady(
      tester,
      either(find.text(t.family.consent_check_f('أم')), find.text(t.family.consent_check_m('أم'))),
    );
    await tapWhenReady(tester, add);
    await pumpUntil(tester, find.text(adult).hitTestable());
    expectNoOverflowErrors(tester);
  });

  patrolTest('child: vaccination, growth and the invalid-value refusal', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'child');
    await openFamily(tester);
    await addChild(tester);

    // The member's home.
    await tapWhenReady(tester, find.text(child));
    await pumpUntil(tester, find.text(t.vacc.title).hitTestable());
    expect(find.text(t.growth.title), findsWidgets);
    expect(find.text(t.family.tile_card), findsWidgets);

    // Vaccinations → add one.
    await tapWhenReady(tester, find.text(t.vacc.title));
    await tapWhenReady(tester, find.text(t.vacc.add));
    await enterByHint(tester, t.vacc.f_name_ph, 'شلل الأطفال');
    await tapWhenReady(tester, find.text('1'));
    await enterByHint(tester, t.vacc.f_clinic_ph, 'مكتب صحة اختبار');
    await scrollToAndTap(tester, find.text(t.vacc.save));
    await pumpUntil(tester, find.text('شلل الأطفال').hitTestable());
    expectNoOverflowErrors(tester);
    await goBack(tester);

    // Growth: a valid entry, then an impossible weight.
    await tapWhenReady(tester, find.text(t.growth.title));
    Finder fieldLabelled(String label) =>
        find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label);
    await pumpUntil(tester, fieldLabelled(t.growth.weight).hitTestable());
    await tester.enterText(fieldLabelled(t.growth.weight).hitTestable().first, '12.5');
    await tester.enterText(fieldLabelled(t.growth.height).hitTestable().first, '88');
    FocusManager.instance.primaryFocus?.unfocus();
    await scrollToAndTap(tester, find.text(t.growth.add));
    await pumpUntil(tester, find.textContaining('12.5'));

    await tester.enterText(fieldLabelled(t.growth.weight).hitTestable().first, '500');
    FocusManager.instance.primaryFocus?.unfocus();
    await scrollToAndTap(tester, find.text(t.growth.add));
    await pumpUntil(tester, textAnyGender(t.growth.invalid));
    expectNoOverflowErrors(tester);
  });

  patrolTest('people picker: switch to the child and back', ($) async {
    final tester = $.tester;
    await startSignedIn($, tag: 'picker');
    await openFamily(tester);
    await addChild(tester);
    await goBack(tester);

    // Adding the child made her the active profile; Home shows her tiles.
    await openTab(tester, t.nav.tab_home);
    await pumpUntil(tester, find.text(t.family.tile_card).hitTestable());

    await tapWhenReady(tester, find.byType(ProfileBar));
    await pumpUntil(tester, textAnyGender(t.family.picker_title).hitTestable());
    expectNoOverflowErrors(tester);
    await tapWhenReady(tester, textAnyGender(t.family.picker_you));

    // Back on the patient's own Home: the child's tiles are gone.
    await pumpUntil(tester, find.byType(ProfileBar).hitTestable());
    expect(find.text(t.family.tile_card), findsNothing);
    expectNoOverflowErrors(tester);
  });
}
