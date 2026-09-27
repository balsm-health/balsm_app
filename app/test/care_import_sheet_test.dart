import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/care_import_sheet.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';

/// The contact-import review sheet.
///
/// Every contact here is invented by the test. The sheet never reaches a real
/// address book: the picker is a port, and this substitutes it.
class _FakePicker implements ContactPicker {
  _FakePicker(this._batches, {this.isAvailable = true});

  /// One list per call, so a test can open the picker twice.
  final List<List<ImportedContact>> _batches;
  int _calls = 0;

  @override
  final bool isAvailable;

  @override
  Future<List<ImportedContact>?> pick() async {
    if (!isAvailable) return null;
    return _calls < _batches.length ? _batches[_calls++] : const [];
  }
}

void main() {
  ImportedContact contact(String name, {String? phone}) =>
      ImportedContact(id: 'c-$name', name: name, phones: phone == null ? const [] : [phone]);

  CareProvider onTeam(String name, String phone) => CareProvider(
        id: CareProviderId.value('cp-$name'),
        healthProfileId: const HealthProfileId.value('hp-1'),
        type: CareProviderType.doctor,
        name: name,
        phone: phone,
        createdAt: DateTime.utc(2026, 1, 1),
      );

  Future<PatientAppState> pump(
    WidgetTester tester, {
    required ContactPicker picker,
    List<CareProvider> team = const [],
    bool ar = false,
  }) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        contactPickerProvider.overrideWithValue(picker),
        careTeamProvider.overrideWith((ref) => Stream.value(team)),
      ],
      child: AppScope(
        state: state,
        child: const MaterialApp(home: CareImportSheet()),
      ),
    ));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('carries its own sheet chrome, since showAppSheet supplies none', (tester) async {
    final s = await pump(tester,
        picker: _FakePicker([
          [contact('Dr. Sara Kamal', phone: '+201002345678')]
        ]));

    // Grab handle, title, and a scroll view — without these the sheet renders
    // as a bare unpadded column on the scrim.
    expect(find.byType(SheetGrab), findsOne);
    expect(find.text(s.strings.care.care_import_title), findsOne);
    expect(find.byType(SingleChildScrollView), findsOne);
  });

  testWidgets('opens the picker on entry and lists what came back, ticked', (tester) async {
    final s = await pump(tester,
        picker: _FakePicker([
          [contact('Dr. Sara Kamal', phone: '+201002345678'), contact('El Ezaby', phone: '+20219600')]
        ]));

    expect(find.text('Dr. Sara Kamal'), findsOne);
    expect(find.text('El Ezaby'), findsOne);
    // Both arrive ticked: the patient chose them in the OS picker a moment ago.
    expect(find.text(s.strings.care.care_import_cta('2')), findsOne);
  });

  testWidgets('unticking a row drops it from the count', (tester) async {
    final s = await pump(tester,
        picker: _FakePicker([
          [contact('Dr. Sara Kamal', phone: '+201002345678'), contact('El Ezaby', phone: '+20219600')]
        ]));

    await tester.tap(find.text('El Ezaby'));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.care.care_import_cta('1')), findsOne);

    await tester.tap(find.text('Dr. Sara Kamal'));
    await tester.pumpAndSettle();
    // Nothing ticked: the primary button says so rather than lying about zero.
    expect(find.text(s.strings.care.care_import_none), findsOne);
  });

  testWidgets('a contact already on the team is shown as such, not offered again', (tester) async {
    final s = await pump(
      tester,
      picker: _FakePicker([
        [contact('Dr. Sara Kamal', phone: '01002345678')]
      ]),
      // Same human, the other spelling of the number.
      team: [onTeam('Dr. Sara Kamal', '+201002345678')],
    );

    expect(find.text(s.strings.care.care_import_on_team), findsOne);
    expect(find.text(s.strings.care.care_import_none), findsOne);
  });

  testWidgets('a cancelled pick leaves the empty card, not a blank sheet', (tester) async {
    final s = await pump(tester, picker: _FakePicker(const []));

    expect(find.text(s.strings.care.care_import_empty), findsOne);
    expect(find.text(s.strings.care.care_import_pick), findsOne);
  });

  testWidgets('a platform with no picker says so and offers the manual route', (tester) async {
    final s = await pump(tester, picker: _FakePicker(const [], isAvailable: false));

    expect(find.text(s.strings.care.care_import_unavailable), findsOne);
    expect(find.text(s.strings.care.care_import_pick), findsNothing);
    expect(find.text(s.strings.care.care_import_manual), findsOne);
  });

  testWidgets('the count eyebrow says how many rows are listed', (tester) async {
    final s = await pump(tester,
        picker: _FakePicker([
          [contact('Dr. Sara Kamal', phone: '+201002345678'), contact('El Ezaby', phone: '+20219600')]
        ]));

    expect(find.text(s.strings.care.care_import_count('2').toUpperCase()), findsOne);
  });

  testWidgets('select all ticks every free row, and clear drops them again', (tester) async {
    final s = await pump(tester,
        picker: _FakePicker([
          [contact('Dr. Sara Kamal', phone: '+201002345678'), contact('El Ezaby', phone: '+20219600')]
        ]));

    // Everything arrives ticked, so the control offers the inverse.
    expect(find.text(s.strings.care.care_import_clear), findsOne);

    await tester.tap(find.text(s.strings.care.care_import_clear));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.care.care_import_none), findsOne);
    expect(find.text(s.strings.care.care_import_select_all), findsOne);

    await tester.tap(find.text(s.strings.care.care_import_select_all));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.care.care_import_cta('2')), findsOne);
  });

  testWidgets('a row already on the team is not swept up by select all', (tester) async {
    final s = await pump(
      tester,
      picker: _FakePicker([
        [contact('Dr. Sara Kamal', phone: '01002345678'), contact('El Ezaby', phone: '+20219600')]
      ]),
      team: [onTeam('Dr. Sara Kamal', '+201002345678')],
    );

    // One of the two is already there; importing it again would duplicate it,
    // so only the free row counts even though both arrived ticked.
    expect(find.text(s.strings.care.care_import_cta('1')), findsOne);

    await tester.tap(find.text(s.strings.care.care_import_clear));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.care.care_import_none), findsOne);

    await tester.tap(find.text(s.strings.care.care_import_select_all));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.care.care_import_cta('1')), findsOne);
  });

  testWidgets('search stays out of the way until the list is long enough to need it', (tester) async {
    final s = await pump(tester,
        picker: _FakePicker([
          [contact('Dr. Sara Kamal', phone: '+201002345678')]
        ]));

    expect(find.text(s.strings.care.care_import_search), findsNothing);
  });

  testWidgets('search filters the picked rows and says when nothing matches', (tester) async {
    final s = await pump(tester,
        picker: _FakePicker([
          [for (var i = 0; i < 9; i++) contact('Contact $i', phone: '+2010000000$i')]
        ]));

    expect(find.text(s.strings.care.care_import_search), findsOne);

    // Searched by number, so the query itself cannot be mistaken for a row
    // label: only contact 4's phone ends `04`.
    await tester.enterText(find.byType(TextField), '04');
    await tester.pumpAndSettle();
    expect(find.text('Contact 4'), findsOne);
    expect(find.text('Contact 5'), findsNothing);
    // Filtering is a view, not a deselection: all nine are still going in.
    expect(find.text(s.strings.care.care_import_cta('9')), findsOne);

    await tester.enterText(find.byType(TextField), 'Nobody');
    await tester.pumpAndSettle();
    expect(find.text(s.strings.care.care_import_no_match), findsOne);
  });

  testWidgets('lays out in Arabic on a phone without overflowing — the design is RTL-native', (tester) async {
    // A phone, not the 800x600 default: the row packs a name, an on-team badge
    // and a type chip across one line, and only a narrow viewport tests that.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pump(
      tester,
      ar: true,
      picker: _FakePicker([
        [for (var i = 0; i < 9; i++) contact('جهة اتصال $i', phone: '+2010000000$i')]
      ]),
      team: [onTeam('جهة اتصال 0', '+20100000000')],
    );

    // Open one row's type chips — the widest thing the sheet can render — with
    // the search box, the eyebrow, the select-all control and an on-team badge
    // all on screen at once.
    await tester.tap(find.byIcon(LucideIcons.chevronDown).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
