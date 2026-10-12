import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:app/balsm_app/widgets/beta_banner.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The beta ribbon: on by default, in the app's language, never in the way of
/// a tap, and gone when its flag is switched off.
void main() {
  Future<void> pump(WidgetTester tester, PatientAppState state, {VoidCallback? onTap}) => tester.pumpWidget(
        MaterialApp(
          // Flutter's own DEBUG ribbon is a Banner too; keep it out of the count.
          debugShowCheckedModeBanner: false,
          home: BetaBanner(
            state: state,
            child: Scaffold(
              body: Align(
                alignment: AlignmentDirectional.topEnd,
                child: TextButton(onPressed: onTap, child: const Text('under the ribbon')),
              ),
            ),
          ),
        ),
      );

  Banner ribbon(WidgetTester tester) => tester.widget<Banner>(find.byType(Banner));

  testWidgets('is shown by default, in English', (tester) async {
    await pump(tester, PatientAppState());
    expect(ribbon(tester).message, 'Beta');
    expect(ribbon(tester).location, BannerLocation.topEnd);
    expect(ribbon(tester).color, T.warning, reason: 'amber whatever the accent');
  });

  testWidgets('reads «إطلاق تجريبي» in Arabic and lays out right to left', (tester) async {
    await pump(tester, PatientAppState()..setLang(LanguageCode.ar));
    expect(ribbon(tester).message, 'إطلاق تجريبي');
    expect(ribbon(tester).textDirection, TextDirection.rtl);
    expect(ribbon(tester).layoutDirection, TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a button under the ribbon still takes the tap', (tester) async {
    var taps = 0;
    await pump(tester, PatientAppState(), onTap: () => taps++);
    await tester.tap(find.text('under the ribbon'));
    expect(taps, 1);
  });

  testWidgets('is gone once the flag is switched off', (tester) async {
    final flags = FeatureFlags(flags: AppFlags.all, allowOverrides: true)..setOverride(AppFlags.betaBanner, false);
    await pump(tester, PatientAppState()..attachFlags(flags));
    expect(find.byType(Banner), findsNothing);
    expect(find.text('under the ribbon'), findsOne);
  });
}
