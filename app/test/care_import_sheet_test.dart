import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/care_import_sheet.dart';
import 'package:app/balsm_app/screens/care_team_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }) async {
    final state = PatientAppState();
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
}
