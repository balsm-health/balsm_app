// T177 — Golden snapshot tests (golden_toolkit).
//
// One real testGoldens for BalsmCard rendered across four variants:
//   en-light, en-dark, ar-rtl-light, ar-rtl-dark
// driven via multiScreenGolden device list + per-theme/direction wrapping.
//
// Per-screen goldens are stubbed below as TODOs — they require their screen
// widgets + router/provider fixtures which are added in their own tasks.
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// Builds the BalsmCard sample under a given theme + direction.
Widget _buildCard({required ThemeData theme, required bool rtl}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    locale: rtl ? const Locale('ar', 'EG') : const Locale('en'),
    supportedLocales: const [
      Locale('en'),
      Locale('ar', 'EG'),
      Locale('ar', 'SA'),
      Locale('ar', 'AE'),
    ],
    home: Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BalsmCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Balsm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('Sample card content for golden snapshot.'),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testGoldens('BalsmCard renders across en/ar x light/dark', (tester) async {
    await loadAppFonts();

    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(devices: [Device.phone])
      ..addScenario(
        name: 'en-light',
        widget: _buildCard(theme: BalsmTheme.light(), rtl: false),
      )
      ..addScenario(
        name: 'en-dark',
        widget: _buildCard(theme: BalsmTheme.dark(), rtl: false),
      )
      ..addScenario(
        name: 'ar-rtl-light',
        widget: _buildCard(theme: BalsmTheme.light(), rtl: true),
      )
      ..addScenario(
        name: 'ar-rtl-dark',
        widget: _buildCard(theme: BalsmTheme.dark(), rtl: true),
      );

    await tester.pumpDeviceBuilder(builder);
    await multiScreenGolden(tester, 'balsm_card_variants');
  });

  // TODO(T177): golden — CountrySelectScreen (en-light/en-dark/ar-rtl-light/ar-rtl-dark)
  // TODO(T177): golden — EmailEntryScreen
  // TODO(T177): golden — OtpScreen
  // TODO(T177): golden — DisclosureScreen
  // TODO(T177): golden — HomeScreen (greeting + nudges)
  // TODO(T177): golden — HealthProfileScreen
  // TODO(T177): golden — HandleScreen
  // TODO(T177): golden — EmergencyCardScreen
  // TODO(T177): golden — MedicationsListScreen (empty + populated)
  // TODO(T177): golden — DeletionScreen
  // TODO(T177): golden — SessionsScreen
  // TODO(T177): golden — AccountSettingsScreen
  // TODO(T177): golden — NotFoundScreen
}
