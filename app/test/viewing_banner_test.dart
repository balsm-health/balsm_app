import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// `UX Enhancement Screens.html` — "Household · active-account accent".
///
/// `selectFamilyMember` is a session-only visual switch: it does NOT re-point
/// the health profile. The home screen used to rename its greeting to the
/// selected member anyway, which told the patient someone else's readings were
/// on screen while the data below stayed their own. These pin the truthful
/// behaviour.
void main() {
  Future<PatientAppState> pump(WidgetTester tester, {bool selectMember = false}) async {
    final state = PatientAppState();
    state.addFamilyMember(name: 'Karim Hassan', relation: 'Father');
    if (selectMember) {
      state.selectFamilyMember(state.extraFamily.first.id);
    }
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      child: AppScope(
        state: state,
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    ));
    await tester.pump();
    return state;
  }

  testWidgets('no banner while viewing your own record', (tester) async {
    final s = await pump(tester);
    expect(find.text(s.strings.home.viewing_member('Karim Hassan')), findsNothing);
    expect(find.text(s.strings.home.viewing_own_data), findsNothing);
  });

  testWidgets('selecting a member says plainly whose record is on screen', (tester) async {
    final s = await pump(tester, selectMember: true);
    expect(find.text(s.strings.home.viewing_member('Karim Hassan')), findsOne);
    expect(find.text(s.strings.home.viewing_own_data), findsOne);
  });

  testWidgets('the greeting never renames to the selected member', (tester) async {
    await pump(tester, selectMember: true);
    // The readings below belong to the signed-in patient, so the greeting must
    // not claim to be Karim's.
    expect(find.text('Karim'), findsNothing);
  });

  testWidgets('switch back clears the selection', (tester) async {
    final s = await pump(tester, selectMember: true);
    expect(s.activeFamilyId, isNotNull);

    await tester.tap(find.text(s.strings.home.viewing_switch_back));
    await tester.pump();
    expect(s.activeFamilyId, isNull);
  });
}
