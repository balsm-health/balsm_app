import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/widgets/body_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:self_report/self_report.dart';

/// Read-only body map on a saved record's detail screen.
void main() {
  Widget host(Set<PainSite> sites) => ProviderScope(
        child: MaterialApp(
          home: AppScope(
            state: PatientAppState(),
            child: Scaffold(body: SingleChildScrollView(child: BodyMapPreview(sites: sites))),
          ),
        ),
      );

  List<String> plateAssets(WidgetTester tester) => tester
      .widgetList<SvgPicture>(find.byType(SvgPicture))
      .map((p) => (p.bytesLoader as SvgAssetLoader).assetName)
      .toList();

  testWidgets('renders nothing without marked sites', (tester) async {
    await tester.pumpWidget(host(const {}));
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('one plate per view that holds a site', (tester) async {
    await tester.pumpWidget(host({const PainSite(Muscle.chest)}));
    expect(plateAssets(tester), ['assets/body/muscles_front.svg']);

    await tester.pumpWidget(host({const PainSite(Muscle.chest), const PainSite(Muscle.bk_neck)}));
    expect(plateAssets(tester), ['assets/body/muscles_front.svg', 'assets/body/muscles_back.svg']);
  });

  testWidgets('legacy mixed-tissue records get a plate per tissue', (tester) async {
    await tester.pumpWidget(host({const PainSite(Muscle.chest), const PainSite(Bone.neck)}));
    expect(plateAssets(tester), ['assets/body/muscles_front.svg', 'assets/body/bones_front.svg']);
  });

  testWidgets('lists each marked site as a read-only label', (tester) async {
    await tester.pumpWidget(host({const PainSite(Muscle.chest), const PainSite(Muscle.bk_neck)}));
    final s = PatientAppState();
    final messages = selfReportMessagesOf(s.lang.value);
    final mid = s.strings.checkin.list_mid;
    expect(find.text(const PainSite(Muscle.chest).label(messages, mid: mid)), findsOneWidget);
    expect(find.text(const PainSite(Muscle.bk_neck).label(messages, mid: mid)), findsOneWidget);
    expect(find.byType(InkWell), findsNothing, reason: 'preview has no remove buttons');
  });
}
