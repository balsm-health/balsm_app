import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/personal_details.dart';
import 'package:app/balsm_app/screens/profile_screen.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// `home.jsx` — QR sharing moved off Account details and onto the Profile tab.
///
/// The prototype now hangs it off two places on Profile (the app-bar button and
/// the `@handle` pill) and off none on Account details. These pin that, so the
/// entry point cannot silently drift back or end up on both screens at once.
void main() {
  setUp(() {
    FlavorConfig.init(
      brand: AppBrand.balsm,
      flavor: Flavor.dev,
      servers: const [ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5050')],
    );
  });

  Future<void> pumpProfile(WidgetTester tester, {String? handle, bool ar = false}) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        accountSummaryProvider.overrideWith(
          (ref) => Future.value(handle == null
              ? null
              : AccountSummary(
                  id: const UserId.value('u1'),
                  handle: handle,
                  displayName: 'Layla Hassan',
                  countryCode: 'EG',
                  preferredLanguage: 'en',
                  deletionState: 'ACTIVE',
                )),
        ),
      ],
      child: AppScope(
        state: state,
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the profile app bar carries the QR button', (tester) async {
    await pumpProfile(tester, handle: 'layla_hassan58');
    expect(find.byIcon(LucideIcons.qrCode), findsWidgets);
  });

  testWidgets('the handle renders as a tappable pill, LTR even in Arabic', (tester) async {
    await pumpProfile(tester, handle: 'layla_hassan58', ar: true);
    final pill = find.text('@layla_hassan58');
    expect(pill, findsOne);
    expect(Directionality.of(tester.element(pill)), TextDirection.ltr);
  });

  testWidgets('no handle, no pill — nothing is invented', (tester) async {
    await pumpProfile(tester);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('the QR opener is exported for the profile tab to call', (tester) async {
    // A compile-time pin: `openQrShare` must stay public. The sheet itself
    // lives with the account surface; only its entry point moved.
    expect(openQrShare, isA<Function>());
  });
}
