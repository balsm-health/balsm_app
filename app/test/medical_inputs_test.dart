import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/quick_log.dart';
import 'package:app/balsm_app/widgets/num_pad.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// Every numeric medical entry pad, driven the way a patient does: open the
/// quick-log sheet, pick the metric, tap digits, and see whether Save is live.
/// Boundaries come from `VitalLimits` (modules/self_report); the point here is
/// that the real UI enforces them.
void main() {
  /// Opens [metric]'s pad fresh, taps [digits], and reports whether Save is enabled.
  Future<bool> saveEnabled(WidgetTester tester, String Function(PatientAppState s) metric, List<String> digits) async {
    // Start from an empty tree so the previous case's open sheet is gone.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final s = PatientAppState();
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        child: AppScope(
          state: s,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(child: TextButton(onPressed: () => showQuickLog(context), child: const Text('open'))),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final label = metric(s);
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    for (final d in digits) {
      final key = find.descendant(of: find.byType(NumPad), matching: find.text(d)).first;
      await tester.ensureVisible(key);
      await tester.pump();
      await tester.tap(key);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final save = tester.widget<RoundBtn>(find.widgetWithIcon(RoundBtn, LucideIcons.check));
    return save.onTap != null;
  }

  List<String> d(String n) => n.split('');

  testWidgets('heart rate: 30-220 bpm', (tester) async {
    String m(PatientAppState s) => s.strings.profile.m_pulse;
    for (final ok in ['72', '30', '220']) {
      expect(await saveEnabled(tester, m, d(ok)), isTrue, reason: ok);
    }
    for (final bad in ['5', '29', '221', '999']) {
      expect(await saveEnabled(tester, m, d(bad)), isFalse, reason: bad);
    }
  });

  testWidgets('SpO2: 50-100 %', (tester) async {
    String m(PatientAppState s) => s.strings.profile.m_o2;
    // The pad takes a third digit only to complete 100, so '999' stays '99'.
    for (final ok in ['98', '50', '100', '999']) {
      expect(await saveEnabled(tester, m, d(ok)), isTrue, reason: ok);
    }
    for (final bad in ['10', '49', '101']) {
      expect(await saveEnabled(tester, m, d(bad)), isFalse, reason: bad);
    }
  });

  testWidgets('glucose: 20-600 mg/dL', (tester) async {
    String m(PatientAppState s) => s.strings.profile.m_glucose;
    for (final ok in ['95', '20', '600']) {
      expect(await saveEnabled(tester, m, d(ok)), isTrue, reason: ok);
    }
    for (final bad in ['5', '19', '601', '999']) {
      expect(await saveEnabled(tester, m, d(bad)), isFalse, reason: bad);
    }
  });

  testWidgets('weight: whole kilos from a newborn up, nothing absurd', (tester) async {
    String m(PatientAppState s) => s.strings.profile.m_weight;
    for (final ok in ['3', '72', '500']) {
      expect(await saveEnabled(tester, m, d(ok)), isTrue, reason: ok);
    }
    for (final bad in ['0', '501', '999']) {
      expect(await saveEnabled(tester, m, d(bad)), isFalse, reason: bad);
    }
  });

  testWidgets('blood pressure: systolic above diastolic, both in range', (tester) async {
    String m(PatientAppState s) => s.strings.profile.m_bp;
    // Three digits fill systolic and move to diastolic on their own.
    for (final ok in [
      ['1', '2', '0', '8', '0'],
      ['2', '6', '0', '1', '6', '0'],
    ]) {
      expect(await saveEnabled(tester, m, ok), isTrue, reason: ok.join());
    }
    for (final bad in [
      ['1', '2', '0', '1', '2', '0'], // systolic must exceed diastolic
      ['1', '2', '0', '1', '6', '1'], // diastolic out of range
      ['2', '6', '1', '8', '0'], // systolic out of range
      ['1', '2', '0'], // no diastolic yet
    ]) {
      expect(await saveEnabled(tester, m, bad), isFalse, reason: bad.join());
    }
  });
}
