import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/screens/report_flow.dart';
import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
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
      {FamilyMember? member, bool ar = false, bool summary = false}) async {
    final s = PatientAppState()
      ..attachFlags(FeatureFlags(flags: AppFlags.all, allowOverrides: true)..setOverride(AppFlags.motherChild, true));
    if (ar) s.setLang(LanguageCode.ar);
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        activeFamilyMemberProvider.overrideWithValue(member),
        // Mood first, as in the default full check-up.
        trackedCheckInMetricsProvider.overrideWithValue(const [CheckInMetric.mood]),
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

  test('member copy, word for word', () {
    final s = PatientAppState();
    expect(s.strings.checkin.m_q_mood_t('Sara'), 'How is Sara feeling today?');
    s.setLang(LanguageCode.ar);
    final c = s.strings.checkin;
    expect(c.m_q_mood_t('سارة'), 'كيف حال سارة اليوم؟');
    expect(c.m_q_mood_h(Gender.female, 'سارة'), 'اختاري الوجه الأقرب لحال سارة.');
    expect(c.m_q_mood_h(Gender.male, 'سارة'), 'اختر الوجه الأقرب لحال سارة.');
    expect(c.m_saved_t('سارة'), 'تم حفظ متابعة سارة');
  });
}
