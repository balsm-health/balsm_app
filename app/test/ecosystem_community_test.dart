import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:core/core.dart';
import 'package:app/balsm_app/screens/ecosystem_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// `ecosystem.jsx` — the community half of the "Balsm is bigger than this app"
/// sheet: the seven-up Follow row, and the help rows that now actually go
/// somewhere (share the download link, open the providers/contributors pages).
///
/// Nothing here touches account or health data — every destination is a public
/// project page — so these are pure layout/affordance checks.
void main() {
  Future<PatientAppState> pump(WidgetTester tester, {Size size = const Size(390, 900), bool ar = false}) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      child: AppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(onPressed: () => showEcosystemSheet(context), child: const Text('open'));
            }),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('the Follow row carries all seven marks', (tester) async {
    await pump(tester);
    // Seven inline SVG glyphs — Lucide has no TikTok or Patreon, so the design
    // ships path data and so do we. (The hero flower is an asset-loaded
    // SvgPicture too, so count the string-loaded ones only.)
    final inline =
        tester.widgetList<SvgPicture>(find.byType(SvgPicture)).where((w) => w.bytesLoader is SvgStringLoader);
    expect(inline.length, 7);
    for (final label in ['balsm.health', 'LinkedIn', 'Facebook', 'Instagram', 'TikTok', 'Patreon', 'GitHub']) {
      expect(find.bySemanticsLabel(label), findsOne, reason: '$label tile missing');
    }
  });

  testWidgets('the Follow row fits seven up at the narrowest supported width', (tester) async {
    await pump(tester, size: const Size(320, 900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('each destination gets the mark that matches where it goes', (tester) async {
    final s = await pump(tester);
    final e = s.strings.ecosystem;

    // Share row: the download link is printed under the copy.
    expect(find.text('balsm.health/download'), findsOne);
    // Two outbound pages (providers, contributors) carry the external mark.
    expect(find.byIcon(LucideIcons.externalLink), findsNWidgets(2));
    // Feedback stays in-app, so it keeps the chevron.
    expect(find.text(e.eco_a2h), findsOne);
    // The share row's own trailing mark.
    expect(find.byIcon(LucideIcons.share), findsOne);
  });

  testWidgets('the ecosystem rows paint the ink-50 tint the design names', (tester) async {
    await pump(tester);
    final s = AppScope.of(tester.element(find.byType(SvgPicture).first));
    final tinted = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => (c.decoration as BoxDecoration?)?.color == T.ink50);
    // Two ecosystem parts + seven social tiles.
    expect(tinted.length, greaterThanOrEqualTo(9));
    expect(s.strings.ecosystem.eco_follow_t, isNotEmpty);
  });

  testWidgets('the download link stays LTR in Arabic', (tester) async {
    await pump(tester, ar: true);
    final link = find.text('balsm.health/download');
    expect(link, findsOne);
    expect(Directionality.of(tester.element(link)), TextDirection.ltr);
  });
}
