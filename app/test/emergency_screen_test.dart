import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/profile_subscreens.dart' show EmergencyScreen;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The Emergency numbers screen follows the country the patient is in: Egypt's
/// four lines, another country's national number, or an honest "none on file".
void main() {
  Future<PatientAppState> pump(WidgetTester tester, CountryCode country) async {
    final state = PatientAppState()..country = country;
    await tester.pumpWidget(
      ProviderScope(
        child: AppScope(
          state: state,
          child: MaterialApp(home: Scaffold(body: EmergencyScreen(s: state))),
        ),
      ),
    );
    await tester.pump();
    return state;
  }

  testWidgets('Egypt lists its four services', (tester) async {
    final s = await pump(tester, CountryCode.egypt);
    final e = s.strings.emergency;

    for (final label in [e.em_ambulance, e.em_police, e.em_fire, e.em_tourist]) {
      expect(find.text(label), findsOne);
    }
    for (final number in ['123', '122', '180', '126']) {
      expect(find.text(number), findsOne);
    }
    expect(find.text(e.em_intro('Egypt', s.gender)), findsOne);
  });

  testWidgets("another country shows its own national number, named for that country, never Egypt's", (tester) async {
    final s = await pump(tester, CountryCode.saudi_arabia);
    final e = s.strings.emergency;

    expect(find.text(CountryCode.saudi_arabia.emergencyNumber), findsOne);
    expect(find.text(e.em_national), findsOne);
    expect(find.text('Saudi Arabia'), findsOne);
    expect(find.text(e.em_intro('Saudi Arabia', s.gender)), findsOne);
    for (final egyptOnly in ['122', '180', '126']) {
      expect(find.text(egyptOnly), findsNothing, reason: "$egyptOnly is Egypt's police / fire / tourist line");
    }
    expect(find.text(e.em_police), findsNothing);
  });

  testWidgets('a country with no number on file says so and offers nothing to call', (tester) async {
    // Outside the curated set a country has no emergency number on file.
    final none = CountryCode.fromCode('FR');
    expect(none.emergencyNumber, isEmpty);
    final s = await pump(tester, none);
    final e = s.strings.emergency;

    expect(find.text(e.em_none(none.name(kCatalog, locale: s.lang.value), s.gender)), findsOne);
    expect(find.text(e.em_national), findsNothing);
    expect(find.text(e.em_tap_call(s.gender)), findsNothing);
  });
}
