import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'dart:ui' as ui;

import 'app_state.dart';

/// The desktop actions the menu can trigger. Callbacks rather than direct
/// imports so the menu stays testable and the shell keeps owning navigation.
typedef DesktopMenuActions = ({
  void Function() checkIn,
  void Function() quickLog,
  void Function() emergency,
  void Function() logs,
  void Function() devConfig,
});

/// Desktop menu bar.
///
/// macOS gets the NATIVE menu bar ([PlatformMenuBar]) with the system-provided
/// app menu (About / Hide / Quit); Windows and Linux get an in-window Material
/// [MenuBar] plus a [CallbackShortcuts] layer so the accelerators work even
/// while the menu is closed. Mobile and web render [child] untouched.
///
/// The screenshot item rasterises [captureKey]'s RepaintBoundary — the whole
/// app UI — and saves it through the platform save dialog. That keeps the
/// macOS sandbox happy (user-selected file access) and keeps the export a
/// deliberate user act, which is the PHI rule for anything leaving the app.
class DesktopMenuScope extends StatelessWidget {
  const DesktopMenuScope({
    super.key,
    required this.state,
    required this.captureKey,
    required this.actions,
    required this.child,
  });

  final PatientAppState state;
  final GlobalKey captureKey;
  final DesktopMenuActions actions;
  final Widget child;

  static bool get _isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  // (label key, tab id) in menu order. Trends/records/rx have no bottom-nav
  // string of their own — the menu is where they become first-class on
  // desktop, so they get menu strings below.
  static const _tabs = <(String, String)>[
    ('home', 'home'),
    ('map', 'map'),
    ('meds', 'meds'),
    ('rx', 'rx'),
    ('records', 'records'),
    ('trends', 'trends'),
    ('profile', 'profile'),
  ];

  String _tabLabel(PatientAppState s, String tab) => switch (tab) {
        'home' => s.strings.nav.tab_home,
        'map' => s.strings.nav.tab_map,
        'meds' => s.strings.nav.tab_meds,
        'profile' => s.strings.nav.tab_profile,
        'rx' => s.strings.nav.menu_prescriptions,
        'records' => s.strings.nav.menu_records,
        'trends' => s.strings.nav.menu_trends,
        _ => tab,
      };

  Future<void> _saveScreenshot(BuildContext context) async {
    final boundary = captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    final bytes = data.buffer.asUint8List();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save screenshot',
      fileName: 'balsm-${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.png',
      type: FileType.image,
    );
    if (path == null) return;
    await File(path).writeAsBytes(Uint8List.fromList(bytes));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return child;
    final s = state;
    final meta = Platform.isMacOS;
    // Patient actions and section navigation only exist inside the signed-in
    // shell — on the auth flow they would push screens whose providers need a
    // session. Diagnostics (screenshot / logs / dev config) stay: they are
    // exactly what you need when sign-in itself misbehaves.
    final signedIn = state.route == 'app';

    SingleActivator nav(int n) => SingleActivator(
          const [
            LogicalKeyboardKey.digit1,
            LogicalKeyboardKey.digit2,
            LogicalKeyboardKey.digit3,
            LogicalKeyboardKey.digit4,
            LogicalKeyboardKey.digit5,
            LogicalKeyboardKey.digit6,
            LogicalKeyboardKey.digit7,
          ][n],
          meta: meta,
          control: !meta,
        );
    final checkInKey = SingleActivator(LogicalKeyboardKey.keyN, meta: meta, control: !meta);
    final quickLogKey = SingleActivator(LogicalKeyboardKey.keyL, meta: meta, control: !meta);
    final emergencyKey = SingleActivator(LogicalKeyboardKey.keyE, meta: meta, control: !meta);
    final shotKey = SingleActivator(LogicalKeyboardKey.keyS, meta: meta, control: !meta, shift: true);
    final logsKey = SingleActivator(LogicalKeyboardKey.keyL, meta: meta, control: !meta, shift: true);
    final devKey = SingleActivator(LogicalKeyboardKey.keyD, meta: meta, control: !meta, shift: true);

    if (Platform.isMacOS) {
      return PlatformMenuBar(
        menus: [
          PlatformMenu(
            label: 'Balsm',
            menus: [
              if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.about))
                const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
              PlatformMenuItemGroup(members: [
                if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.hide))
                  const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
              ]),
              if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.quit))
                const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
            ],
          ),
          PlatformMenu(
            label: s.strings.nav.menu_actions,
            menus: [
              if (signedIn) ...[
                PlatformMenuItem(label: s.strings.nav.menu_checkin, shortcut: checkInKey, onSelected: actions.checkIn),
                PlatformMenuItem(
                    label: s.strings.nav.menu_quicklog, shortcut: quickLogKey, onSelected: actions.quickLog),
                PlatformMenuItem(
                    label: s.strings.nav.menu_emergency, shortcut: emergencyKey, onSelected: actions.emergency),
              ],
              PlatformMenuItemGroup(members: [
                PlatformMenuItem(
                    label: s.strings.nav.menu_screenshot,
                    shortcut: shotKey,
                    onSelected: () => _saveScreenshot(context)),
              ]),
            ],
          ),
          if (signedIn)
            PlatformMenu(
              label: s.strings.nav.menu_go,
              menus: [
                for (final (i, (_, tab)) in _tabs.indexed)
                  PlatformMenuItem(
                    label: _tabLabel(s, tab),
                    shortcut: nav(i),
                    onSelected: () => state.setTab(tab),
                  ),
              ],
            ),
        ],
        child: child,
      );
    }

    // Windows / Linux: in-window Material menu + always-on accelerators.
    final shortcuts = <ShortcutActivator, VoidCallback>{
      if (signedIn) checkInKey: actions.checkIn,
      if (signedIn) quickLogKey: actions.quickLog,
      if (signedIn) emergencyKey: actions.emergency,
      shotKey: () => _saveScreenshot(context),
      logsKey: actions.logs,
      devKey: actions.devConfig,
      if (signedIn)
        for (final (i, (_, tab)) in _tabs.indexed) nav(i): () => state.setTab(tab),
    };
    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Column(children: [
          MenuBar(children: [
            SubmenuButton(
              menuChildren: [
                MenuItemButton(
                    shortcut: checkInKey, onPressed: actions.checkIn, child: Text(s.strings.nav.menu_checkin)),
                MenuItemButton(
                    shortcut: quickLogKey, onPressed: actions.quickLog, child: Text(s.strings.nav.menu_quicklog)),
                MenuItemButton(
                    shortcut: emergencyKey, onPressed: actions.emergency, child: Text(s.strings.nav.menu_emergency)),
                MenuItemButton(
                    shortcut: shotKey,
                    onPressed: () => _saveScreenshot(context),
                    child: Text(s.strings.nav.menu_screenshot)),
              ],
              child: Text(s.strings.nav.menu_actions),
            ),
            if (signedIn)
              SubmenuButton(
                menuChildren: [
                  for (final (i, (_, tab)) in _tabs.indexed)
                    MenuItemButton(
                        shortcut: nav(i), onPressed: () => state.setTab(tab), child: Text(_tabLabel(s, tab))),
                ],
                child: Text(s.strings.nav.menu_go),
              ),
          ]),
          Expanded(child: child),
        ]),
      ),
    );
  }
}
