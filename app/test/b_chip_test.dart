import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

Future<void> _pump(WidgetTester tester, {required bool active, VoidCallback? onTap}) => tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: BChip(
            'Blood pressure',
            active: active,
            accent: Accent.blue.main,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ));

void main() {
  testWidgets('inactive chip is outlined, no check', (tester) async {
    await _pump(tester, active: false);
    final d = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration;
    expect(d.color, Colors.white);
    expect((d.border! as Border).top.color, T.border);
    expect(find.byIcon(LucideIcons.check), findsNothing);
    expect(find.text('Blood pressure'), findsOneWidget);
  });

  testWidgets('active chip fills the accent and shows a check', (tester) async {
    await _pump(tester, active: true);
    final d = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as BoxDecoration;
    expect(d.color, Accent.blue.main);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
  });

  testWidgets('tapping reports', (tester) async {
    var taps = 0;
    await _pump(tester, active: false, onTap: () => taps++);
    await tester.tap(find.text('Blood pressure'));
    expect(taps, 1);
  });
}
