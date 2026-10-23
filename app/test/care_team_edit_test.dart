import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/widgets/attachment_thumb.dart';
import 'package:app/balsm_app/widgets/phone_field.dart';
import 'package:app/balsm_app/widgets/photo_attach.dart';
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

  Future<PatientAppState> pump(
    WidgetTester tester,
    List<CareProvider> team, {
    bool ar = false,
    List<ImportedContact> picks = const [],
  }) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        careTeamProvider.overrideWith((ref) => Stream.value(team)),
        contactPickerProvider.overrideWithValue(_StubPicker(picks)),
      ],
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
      // The button names who is being edited, not just "Edit" — with several
      // cards open, the bare word tells a screen-reader user nothing. There is
      // exactly one node for it; an outer generic wrapper used to duplicate the
      // word and has been removed.
      final edit = tester.widget<RoundBtn>(
        find.ancestor(of: find.byIcon(LucideIcons.pencil), matching: find.byType(RoundBtn)),
      );
      expect(edit.semanticLabel, '${s.strings.care.care_edit} Dr. Sara Kamal');
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

  group('the add affordance', () {
    testWidgets('is a FAB, not the old dashed row', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      // `home.jsx` swapped the full-width dashed "Add a care provider" button
      // for a FAB, and then pointed that FAB at the phone's contacts.
      expect(find.byIcon(LucideIcons.userPlus), findsOne);
      expect(find.bySemanticsLabel(s.strings.care.care_import_fab), findsOne);
      expect(find.widgetWithText(DashedBorder, s.strings.care.care_add), findsNothing);
      expect(find.text(s.strings.care.care_add), findsNothing, reason: 'the dashed row is gone');
      // The standalone "From contacts" button went with it: one entry point.
      expect(find.text(s.strings.care.care_import), findsNothing);
    });

    testWidgets('is offered on an empty care team too', (tester) async {
      // The empty state has no add button of its own — the FAB is the only
      // way in, so it must not be gated on having a roster.
      final s = await pump(tester, const []);
      expect(find.text(s.strings.care.care_empty), findsOne);
      expect(find.byIcon(LucideIcons.userPlus), findsOne);
    });

    testWidgets('opens the contact import sheet, not either provider form', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      await tester.tap(find.byIcon(LucideIcons.userPlus));
      await tester.pumpAndSettle();
      expect(find.text(s.strings.care.care_import_title), findsOne);
      expect(find.text(s.strings.care.care_add_title), findsNothing);
      expect(find.text(s.strings.care.care_edit_title), findsNothing);
    });

    testWidgets('typing one in by hand is reached through the import sheet', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      await tester.tap(find.byIcon(LucideIcons.userPlus));
      await tester.pumpAndSettle();
      // The import sheet's own escape hatch is the only route to the blank
      // form now that the FAB is the picker.
      await tester.tap(find.text(s.strings.care.care_import_manual));
      await tester.pumpAndSettle();
      expect(find.text(s.strings.care.care_add_title), findsOne);
    });

    testWidgets('the list keeps a tail so the FAB never covers the last card', (tester) async {
      await pump(tester, [provider('Dr. Sara Kamal')]);
      final tail = tester.widgetList<SizedBox>(find.byType(SizedBox)).where((b) => b.height == 72 && b.width == null);
      expect(tail, isNotEmpty, reason: 'the design ends the scroll with a 72px spacer');
    });
  });

  group('the files block', () {
    testWidgets('lives in the edit sheet, not on the card', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      final c = s.strings.care;

      // Nothing on the roster.
      expect(find.text(c.care_files_head.toUpperCase()), findsNothing);
      expect(find.text(c.care_attach_file), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.pencil).first);
      await tester.pumpAndSettle();

      // `home.jsx` puts "Business card & files" in the form, between Notes and
      // the save row — a card is something you have in hand while typing the
      // provider in.
      // The eyebrow is uppercased, as `letter-spacing: 0.16em` labels are.
      final head = find.text(c.care_files_head.toUpperCase());
      await tester.ensureVisible(head);
      await tester.pumpAndSettle();
      expect(head, findsOne);
      expect(find.text(c.care_attach), findsOne);
    });

    testWidgets('with nothing attached it invites one, in a dashed row', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      final c = s.strings.care;
      await tester.tap(find.byIcon(LucideIcons.pencil).first);
      await tester.pumpAndSettle();

      final empty = find.text(c.care_attach_empty);
      await tester.ensureVisible(empty);
      await tester.pumpAndSettle();
      expect(empty, findsOne);
      expect(find.text(c.care_attach_empty_h), findsOne);
      // An empty gallery would read as broken; the invitation does not.
      expect(find.byType(VaultAttachmentGallery), findsNothing);
    });

    testWidgets('Attach asks where the file comes from before opening a picker', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      final c = s.strings.care;
      final r = s.strings.records;
      await tester.tap(find.byIcon(LucideIcons.pencil).first);
      await tester.pumpAndSettle();

      final attach = find.text(c.care_attach);
      await tester.ensureVisible(attach);
      await tester.pumpAndSettle();
      await tester.tap(attach);
      await tester.pumpAndSettle();

      // Files and Photos are different pickers on both platforms; going
      // straight to one of them is a dead end for whichever the patient needs.
      expect(find.text(r.att_source_title), findsOne);
      expect(find.text(r.att_src_files), findsOne);
      expect(find.text(r.att_src_gallery), findsOne);
    });

    testWidgets('dismissing the source sheet opens no picker', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      final c = s.strings.care;
      final r = s.strings.records;
      await tester.tap(find.byIcon(LucideIcons.pencil).first);
      await tester.pumpAndSettle();

      final attach = find.text(c.care_attach);
      await tester.ensureVisible(attach);
      await tester.pumpAndSettle();
      await tester.tap(attach);
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
        of: find.byType(AttachSourceSheet),
        matching: find.byIcon(LucideIcons.x),
      ));
      await tester.pumpAndSettle();

      // Back on the form, nothing picked, no platform call attempted.
      expect(find.text(r.att_source_title), findsNothing);
      expect(find.text(c.care_edit_title), findsOne);
    });

    testWidgets('no attachments means no preview strip on the card', (tester) async {
      await pump(tester, [provider('Dr. Sara Kamal')]);
      expect(find.byType(VaultAttachmentThumb), findsNothing);
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
      // The stored number arrives split: the dial code on its button, the
      // national part in the field. A number saved before the picker existed
      // has to survive the round trip.
      // The first field; the optional second one is empty and shows the home
      // country's code, which is why this is scoped.
      expect(find.descendant(of: find.byType(PhoneField).first, matching: find.text('+20')), findsOne);
      expect(sheetField('2 2555 0100'), findsOne);
    });

    testWidgets('adding is still a blank form', (tester) async {
      final s = await pump(tester, const []);
      await tester.tap(find.byIcon(LucideIcons.userPlus));
      await tester.pumpAndSettle();
      final c = s.strings.care;
      await tester.tap(find.text(c.care_import_manual));
      await tester.pumpAndSettle();
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

    testWidgets('Paste sits at the trailing edge of the field, not over the text', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      await openEdit(tester);
      final c = s.strings.care;

      final field = sheetField(c.care_ph_map);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();

      final fieldRect = tester.getRect(field);
      final pasteRect = tester.getRect(find.text(c.care_paste));

      // The regression this guards: laid over the field in a Stack, the button
      // landed mid-field on top of the hint, because a TextField under loose
      // constraints shrink-wraps to its hint width.
      expect(pasteRect.right, lessThanOrEqualTo(fieldRect.right + 0.5));
      expect(pasteRect.left, greaterThan(fieldRect.left + fieldRect.width / 2),
          reason: 'Paste belongs in the trailing half of the field');
      // And the hint has to have room, clear of it. The suffix used to swallow
      // the field, collapsing the content area to zero width.
      final hintRect = tester.getRect(find.text(c.care_ph_map));
      expect(hintRect.width, greaterThan(100), reason: 'the content area collapsed');
      expect(hintRect.right, lessThanOrEqualTo(pasteRect.left + 0.5));
    });

    testWidgets('the map field is outlined like every other field, not underlined', (tester) async {
      final s = await pump(tester, [provider('Dr. Sara Kamal')]);
      await openEdit(tester);

      final field = sheetField(s.strings.care.care_ph_map);
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();

      // Left unset, Material draws an underline and the prefix icon falls
      // outside the box — which is exactly how it shipped.
      final decoration = tester.widget<TextField>(field).decoration!;
      expect(decoration.enabledBorder, isA<OutlineInputBorder>());
      expect(decoration.focusedBorder, isA<OutlineInputBorder>());
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

/// Stands in for the OS contact picker: the screen's FAB opens it, and a test
/// must never reach the real address book.
class _StubPicker implements ContactPicker {
  _StubPicker(this._picks);
  final List<ImportedContact> _picks;

  @override
  bool get isAvailable => true;

  @override
  Future<List<ImportedContact>?> pick() async => _picks;
}
