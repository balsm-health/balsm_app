import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:core/core.dart';

// Golden tests for all BalsmKit widgets.
// Run: flutter test --update-goldens (first time to generate baseline images)
// RTL + LTR × light + dark × en + ar-EG = 4 variants per widget.

void main() {
  setUpAll(loadAppFonts);

  for (final (locale, dir) in [
    (const Locale('en'), TextDirection.ltr),
    (const Locale('ar', 'EG'), TextDirection.rtl),
  ]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final suffix = '${locale.toLanguageTag()}_${brightness.name}';

      group('BalsmPill [$suffix]', () {
        testGoldens('all variants', (tester) async {
          await tester.pumpWidgetBuilder(
            _wrap(
              Wrap(
                spacing: 8,
                children: BalsmPillVariant.values.map((v) => BalsmPill(label: v.name, variant: v)).toList(),
              ),
              locale: locale,
              dir: dir,
              brightness: brightness,
            ),
          );
          await screenMatchesGolden(tester, 'balsm_pill_$suffix');
        });
      });

      group('BalsmCard [$suffix]', () {
        testGoldens('all variants', (tester) async {
          await tester.pumpWidgetBuilder(
            _wrap(
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BalsmCard(child: const Text('Standard')),
                  const SizedBox(height: 8),
                  BalsmCard.accent(child: const Text('Accent')),
                  const SizedBox(height: 8),
                  BalsmCard.danger(child: const Text('Danger')),
                  const SizedBox(height: 8),
                  BalsmCard.cream(child: const Text('Cream')),
                ],
              ),
              locale: locale,
              dir: dir,
              brightness: brightness,
            ),
            surfaceSize: const Size(375, 400),
          );
          await screenMatchesGolden(tester, 'balsm_card_$suffix');
        });
      });

      group('BalsmAvatar [$suffix]', () {
        testGoldens('sizes', (tester) async {
          await tester.pumpWidgetBuilder(
            _wrap(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BalsmAvatar(initials: 'AH', size: 44),
                  const SizedBox(width: 12),
                  BalsmAvatar(initials: 'MK', size: 84, backgroundColor: BalsmColors.petalEmerald),
                ],
              ),
              locale: locale,
              dir: dir,
              brightness: brightness,
            ),
          );
          await screenMatchesGolden(tester, 'balsm_avatar_$suffix');
        });
      });

      group('BalsmStepDots [$suffix]', () {
        testGoldens('step 2 of 3', (tester) async {
          await tester.pumpWidgetBuilder(
            _wrap(
              const BalsmStepDots(totalSteps: 3, currentStep: 2),
              locale: locale,
              dir: dir,
              brightness: brightness,
            ),
          );
          await screenMatchesGolden(tester, 'balsm_step_dots_$suffix');
        });
      });

      group('BalsmBottomNav [$suffix]', () {
        testGoldens('tab 0 active', (tester) async {
          await tester.pumpWidgetBuilder(
            _wrap(
              BalsmBottomNav(
                tabs: BalsmBottomNav.defaultTabs,
                currentIndex: 0,
                onTap: (_) {},
              ),
              locale: locale,
              dir: dir,
              brightness: brightness,
            ),
            surfaceSize: const Size(375, 80),
          );
          await screenMatchesGolden(tester, 'balsm_bottom_nav_$suffix');
        });
      });
    }
  }
}

Widget _wrap(
  Widget child, {
  required Locale locale,
  required TextDirection dir,
  required Brightness brightness,
}) {
  return MaterialApp(
    locale: locale,
    theme: ThemeData(brightness: brightness),
    home: Directionality(
      textDirection: dir,
      child: Scaffold(
        body: Center(child: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    ),
  );
}
