import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/theme.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:app/balsm_app/widgets/select_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Every surface in the app is flat white. Material's own popups are the
/// exception that has to be asked for: they have no Balsm widget to take a
/// colour from and fall back to the theme, and `ThemeData` derives
/// `canvasColor` from the default Material 3 `colorScheme.surface` — `#FEF7FF`,
/// white with a violet cast. `scaffoldBackgroundColor` was set and
/// `canvasColor` was not, which is why the pages were white and the menus that
/// opened over them were lilac.
///
/// `DropdownButton` paints its menu with
/// `dropdownColor ?? Theme.of(context).canvasColor`, so this reads the token
/// the menu actually uses rather than sampling pixels.
void main() {
  test('the theme does not leave a popup to the default M3 surface', () {
    final theme = balsmTheme();

    // What DropdownButton paints its menu with.
    expect(theme.canvasColor, T.surface);
    expect(theme.popupMenuTheme.color, T.surface);

    // The tint M3 would otherwise lay back over that white at elevation.
    expect(theme.popupMenuTheme.surfaceTintColor, Colors.transparent);
  });

  test('the date and time pickers are white too', () {
    final theme = balsmTheme();

    // A different token from canvasColor: DatePickerDialog falls back to
    // colorScheme.surfaceContainerHigh, so setting canvasColor alone would
    // leave this dialog lilac while reading as though it had covered it.
    expect(theme.datePickerTheme.backgroundColor, T.surface);
    expect(theme.datePickerTheme.headerBackgroundColor, T.surface);
    expect(theme.datePickerTheme.surfaceTintColor, Colors.transparent);

    expect(theme.timePickerTheme.backgroundColor, T.surface);
  });

  testWidgets('an open SelectField menu is white', (tester) async {
    const items = [('skin', 'Skin'), ('muscle', 'Muscle'), ('bone', 'Bone')];
    var value = 'skin';

    await tester.pumpWidget(
      MaterialApp(
        theme: balsmTheme(),
        home: AppScope(
          state: PatientAppState(),
          child: Scaffold(
            body: Center(
              child: SelectField<String>(
                value: value,
                items: items,
                semanticsLabel: 'Layer',
                onChanged: (v) => value = v,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SelectField<String>));
    await tester.pumpAndSettle();

    // The menu is up: every option is on screen, the closed field showed one.
    expect(find.text('Muscle'), findsOneWidget);

    // The menu's background is the inherited canvasColor, read from inside the
    // route so a theme that stops short of the overlay is caught too.
    final menuTheme = Theme.of(tester.element(find.text('Muscle')));
    expect(menuTheme.canvasColor, T.surface);
  });
}
