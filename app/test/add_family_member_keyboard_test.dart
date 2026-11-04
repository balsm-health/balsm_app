import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/widgets/account_switcher.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The add-a-family-member form with the keyboard up.
///
/// The name field autofocuses, so the keyboard opens with the form. The sheet
/// was one fixed column padded by the keyboard's height, and on a phone the
/// form plus the keyboard is taller than the screen, so it overflowed
/// at the bottom (28px, reported in Arabic) instead of scrolling.
///
/// The sheet is opened through the real `showAppSheet`, with the keyboard as a
/// real view inset, because the height limit comes from the route and the
/// keyboard reaches the sheet through MediaQuery.
void main() {
  /// A 360×800 phone, logical pixels.
  const phone = Size(360, 800);

  /// About what the reported keyboard covers: the bottom ~40% of the screen.
  const keyboard = 320.0;

  Future<void> openManualForm(WidgetTester tester, {required bool ar, double scale = 1.0}) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = phone * 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
    addTearDown(tester.view.reset);

    final state = PatientAppState();
    // Assigned rather than setLang(), which also writes prefs.
    if (ar) state.lang = LanguageCode.ar;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: AppScope(
          state: state,
          child: Directionality(
            textDirection: state.dir,
            child: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showAppSheet<void>(
                      context,
                      textDirection: state.dir,
                      builder: (_) => AddFamilyMemberSheet(
                        s: state,
                        selfName: '',
                        onClose: () {},
                        onAdd: (_, __, ___, {linkJti}) {},
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // choose → manual: the mode with the text field, as reported.
    await tester.tap(find.text(state.strings.common.fam_manual));
    await tester.pumpAndSettle();
  }

  for (final ar in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      final lang = ar ? 'arabic' : 'english';
      testWidgets('the manual form fits with the keyboard up — $lang, text scale $scale', (tester) async {
        await openManualForm(tester, ar: ar, scale: scale);

        final failure = tester.takeException();
        expect(failure, isNull, reason: '$lang · text scale $scale\n$failure');
      });
    }
  }

  testWidgets('the buttons under the form can still be reached above the keyboard', (tester) async {
    await openManualForm(tester, ar: true);
    final c = PatientAppState()..lang = LanguageCode.ar;
    final scanInstead = find.text(c.strings.common.fam_scan_instead);

    // Fixing the overflow by clipping would hide these. They must scroll into
    // view and end up above the keyboard, not under it.
    await tester.scrollUntilVisible(scanInstead, 80, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();

    expect(tester.getRect(scanInstead).bottom, lessThanOrEqualTo(phone.height - keyboard));
  });
}
