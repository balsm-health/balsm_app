import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart';
import 'package:app/balsm_app/widgets/attachment_thumb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';

/// Care team screen (`home.jsx` CareTeamScreen): search, provider-type chips,
/// and the two different empty states.
///
/// Every provider here is invented by the test, not by the app — the screen
/// itself never seeds a roster, which is the point of the first case.
void main() {
  CareProvider provider(
    String name, {
    CareProviderType type = CareProviderType.doctor,
    String? specialty,
    String? phone,
    String? email,
    String? clinic,
  }) =>
      CareProvider(
        id: CareProviderId.value('cp-$name'),
        healthProfileId: const HealthProfileId.value('hp-1'),
        type: type,
        name: name,
        specialty: specialty,
        phone: phone,
        email: email,
        clinic: clinic,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  Future<PatientAppState> pump(WidgetTester tester, List<CareProvider> team) async {
    final state = PatientAppState();
    await tester.pumpWidget(ProviderScope(
      overrides: [careTeamProvider.overrideWith((ref) => Stream.value(team))],
      child: AppScope(
        state: state,
        child: const MaterialApp(home: CareTeamScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('an empty care team invites the first entry, with no search', (tester) async {
    final s = await pump(tester, const []);
    expect(find.text(s.strings.care.care_empty), findsOne);
    expect(find.text(s.strings.care.care_add_help), findsOne);
    // Nothing to search or filter yet.
    expect(find.byType(TextField), findsNothing);
    expect(find.text(s.strings.care.care_all), findsNothing);
    // The way in is always offered — as the FAB now, not a dashed row.
    expect(find.bySemanticsLabel(s.strings.care.care_add), findsOne);
  });

  testWidgets('one provider type needs no filter row', (tester) async {
    final s = await pump(tester, [provider('Dr. A'), provider('Dr. B')]);
    expect(find.byType(TextField), findsOne, reason: 'search shows as soon as there is a team');
    expect(find.text(s.strings.care.care_all), findsNothing);
  });

  testWidgets('two provider types bring out the chips', (tester) async {
    final s = await pump(tester, [provider('Dr. A'), provider('Alfa', type: CareProviderType.lab)]);
    expect(find.text(s.strings.care.care_all), findsOne);
    expect(find.text(s.strings.care.care_t_lab), findsExactly(2), reason: 'the chip and the card badge');
  });

  testWidgets('a chip filters the list to its type', (tester) async {
    final s = await pump(tester, [
      provider('Dr. Ahmed'),
      provider('Corner pharmacy', type: CareProviderType.pharmacy),
    ]);
    expect(find.text('Dr. Ahmed'), findsOne);

    await tester.tap(find.text(s.strings.care.care_t_pharmacy).first);
    await tester.pumpAndSettle();
    expect(find.text('Dr. Ahmed'), findsNothing);
    expect(find.text('Corner pharmacy'), findsOne);
  });

  testWidgets('search matches the specialty and the type name, not just the name', (tester) async {
    await pump(tester, [
      provider('Dr. Ahmed', specialty: 'Cardiology'),
      provider('Alfa', type: CareProviderType.lab),
    ]);

    await tester.enterText(find.byType(TextField), 'cardio');
    await tester.pumpAndSettle();
    expect(find.text('Dr. Ahmed'), findsOne);
    expect(find.text('Alfa'), findsNothing);

    // "lab" is nowhere in the row's own text — it is the type's label.
    await tester.enterText(find.byType(TextField), 'lab');
    await tester.pumpAndSettle();
    expect(find.text('Alfa'), findsOne);
    expect(find.text('Dr. Ahmed'), findsNothing);
  });

  testWidgets('a search with no hits says so instead of showing the empty team', (tester) async {
    final s = await pump(tester, [provider('Dr. Ahmed')]);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(s.strings.care.care_no_match), findsOne);
    expect(find.text(s.strings.care.care_no_match_h), findsOne);
    // The team is not empty, so the "add your first" card must not appear.
    expect(find.text(s.strings.care.care_empty), findsNothing);
  });

  testWidgets('the card shows only the lines the patient filled in', (tester) async {
    await pump(tester, [provider('Dr. Ahmed', clinic: 'Balsm Centre', phone: '0100000000')]);
    expect(find.text('Balsm Centre'), findsOne);
    expect(find.text('0100000000'), findsOne);
    // No email was entered, so no mail row.
    expect(find.byIcon(LucideIcons.mail), findsNothing);
    expect(find.byIcon(LucideIcons.mapPin), findsOne);
  });

  testWidgets('Call appears when there is a number to dial', (tester) async {
    final s = await pump(tester, [provider('Dr. Ahmed', phone: '0100000000')]);
    expect(find.text(s.strings.care.care_call), findsOne);
  });

  testWidgets('a provider with no number gets no dead Call button', (tester) async {
    final s = await pump(tester, [provider('Dr. Ahmed')]);
    expect(find.text(s.strings.care.care_call), findsNothing);
  });

  group('add-provider sheet', () {
    Future<PatientAppState> pumpSheet(WidgetTester tester) async {
      final state = PatientAppState();
      await tester.pumpWidget(ProviderScope(
        child: AppScope(
          state: state,
          child: const MaterialApp(home: Scaffold(body: AddCareProviderSheet())),
        ),
      ));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('offers every provider type', (tester) async {
      final s = await pumpSheet(tester);
      for (final t in CareProviderType.values) {
        expect(find.text(careTypeLabel(s.strings.care, t)), findsOne);
      }
    });

    testWidgets('a person is asked for a specialty and a clinic', (tester) async {
      final s = await pumpSheet(tester);
      final c = s.strings.care;
      // Doctor is the default selection.
      expect(find.text(c.care_f_specialty), findsOne);
      expect(find.text(c.care_f_clinic), findsOne);
      expect(find.text(c.care_f_services), findsNothing);
      expect(find.text(c.care_f_branch), findsNothing);
    });

    testWidgets('a place relabels those fields to services and branch', (tester) async {
      final s = await pumpSheet(tester);
      final c = s.strings.care;
      await tester.tap(find.text(c.care_t_pharmacy));
      await tester.pumpAndSettle();
      expect(find.text(c.care_f_services), findsOne);
      expect(find.text(c.care_f_branch), findsOne);
      expect(find.text(c.care_f_specialty), findsNothing);
      expect(find.text(c.care_f_clinic), findsNothing);
    });

    testWidgets('saving stays disabled until a name is typed', (tester) async {
      final s = await pumpSheet(tester);
      PButton save() => tester.widget<PButton>(find.widgetWithText(PButton, s.strings.care.care_save));
      expect(save().onTap, isNull, reason: 'the name is the one required field');

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pumpAndSettle();
      expect(save().onTap, isNull, reason: 'whitespace is not a name');

      await tester.enterText(find.byType(TextField).first, 'Dr. Ahmed');
      await tester.pumpAndSettle();
      expect(save().onTap, isNotNull);
    });
  });

  group('provider file drawer', () {
    Future<PatientAppState> pumpWithFiles(
      WidgetTester tester,
      List<CareProvider> team, {
      List<String> files = const [],
    }) async {
      final state = PatientAppState();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          careTeamProvider.overrideWith((ref) => Stream.value(team)),
          careProviderFilesProvider.overrideWith((ref, id) => Stream.value(files)),
        ],
        child: AppScope(
          state: state,
          child: const MaterialApp(home: CareTeamScreen()),
        ),
      ));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('every provider offers the files action, phone or not', (tester) async {
      final s = await pumpWithFiles(tester, [provider('Dr. Ahmed')]);
      expect(find.text(s.strings.care.care_attach_file), findsOne);
      expect(find.text(s.strings.care.care_call), findsNothing);
    });

    testWidgets('with nothing attached there is no drawer to open', (tester) async {
      final s = await pumpWithFiles(tester, [provider('Dr. Ahmed')]);
      // Not tapped on purpose: with no files the button goes straight to the
      // system picker, which has no binding in a widget test. The label split
      // below is what distinguishes the two routes; the drawer-opening path is
      // covered by 'managing opens the gallery' with files present.
      expect(find.text(s.strings.care.care_attach_file), findsOne);
      expect(find.text(s.strings.care.care_manage_files), findsNothing);
      expect(find.text(s.strings.care.care_files_head), findsNothing);
      expect(find.byType(VaultAttachmentGallery), findsNothing);
    });

    testWidgets('with files attached the button offers to manage them', (tester) async {
      final s = await pumpWithFiles(tester, [provider('Dr. Ahmed')], files: ['v/a.pdf', 'v/b.pdf']);
      expect(find.text(s.strings.care.care_manage_files), findsOne);
      expect(find.text(s.strings.care.care_attach_file), findsNothing);
      // Collapsed, the card previews them.
      expect(find.byType(VaultAttachmentThumb), findsNWidgets(2));
    });

    testWidgets('managing opens the gallery and the button becomes Done', (tester) async {
      final s = await pumpWithFiles(tester, [provider('Dr. Ahmed')], files: ['v/a.pdf']);
      await tester.tap(find.text(s.strings.care.care_manage_files));
      await tester.pumpAndSettle();
      expect(find.byType(VaultAttachmentGallery), findsOne);
      expect(find.text(s.strings.records.att_one_file), findsOne);
      expect(find.text(s.strings.care.care_files_done), findsOne);
      expect(find.text(s.strings.care.care_manage_files), findsNothing);
    });

    testWidgets('each provider drawer opens on its own', (tester) async {
      final s = await pumpWithFiles(tester, [provider('Dr. A'), provider('Dr. B')], files: ['v/a.pdf']);
      await tester.tap(find.text(s.strings.care.care_manage_files).first);
      await tester.pumpAndSettle();
      // One open drawer, not both.
      expect(find.text(s.strings.care.care_files_head), findsOne);
    });
  });
}
