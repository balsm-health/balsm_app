import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/auth_flow.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart'
    show DisclosureAcceptance, DisclosureDao, DisclosureId, disclosureDaoProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

class _FakeDisclosureDao extends Mock implements DisclosureDao {}

/// Dev Config's entry point on the welcome screen.
///
/// It exists because the server a build talks to is the first thing that goes
/// wrong and the shake gesture reaches nobody on a simulator — and it must not
/// exist in production, where the welcome screen belongs to a patient.
void main() {
  late DisclosureDao disclosure;

  setUpAll(() => registerFallbackValue(const DisclosureId.value('consolidated')));

  setUp(() {
    disclosure = _FakeDisclosureDao();
    when(() => disclosure.watchAcceptance(any(), any())).thenAnswer((_) => Stream<DisclosureAcceptance?>.value(null));
  });

  Future<void> pumpWelcome(WidgetTester tester, {required Flavor flavor}) async {
    FlavorConfig.init(brand: AppBrand.balsm, flavor: flavor);
    // The welcome layout overflows the default 800×600, and one overflow
    // exception fails every finder after it.
    tester.view.physicalSize = const Size(402, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [disclosureDaoProvider.overrideWithValue(disclosure)],
        child: MaterialApp(
          home: Material(
            type: MaterialType.transparency,
            child: AppScope(state: PatientAppState(), child: const AuthRouter()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a dev build offers it before anyone signs in', (tester) async {
    await pumpWelcome(tester, flavor: Flavor.dev);

    expect(find.byIcon(LucideIcons.wrench), findsOneWidget);
    // Labelled with the host it is actually pointed at, which is the question
    // being asked — the preset name reads "Local" either way.
    expect(find.textContaining('localhost'), findsOneWidget);
  });

  testWidgets('staging offers it too — that build can still be repointed', (tester) async {
    await pumpWelcome(tester, flavor: Flavor.staging);
    expect(find.byIcon(LucideIcons.wrench), findsOneWidget);
  });

  testWidgets('production does not, at any size', (tester) async {
    await pumpWelcome(tester, flavor: Flavor.prod);

    expect(find.byIcon(LucideIcons.wrench), findsNothing);
  });

  testWidgets('the language pill still stands beside it', (tester) async {
    await pumpWelcome(tester, flavor: Flavor.dev);

    // Both pills share one row at 402px; an overflow here would fail the test
    // through the exception it raises.
    expect(find.text('العربية'), findsOneWidget);
    expect(find.byIcon(LucideIcons.wrench), findsOneWidget);
  });
}
