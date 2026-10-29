import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// The app's single [ThemeData].
///
/// Almost nothing in the app reads it: the screens are drawn from the [T]
/// tokens, and the kit widgets carry their own colours. What is left is the
/// handful of surfaces Material builds for us — dropdown menus, popup menus —
/// which have no Balsm widget to take their colour from and fall back to the
/// theme.
///
/// That fallback is the trap. `ThemeData` derives `canvasColor` from
/// `colorScheme.surface`, and the default Material 3 scheme's surface is
/// `#FEF7FF` — white with a violet cast. `scaffoldBackgroundColor` was set
/// here, so the pages were white and only the popups were not; a menu opened
/// lilac over a white field. `DropdownButton` paints its menu with
/// `dropdownColor ?? Theme.of(context).canvasColor`, so one unset token
/// coloured every dropdown in the app.
///
/// Setting it on the theme rather than per call site means a dropdown added
/// later is white without anyone remembering to ask for it. `surfaceTintColor`
/// on the menu themes is belt-and-braces: M3 tints a raised Material by its
/// elevation, which would put the same cast back on a white fill.
///
/// Lives in its own file so `previews/preview_harness.dart` can mount the same
/// theme the shell does — a preview that is not the app's colour is a preview
/// that lies.
ThemeData balsmTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: T.surface,
      canvasColor: T.surface,
      popupMenuTheme: const PopupMenuThemeData(color: T.surface, surfaceTintColor: Colors.transparent),
      dropdownMenuTheme: const DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(T.surface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(T.surface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
