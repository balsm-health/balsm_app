import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/screens/report_flow.dart';
import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medications/medications.dart';
import 'package:self_report/self_report.dart';

/// The full check-in names the active family member instead of speaking to
/// the account holder; for the account holder it is unchanged.
void main() {
  const adult = FamilyMember(
    id: HealthProfileId.value('hp-adult'),
    kind: ProfileKind.dependent,
    displayName: 'Test Adult',
  );

  Future<PatientAppState> open(WidgetTester tester,
      {FamilyMember? member,
      bool ar = false,
      bool summary = false,
      Gender holder = Gender.other,
      List<CheckInMetric> metrics = const [CheckInMetric.mood],
      List<Medication>? meds}) async {
    final s = PatientAppState()
      ..attachFlags(FeatureFlags(flags: AppFlags.all, allowOverrides: true)..setOverride(AppFlags.motherChild, true));
    if (ar) s.setLang(LanguageCode.ar);
    s.setGender(holder);
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeFamilyMemberProvider.overrideWithValue(member),
        // Mood first, as in the default full check-up.
        trackedCheckInMetricsProvider.overrideWithValue(metrics),
        if (meds != null) medicationListProvider.overrideWith((ref) => Stream.value(meds)),
      ],
      child: AppScope(
        state: s,
        child: MaterialApp(
          home: Directionality(textDirection: s.dir, child: ReportFlow(s: s, debugShowSummary: summary)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return s;
  }

  for (final ar in [false, true]) {
    final lang = ar ? 'AR' : 'EN';
    testWidgets('$lang: a member gets their own mood question and the banner', (tester) async {
      final s = await open(tester, member: adult, ar: ar);
      final c = s.strings.checkin;
      expect(find.text(c.m_q_mood_t('Test')), findsOne);
      expect(find.text(c.m_q_mood_h(s.gender, 'Test')), findsOne);
      expect(find.text(c.q_mood_t(s.gender)), findsNothing);
      expect(find.text('${c.ql_logging_for(s.gender)}Test', findRichText: true), findsOne);
    });

    testWidgets('$lang: a member\'s done screen names them', (tester) async {
      final s = await open(tester, member: adult, ar: ar, summary: true);
      expect(find.text(s.strings.checkin.m_saved_t('Test')), findsOne);
      expect(find.text(s.strings.common.saved_t), findsNothing);
    });

    testWidgets('$lang: the account holder is still addressed as "you"', (tester) async {
      final s = await open(tester, ar: ar);
      final c = s.strings.checkin;
      expect(find.text(c.q_mood_t(s.gender)), findsOne);
      expect(find.text('${c.ql_logging_for(s.gender)}Test', findRichText: true), findsNothing);
    });

    testWidgets('$lang: the account holder\'s done screen is unchanged', (tester) async {
      final s = await open(tester, ar: ar, summary: true);
      expect(find.text(s.strings.common.saved_t), findsOne);
    });
  }

  // Mood words describe the person being logged for: a member's own sex,
  // never the account holder's gender.
  FamilyMember withSex(Sex? sex) => FamilyMember(
        id: const HealthProfileId.value('hp-adult'),
        kind: ProfileKind.dependent,
        displayName: 'Test Adult',
        sex: sex,
      );
  for (final (sex, want, holder) in [
    (Sex.female, ['متعبة', 'ضعيفة', 'عادية', 'جيدة', 'ممتازة'], Gender.male),
    (Sex.male, ['متعب', 'ضعيف', 'عادي', 'جيد', 'ممتاز'], Gender.female),
    (null, ['متعب', 'ضعيف', 'عادي', 'جيد', 'ممتاز'], Gender.female),
  ]) {
    testWidgets('AR: member with sex $sex gets their own mood words (holder $holder)', (tester) async {
      await open(tester, member: withSex(sex), ar: true, holder: holder);
      for (final w in want) {
        expect(find.text(w), findsOne, reason: w);
      }
    });
  }

  for (final (holder, want) in [(Gender.female, 'متعبة'), (Gender.male, 'متعب')]) {
    testWidgets('AR: the account holder ($holder) keeps their own mood words', (tester) async {
      await open(tester, ar: true, holder: holder);
      expect(find.text(want), findsOne);
    });
  }

  for (final (holder, want) in [(Gender.female, 'هل أخذتِ أدويتك؟'), (Gender.male, 'هل أخذت أدويتك؟')]) {
    testWidgets('AR: the medicines question follows the account holder ($holder)', (tester) async {
      await open(tester, ar: true, holder: holder, metrics: const [], meds: [
        Medication(
          id: const MedicationId.value('med-a'),
          userId: const UserId.value('u1'),
          name: 'Testamol',
          scheduleType: ScheduleType.daily,
          scheduleConfig: const ScheduleConfig(times: ['08:00']),
          startDate: DateTime(2026, 1, 1),
        ),
      ]);
      expect(find.text(want), findsOne);
    });
  }

  test('member copy, word for word', () {
    final s = PatientAppState();
    expect(s.strings.checkin.m_q_mood_t('Sara'), 'How is Sara feeling today?');
    s.setLang(LanguageCode.ar);
    final c = s.strings.checkin;
    expect(c.m_q_mood_t('سارة'), 'كيف حال سارة اليوم؟');
    expect(c.m_q_mood_h(Gender.female, 'سارة'), 'اختاري الوجه الأقرب لحال سارة.');
    expect(c.m_q_mood_h(Gender.male, 'سارة'), 'اختر الوجه الأقرب لحال سارة.');
    expect(c.m_saved_t('سارة'), 'تم حفظ متابعة سارة');
    expect(c.q_med_t(Gender.female), 'هل أخذتِ أدويتك؟');
    expect(c.q_med_t(Gender.male), 'هل أخذت أدويتك؟');
    expect(c.q_med_t(Gender.other), 'هل أخذت أدويتك؟');
  });
}
