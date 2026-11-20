import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart';
import 'package:app/balsm_app/screens/day_records_screen.dart';
import 'package:app/balsm_app/vault/memory_file_store.dart';
import 'package:app/balsm_app/widgets/entry_attribution.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';
import 'package:self_report/self_report.dart';

/// `mother-child.jsx` MCBy / MCByHistory: an entry someone else added, edited
/// or shared shows a chip that opens its edit history; the patient's own shows
/// nothing. Every person and value here is invented by the test.
void main() {
  final family = ProvenanceActor.other(ProvenanceActorKind.family, displayName: 'Member A');
  final added = ProvenanceEvent(id: 'e1', actor: family, action: ProvenanceAction.added, at: DateTime(2026, 1, 1, 9));
  final selfEdit = ProvenanceEvent(
      id: 'e2', actor: ProvenanceActor.self, action: ProvenanceAction.edited, at: DateTime(2026, 2, 3, 9));

  Future<PatientAppState> pump(WidgetTester tester, Widget child,
      {List<CareProvider> team = const [], LanguageCode lang = LanguageCode.en, Gender gender = Gender.other}) async {
    final state = PatientAppState()
      ..setLang(lang)
      ..setGender(gender);
    await tester.pumpWidget(ProviderScope(
      overrides: [careTeamProvider.overrideWith((ref) => Stream.value(team))],
      child: AppScope(
        state: state,
        child: MaterialApp(
          builder: (_, c) => Directionality(textDirection: state.dir, child: c!),
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(EntryAttributionChip));
    await tester.pumpAndSettle();
  }

  testWidgets('the patient\'s own entry shows nothing', (tester) async {
    await pump(tester, const EntryAttributionChip(history: EntryHistory.none));
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('an entry a family member added shows their name and opens its history', (tester) async {
    final s = await pump(tester, EntryAttributionChip(history: EntryHistory([added])));
    expect(find.text('Member A'), findsOne);
    expect(find.byIcon(LucideIcons.plus), findsOne);
    expect(find.bySemanticsLabel(RegExp('^Edit history: By Member A')), findsOne);

    await openSheet(tester);
    expect(find.text(s.strings.attribution.history_title), findsOne);
    expect(find.text('Member A added this'), findsOne);
    expect(find.text('Family · 1 January 2026'), findsOne);
    expect(find.text('Balsm keeps this history and it can’t be changed.'), findsOne);
  });

  testWidgets('the patient\'s own edit is listed newest first and marks the chip edited', (tester) async {
    await pump(tester, EntryAttributionChip(history: EntryHistory([added, selfEdit])));
    expect(find.text('Member A'), findsOne, reason: 'still shown as coming from the family member');
    expect(find.byIcon(LucideIcons.pencil), findsOne);

    await openSheet(tester);
    final you = tester.getTopLeft(find.text('You edited this'));
    final them = tester.getTopLeft(find.text('Member A added this'));
    expect(you.dy, lessThan(them.dy));
    expect(find.text('3 February 2026'), findsOne, reason: 'no role line for the patient');
  });

  testWidgets('a doctor known by a care-team reference is shown by their care-team name', (tester) async {
    final doctor = ProvenanceActor.other(ProvenanceActorKind.doctor, careProviderId: 'cp-1');
    final shared = ProvenanceEvent(id: 'e3', actor: doctor, action: ProvenanceAction.shared, at: DateTime(2026, 3, 4));
    await pump(
      tester,
      EntryAttributionChip(history: EntryHistory([shared])),
      team: [
        CareProvider(
          id: const CareProviderId.value('cp-1'),
          healthProfileId: const HealthProfileId.value('hp-1'),
          type: CareProviderType.doctor,
          name: 'Provider One',
          createdAt: DateTime(2026),
        ),
      ],
    );
    expect(find.text('Provider One'), findsOne);
    expect(find.byIcon(LucideIcons.share2), findsOne);
    await openSheet(tester);
    expect(find.text('Provider One shared this'), findsOne);
    expect(find.text('Doctor · 4 March 2026'), findsOne);
  });

  testWidgets('a care-team reference that is gone reads "Someone else"', (tester) async {
    final clinic = ProvenanceActor.other(ProvenanceActorKind.clinic, careProviderId: 'gone');
    await pump(
        tester,
        EntryAttributionChip(
            history: EntryHistory(
                [ProvenanceEvent(id: 'e4', actor: clinic, action: ProvenanceAction.added, at: DateTime(2026))])));
    expect(find.text('Someone else'), findsOne);
  });

  testWidgets('Arabic addresses the patient\'s own edit in their gender', (tester) async {
    await pump(tester, EntryAttributionChip(history: EntryHistory([added, selfEdit])),
        lang: LanguageCode.ar, gender: Gender.female);
    await openSheet(tester);
    expect(find.text('عدّلتِه أنت'), findsOne);
    expect(find.text('أضافه Member A'), findsOne);
  });

  testWidgets('a reading someone else logged carries the chip on the day screen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    CheckIn reading(String id, EntryHistory history) => CheckIn(
          id: CheckInId.value(id),
          healthProfileId: const HealthProfileId.value('hp-1'),
          recordedAt: DateTime.utc(2026, 7, 24, 9),
          painLevel: PainLevel.none,
          painSites: const {},
          symptoms: const {},
          vitals: const Vitals(systolic: 118, diastolic: 76),
          history: history,
        );
    final state = PatientAppState();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        userFileStoreProvider.overrideWithValue(MemoryUserFileStore()),
      ],
      child: AppScope(
        state: state,
        child: MaterialApp(
          home: DayRecordsScreen(checkIns: [
            reading('own', EntryHistory.none),
            reading('theirs', EntryHistory([added]))
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(EntryAttributionChip), findsOne, reason: 'only the reading someone else logged');
    expect(find.text('Member A'), findsOne);
  });
}
