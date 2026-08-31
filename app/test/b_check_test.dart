import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// `.b-check` — 18×18 box, radius 5 (circle for radio), 1.5px ink300 outline,
/// filling with brand blue when checked.
Future<void> _pump(WidgetTester tester, {required bool checked, required bool radio, VoidCallback? onTap}) =>
    tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: BCheck(
            label: 'Headache',
            checked: checked,
            radio: radio,
            accent: Accent.blue,
            icon: LucideIcons.brain,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ));

BoxDecoration _boxDecoration(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('unchecked box is white with an ink300 outline', (tester) async {
    await _pump(tester, checked: false, radio: false);
    final d = _boxDecoration(tester);
    expect(d.color, Colors.white);
    expect((d.border! as Border).top.color, T.ink300);
    expect((d.border! as Border).top.width, 1.5);
  });

  testWidgets('checked box fills with the session accent', (tester) async {
    await _pump(tester, checked: true, radio: false);
    final d = _boxDecoration(tester);
    // `--balsm-primary` is bound to the accent tweak in app.jsx.
    expect(d.color, Accent.blue.main);
    expect((d.border! as Border).top.color, Accent.blue.main);
  });

  testWidgets('checkbox is a 5pt-radius square; radio is a circle', (tester) async {
    await _pump(tester, checked: false, radio: false);
    var d = _boxDecoration(tester);
    expect(d.shape, BoxShape.rectangle);
    expect(d.borderRadius, BorderRadius.circular(5));

    await _pump(tester, checked: false, radio: true);
    d = _boxDecoration(tester);
    expect(d.shape, BoxShape.circle);
    expect(d.borderRadius, isNull);
  });

  testWidgets('box is 18×18 and the leading glyph is 15pt', (tester) async {
    await _pump(tester, checked: false, radio: false);
    final box = tester.getSize(find.byType(AnimatedContainer));
    expect(box, const Size(18, 18));
    expect(tester.widget<Icon>(find.byIcon(LucideIcons.brain)).size, 15);
  });

  testWidgets('tapping the label reports, not just the box', (tester) async {
    var taps = 0;
    await _pump(tester, checked: false, radio: false, onTap: () => taps++);
    await tester.tap(find.text('Headache'));
    expect(taps, 1);
  });
}
