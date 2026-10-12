import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/widgets/phone_field.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The shared phone control (design: `dialcodes.jsx` `PhoneInput`).
///
/// The parse/join round trip matters more than the pixels: every number a
/// patient has already saved goes through it, and a wrong split silently
/// rewrites a care provider's phone number.
void main() {
  group('splitPhone', () {
    test('pulls a known dial code off the front', () {
      final r = splitPhone('+20 10 1234 5678');
      expect(r.country, CountryCode.egypt);
      expect(r.national, '10 1234 5678');
    });

    test('prefers the longest dial code, so +97 never shadows +971', () {
      // Both exist; a shortest-first scan would file a UAE number under +97.
      expect(splitPhone('+971 50 123 4567').country, CountryCode.united_arab_emirates);
    });

    test('a local number keeps the home country and is left alone', () {
      final r = splitPhone('01002345678');
      expect(r.country, kHomeCountry);
      expect(r.national, '01002345678', reason: 'never reinterpreted as a dial code');
    });

    test('an unknown + prefix is not silently re-filed', () {
      final r = splitPhone('+999123');
      expect(r.country, kHomeCountry);
      expect(r.national, '+999123', reason: 'kept verbatim rather than mangled');
    });

    test('empty stays empty', () {
      expect(splitPhone('').national, '');
      expect(splitPhone(null).national, '');
    });

    test('the fallback is used only when nothing parses', () {
      expect(splitPhone('555 1234', fallback: CountryCode.saudi_arabia).country, CountryCode.saudi_arabia);
      expect(splitPhone('+20 1 2', fallback: CountryCode.saudi_arabia).country, CountryCode.egypt);
    });
  });

  group('joinPhone', () {
    test('stores the dial code with the number', () {
      expect(joinPhone(CountryCode.egypt, '10 1234 5678'), '+20 10 1234 5678');
    });

    test('an empty number stores nothing, not a bare dial code', () {
      // A bare "+20" would read as a number the patient gave us, and
      // `contactPhoneKey` would start matching providers on it.
      expect(joinPhone(CountryCode.egypt, ''), '');
      expect(joinPhone(CountryCode.egypt, '   '), '');
    });

    test('round trips whatever splitPhone produced', () {
      for (final v in ['+20 10 1234 5678', '+966 50 123 4567', '+1 555 0100']) {
        final r = splitPhone(v);
        expect(joinPhone(r.country, r.national), v);
      }
    });
  });

  group('foldPhoneDigits', () {
    test('folds Arabic-Indic and Eastern Arabic-Indic digits (FR-213)', () {
      expect(foldPhoneDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(foldPhoneDigits('۰۱۲۳'), '0123');
    });

    test('leaves ASCII and separators alone', () {
      expect(foldPhoneDigits('10 1234-5678'), '10 1234-5678');
    });
  });

  test('every offered country has a dial code', () {
    // The picker filters on this; a blank code would render a button with no
    // prefix and store a number with no country.
    final offered = CountryCode.all.where((c) => c.dialCode.isNotEmpty);
    expect(offered, isNotEmpty);
    for (final c in offered) {
      expect(c.dialCode, startsWith('+'), reason: '${c.value} has a malformed dial code');
    }
  });

  group('the widget', () {
    Future<TextEditingController> pump(WidgetTester tester, String initial, {bool ar = false}) async {
      final state = PatientAppState();
      if (ar) state.setLang(LanguageCode.ar);
      final controller = TextEditingController(text: initial);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: Padding(padding: const EdgeInsets.all(20), child: PhoneField(controller: controller)),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('shows the dial code apart from the number', (tester) async {
      await pump(tester, '+966 50 123 4567');
      expect(find.text('+966'), findsOne);
      expect(find.text('50 123 4567'), findsOne);
    });

    testWidgets('typing writes the dial code back into the owner value', (tester) async {
      final controller = await pump(tester, '');
      await tester.enterText(find.byType(TextField), '10 1234 5678');
      await tester.pump();
      expect(controller.text, '+20 10 1234 5678');
    });

    testWidgets('clearing the number clears the whole value', (tester) async {
      final controller = await pump(tester, '+20 10 1234 5678');
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(controller.text, '', reason: 'no bare dial code left behind');
    });

    testWidgets('Arabic-Indic digits fold as they are typed', (tester) async {
      final controller = await pump(tester, '');
      await tester.enterText(find.byType(TextField), '١٠١٢٣٤');
      await tester.pump();
      expect(controller.text, '+20 101234');
    });

    testWidgets('picking a country rewrites the code and keeps the number', (tester) async {
      final controller = await pump(tester, '+20 10 1234 5678');
      final s = PatientAppState();

      await tester.tap(find.text('+20'));
      await tester.pumpAndSettle();
      expect(find.text(s.strings.common.ph_country), findsOne);

      // Search by dial code, which is the fastest route for someone who knows
      // it and does not know how Balsm spells their country.
      await tester.enterText(find.widgetWithText(TextField, s.strings.common.ph_country_search), '966');
      await tester.pumpAndSettle();
      await tester.tap(find.text('+966').first);
      await tester.pumpAndSettle();

      expect(controller.text, '+966 10 1234 5678');
    });

    testWidgets('the picker says so when nothing matches', (tester) async {
      await pump(tester, '');
      final s = PatientAppState();
      await tester.tap(find.text('+20'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, s.strings.common.ph_country_search), 'zzzzz');
      await tester.pumpAndSettle();
      expect(find.text(s.strings.common.ph_no_match), findsOne);
    });

    testWidgets('follows the owner rewriting the value', (tester) async {
      // The real sequence: the field builds empty, then the profile loads and
      // assigns to the controller. Before the picker existed that just showed
      // a string; now the split has to happen on assignment too.
      final controller = await pump(tester, '');
      expect(find.text('+20'), findsOne);

      controller.text = '+971 50 123 4567';
      await tester.pumpAndSettle();
      expect(find.text('+971'), findsOne);
      expect(find.text('50 123 4567'), findsOne);

      // And clearing it, as adding an emergency contact does.
      controller.text = '';
      await tester.pumpAndSettle();
      expect(find.text('50 123 4567'), findsNothing);
    });

    testWidgets('lays out in Arabic on a phone without overflowing', (tester) async {
      await pump(tester, '+20 10 1234 5678', ar: true);
      expect(tester.takeException(), isNull);
    });
  });
}
