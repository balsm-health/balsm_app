import 'dart:async';

import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/meds_screen.dart';
import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medications/medications.dart';
import 'package:prescriptions/prescriptions.dart';

import 'support/flag_overrides.dart';

/// `home.jsx` MedsScreen — a medication is deleted from its dose row's ⋮
/// menu, by swiping the row, or with Select; each asks first.
///
/// The medications are invented by the test; nothing here is real patient data.
class _Recorder implements DeleteMedicationUseCase {
  final deleted = <MedicationId>[];

  @override
  MedicationsDataSource get dao => throw UnimplementedError();

  @override
  Future<void> call(MedicationId id) async => deleted.add(id);
}

class _EditRecorder implements EditMedicationUseCase {
  final edited = <Medication>[];

  @override
  MedicationsDataSource get dao => throw UnimplementedError();

  @override
  Future<void> call(Medication medication) async => edited.add(medication);
}

void main() {
  const user = UserId.value('usr-1');
  Medication med(String id, String name) => Medication(
        id: MedicationId.value(id),
        userId: user,
        name: name,
        scheduleType: ScheduleType.daily,
        scheduleConfig: const ScheduleConfig(times: ['08:00', '20:00']),
        startDate: DateTime(2026),
      );
  final alpha = med('med-a', 'Testamol');
  final beta = med('med-b', 'Placebex');
  final today = DateTime.now();
  final doses = [
    TodayDose(medication: alpha, scheduledAt: DateTime(today.year, today.month, today.day, 8)),
    TodayDose(medication: beta, scheduledAt: DateTime(today.year, today.month, today.day, 9)),
    TodayDose(medication: alpha, scheduledAt: DateTime(today.year, today.month, today.day, 20)),
  ];

  late _EditRecorder editor;

  Future<(_Recorder, PatientAppState)> pump(
    WidgetTester tester, {
    bool ar = false,
    FamilyMember? member,
    List<Medication>? meds,
  }) async {
    final recorder = _Recorder();
    editor = _EditRecorder();
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    if (member != null) {
      state.attachFlags(
        flagsWith({AppFlags.motherChild: true}),
      );
    }
    final list = meds ?? [alpha, beta];
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        retry: noProviderRetry,
        overrides: [
          currentUserIdProvider.overrideWithValue(user),
          todayDosesProvider.overrideWith((ref) async => meds == null ? doses : const <TodayDose>[]),
          medicationListProvider.overrideWith((ref) => Stream.value(list)),
          if (member != null) ...[
            familyMembersProvider.overrideWith((ref) => Stream.value([member])),
            activeFamilyMemberProvider.overrideWithValue(member),
          ],
          prescriptionListProvider.overrideWith((ref) => Stream.value(const <Prescription>[])),
          weekAdherenceProvider.overrideWith((ref) async => const WeekAdherence(scheduled: 0, taken: 0)),
          deleteMedicationUseCaseProvider(user).overrideWithValue(recorder),
          editMedicationUseCaseProvider(user).overrideWithValue(editor),
        ],
        child: AppScope(
          state: state,
          child: MaterialApp(
            builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
            home: const Scaffold(body: MedsScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (recorder, state);
  }

  Future<void> confirm(WidgetTester tester, PatientAppState s) async {
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text(s.strings.common.del)));
    await tester.pumpAndSettle();
  }

  testWidgets('the ⋮ menu asks, then ends the medication', (tester) async {
    final (recorder, s) = await pump(tester);
    await tester.tap(
      find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == s.strings.common.del_options('Placebex')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.common.del));
    await tester.pumpAndSettle();

    expect(find.text(s.strings.common.del_title('Placebex')), findsOne);
    expect(find.text(s.strings.meds.med_del_body_one), findsOne);
    await confirm(tester, s);

    expect(recorder.deleted, [beta.id]);
    expect(find.text(s.strings.common.del_done('Placebex')), findsOne);
  });

  testWidgets('Cancel ends nothing', (tester) async {
    final (recorder, s) = await pump(tester);
    await tester.drag(find.text('Placebex'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();
    expect(recorder.deleted, isEmpty);
  });

  testWidgets('Select all ends each medication once, though Testamol has two doses', (tester) async {
    final (recorder, s) = await pump(tester);
    final c = s.strings.common;
    await tester.tap(find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == c.del_select));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.del_select_all));
    await tester.pumpAndSettle();
    expect(find.text(c.del_selected(2)), findsOne);

    await tester.tap(find.text(c.del_n(s.strings.meds.med_count(2))));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.meds.med_del_body_n), findsOne);
    await confirm(tester, s);

    expect(recorder.deleted, [alpha.id, beta.id]);
  });

  testWidgets('in Arabic the row swipes the other way and counts in Arabic', (tester) async {
    final (recorder, s) = await pump(tester, ar: true);
    expect(s.strings.meds.med_count(5), '5 أدوية');
    expect(s.strings.meds.med_count(11), '11 دواءً');
    await tester.drag(find.text('Testamol').first, const Offset(300, 0));
    await tester.pumpAndSettle();
    await confirm(tester, s);
    expect(recorder.deleted, [alpha.id]);
  });

  testWidgets('Edit medication: from the dose sheet, prefilled, saved under the same id', (tester) async {
    final (_, s) = await pump(tester);
    final m = s.strings.meds;
    expect(find.text(m.med_edit_hint(s.gender)), findsOne);

    await tester.tap(find.text('Placebex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(m.med_edit_title));
    await tester.pumpAndSettle();

    expect(find.text(m.med_edit_title), findsOne, reason: 'the sheet title');
    final name = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == 'Placebex');
    expect(name, findsOne);
    await tester.enterText(name, 'Renamedol');
    await tester.pump();
    await tester.tap(find.text(m.med_save_changes));
    await tester.pump();
    expect(find.text(m.med_changes_saved), findsOne);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(editor.edited, hasLength(1));
    expect(editor.edited.single.id, beta.id);
    expect(editor.edited.single.name, 'Renamedol');
    expect(editor.edited.single.scheduleConfig.times, beta.scheduleConfig.times, reason: 'schedule left alone');
  });

  group('a family member is the active profile (home-base-mc.jsx MedsScreen member)', () {
    const kid = FamilyMember(
      id: HealthProfileId.value('hp-kid'),
      kind: ProfileKind.dependent,
      displayName: 'Test Kid',
    );

    testWidgets('names them, hides the adherence and prescriptions cards, and offers to add', (tester) async {
      final (_, s) = await pump(tester, member: kid, meds: const []);
      final m = s.strings.meds;
      expect(find.text(m.regimen_of('Test')), findsOne);
      expect(find.text(m.regimen), findsNothing);
      expect(find.text(m.adherence), findsNothing);
      expect(find.text(s.strings.records.prescriptions), findsNothing);
      expect(find.text(m.member_meds_empty('Test')), findsOne);
      expect(find.text(m.member_meds_empty_h(s.gender, 'Test')), findsOne);
      expect(find.text(m.med_add_title), findsOne);
    });

    testWidgets('in Arabic, the copy addresses the patient by gender', (tester) async {
      final (_, s) = await pump(tester, ar: true, member: kid, meds: const []);
      expect(find.text('لا أدوية لـTest بعد'), findsOne);
      expect(s.strings.meds.member_meds_empty_h(Gender.female, 'Test'), startsWith('أضيفي'));
      expect(s.strings.meds.member_meds_empty_h(Gender.male, 'Test'), startsWith('أضف '));
    });

    testWidgets('once they have medicines, the list shows instead of the empty state', (tester) async {
      final (_, s) = await pump(tester, member: kid);
      expect(find.text(s.strings.meds.member_meds_empty('Test')), findsNothing);
      expect(find.text('Testamol'), findsWidgets);
    });
  });
}
