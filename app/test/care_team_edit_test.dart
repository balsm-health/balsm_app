import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';

/// `home.jsx` — the care-team card's remove button became an edit button, and
/// the add sheet gained a map link plus a guarded remove.
///
/// Every provider here is invented by the test; the screen never seeds one.
void main() {
  CareProvider provider(String name, {String? mapUrl, String? phone}) => CareProvider(
        id: CareProviderId.value('cp-$name'),
        healthProfileId: const HealthProfileId.value('hp-1'),
        type: CareProviderType.doctor,
        name: name,
        phone: phone,
        mapUrl: mapUrl,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  Future<PatientAppState> pump(WidgetTester tester, List<CareProvider> team, {bool ar = false}) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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

  group('the card', () {
    testWidgets('offers edit, not a bare remove', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      expect(find.byIcon(LucideIcons.pencil), findsOne);
      // Removal moved into the sheet, behind a confirm — it is not one tap
      // away from the roster any more.
      expect(find.bySemanticsLabel(s.strings.care.care_edit), findsOne);
      expect(find.byIcon(LucideIcons.x), findsNothing);
    });

    testWidgets('shows Directions only when a usable link was saved', (tester) async {
      final s = await pump(tester, [
        provider('Dr. With', mapUrl: 'https://maps.app.goo.gl/abc'),
        provider('Dr. Without'),
        provider('Dr. Typed', mapUrl: '12 Street 9, Maadi'),
      ]);
      // One link, one plain address, one nothing — only the link is tappable.
      expect(find.text(s.strings.care.care_directions), findsOne);
    });
  });

  group('the sheet', () {
    Future<void> openEdit(WidgetTester tester) async {
      await tester.tap(find.byIcon(LucideIcons.pencil).first);
      await tester.pumpAndSettle();
    }

    /// The sheet scrolls; the remove action sits past the fold.
    Future<void> tapInSheet(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    /// Scoped to the sheet — the roster's search field is a TextField too.
    Finder sheetField(String text) => find.descendant(
          of: find.byType(AddCareProviderSheet),
          matching: find.widgetWithText(TextField, text),
        );

    testWidgets('opens in edit mode with the provider already filled in', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal', phone: '+20 2 2555 0100')]);
      await openEdit(tester);

      final c = s.strings.care;
      expect(find.text(c.care_edit_title), findsOne, reason: 'edit, not add');
      expect(find.text(c.care_save_changes), findsOne);
      expect(find.text(c.care_save), findsNothing);
      // The fields arrive populated rather than blank.
      expect(sheetField('Dr. Sara Kamal'), findsOne);
      expect(sheetField('+20 2 2555 0100'), findsOne);
    });

    testWidgets('adding is still a blank form', (tester) async {
      final s = await pump(tester, const []);
      await tester.tap(find.text(s.strings.care.care_add));
      await tester.pumpAndSettle();
      final c = s.strings.care;
      expect(find.text(c.care_add_title), findsOne);
      expect(find.text(c.care_save), findsOne);
      // No removal on a row that does not exist yet.
      expect(find.text(c.care_delete), findsNothing);
    });

    testWidgets('removal takes two taps, and says what it deletes', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      await openEdit(tester);
      final c = s.strings.care;

      expect(find.text(c.care_delete), findsOne);
      expect(find.text(c.care_delete_q('Dr. Sara Kamal')), findsNothing);

      await tapInSheet(tester, find.text(c.care_delete));

      // The confirm names the provider and warns about the files.
      expect(find.text(c.care_delete_q('Dr. Sara Kamal')), findsOne);
      expect(find.text(c.care_delete_h), findsOne);
      expect(find.text(c.care_keep), findsOne);
    });

    testWidgets('the confirm can be backed out of', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      await openEdit(tester);
      final c = s.strings.care;
      await tapInSheet(tester, find.text(c.care_delete));
      await tapInSheet(tester, find.text(c.care_keep));
      expect(find.text(c.care_delete_q('Dr. Sara Kamal')), findsNothing);
      expect(find.text(c.care_delete), findsOne);
    });

    testWidgets('the map field explains where to get a link, then flags a bad one', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      await openEdit(tester);
      final c = s.strings.care;

      // Empty: the how-to, not an error.
      expect(find.text(c.care_map_help), findsOne);
      expect(find.text(c.care_map_bad), findsNothing);

      await tester.enterText(sheetField(c.care_ph_map), 'not a link');
      await tester.pumpAndSettle();
      expect(find.text(c.care_map_bad), findsOne);
      expect(find.text(c.care_map_help), findsNothing);

      await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == 'not a link'),
          'https://maps.app.goo.gl/abc');
      await tester.pumpAndSettle();
      expect(find.text(c.care_map_bad), findsNothing);
    });

    testWidgets('a saved link renders LTR even in Arabic', (tester) async {
      await pump(tester, [provider('Dr. Sara Kamal', mapUrl: 'https://maps.app.goo.gl/abc')], ar: true);
      await openEdit(tester);
      final field = sheetField('https://maps.app.goo.gl/abc');
      expect(field, findsOne);
      expect(tester.widget<TextField>(field).textDirection, TextDirection.ltr);
    });
  });
}
