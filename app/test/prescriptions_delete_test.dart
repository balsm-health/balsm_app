import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/prescriptions_screen.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:prescriptions/prescriptions.dart';

/// `prescriptions.jsx` PrescriptionsScreen — the patient's own prescriptions
/// delete by swipe, ⋮ or Select, and from the detail page; clinic-issued ones
/// offer none of these ([DeletePrescriptionUseCase] policy).
///
/// The prescriptions are invented by the test; nothing here is real patient data.
class _Recorder implements DeletePrescriptionUseCase {
  final deleted = <PrescriptionId>[];

  @override
  Future<void> call(Prescription rx) async => deleted.add(rx.id);
}

void main() {
  const user = UserId.value('usr-1');
  final issued = DateTime(2026, 7, 1);
  final mine = Prescription(
    id: const PrescriptionId.value('rx-self'),
    userId: user,
    clinician: 'Me',
    title: 'Allergy script',
    source: 'self',
    issuedAt: issued,
    createdAt: issued,
  );
  final clinic = Prescription(
    id: const PrescriptionId.value('rx-clinic'),
    userId: user,
    clinician: 'Dr Example',
    reference: 'REF-0001',
    source: 'clinic',
    issuedAt: issued,
    createdAt: issued,
  );

  Future<(_Recorder, PatientAppState)> pump(WidgetTester tester) async {
    final recorder = _Recorder();
    final state = PatientAppState();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        prescriptionListProvider.overrideWith((ref) => Stream.value([clinic, mine])),
        deletePrescriptionUseCaseProvider.overrideWithValue(recorder),
      ],
      child: AppScope(
        state: state,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
          home: const Scaffold(body: PrescriptionsScreen()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (recorder, state);
  }

  Finder more(PatientAppState s, String label) =>
      find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == s.strings.common.del_options(label));

  Future<void> confirm(WidgetTester tester, PatientAppState s) async {
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text(s.strings.common.del)));
    await tester.pumpAndSettle();
  }

  testWidgets('only the patient\'s own prescription has a ⋮', (tester) async {
    final (_, s) = await pump(tester);
    expect(more(s, 'Allergy script'), findsOne);
    expect(more(s, 'Dr Example'), findsNothing);
  });

  testWidgets('the ⋮ menu asks, then deletes', (tester) async {
    final (recorder, s) = await pump(tester);
    await tester.tap(more(s, 'Allergy script'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.common.del));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.meds.rx_del_body_one), findsOne);
    await confirm(tester, s);

    expect(recorder.deleted, [mine.id]);
    expect(find.text(s.strings.common.del_done('Allergy script')), findsOne);
  });

  testWidgets('a clinic prescription does not swipe', (tester) async {
    final (recorder, s) = await pump(tester);
    await tester.drag(find.text('Dr Example'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(recorder.deleted, isEmpty);
  });

  testWidgets('Select all ticks only the patient\'s own', (tester) async {
    final (recorder, s) = await pump(tester);
    final c = s.strings.common;
    await tester.tap(find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == c.del_select));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.del_select_all));
    await tester.pumpAndSettle();
    expect(find.text(c.del_selected(1)), findsOne);
    await tester.tap(find.text(c.del_n(s.strings.meds.rx_count(1))));
    await tester.pumpAndSettle();
    await confirm(tester, s);
    expect(recorder.deleted, [mine.id]);
  });

  testWidgets('the detail page\'s bin asks, deletes and returns', (tester) async {
    final (recorder, s) = await pump(tester);
    await tester.tap(find.text('Allergy script'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == s.strings.common.a11y_delete));
    await tester.pumpAndSettle();
    await confirm(tester, s);

    expect(recorder.deleted, [mine.id]);
    expect(find.byType(PrescriptionDetailScreen), findsNothing);
    expect(find.text(s.strings.common.del_done('Allergy script')), findsOne);
  });
}
