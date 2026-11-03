import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/help_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Profile › Help & support (help.jsx HelpSupportScreen).
void main() {
  Future<PatientAppState> pump(WidgetTester tester) async {
    final state = PatientAppState();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      child: AppScope(state: state, child: MaterialApp(home: HelpSupportScreen(s: state))),
    ));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('names the account country’s ambulance number', (tester) async {
    final s = await pump(tester);

    final number = s.country.emergencyNumber;
    if (number.isEmpty) {
      expect(find.text(s.strings.help.hp_emergency_local(s.gender)), findsOne);
    } else {
      expect(find.text(number, findRichText: true), findsOne);
    }
  });

  testWidgets('opens one question at a time', (tester) async {
    final s = await pump(tester);
    final h = s.strings.help;
    expect(find.text(h.hp_a_data), findsNothing);

    await tester.tap(find.text(h.hp_q_data));
    await tester.pumpAndSettle();
    expect(find.text(h.hp_a_data), findsOne);

    await tester.tap(find.text(h.hp_q_offline));
    await tester.pumpAndSettle();
    expect(find.text(h.hp_a_data), findsNothing);
    expect(find.text(h.hp_a_offline), findsOne);
  });
}
