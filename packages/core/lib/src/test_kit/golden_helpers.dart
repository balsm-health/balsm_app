import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../kit/theme.dart';

/// Wraps [widget] in both LTR and RTL variants for golden snapshots.
void goldenTest(
  String name,
  Widget widget, {
  List<Locale> locales = const [Locale('en'), Locale('ar', 'EG')],
  List<Brightness> brightnesses = const [Brightness.light, Brightness.dark],
  Size? size,
}) {
  for (final locale in locales) {
    final isRtl = locale.languageCode == 'ar';
    for (final brightness in brightnesses) {
      final variantName = '${name}_${locale.toLanguageTag().replaceAll('-', '_')}_${brightness.name}';

      testGoldens(variantName, (tester) async {
        await loadAppFonts();
        final theme = brightness == Brightness.light ? BalsmTheme.light() : BalsmTheme.dark();

        await tester.pumpWidgetBuilder(
          MaterialApp(
            theme: theme,
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('ar', 'EG'), Locale('ar', 'SA'), Locale('ar', 'AE')],
            home: Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: Scaffold(body: widget),
            ),
          ),
          surfaceSize: size ?? const Size(390, 844),
        );

        await screenMatchesGolden(tester, variantName);
      });
    }
  }
}
