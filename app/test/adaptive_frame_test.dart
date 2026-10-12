import 'package:app/balsm_app/shell.dart';
import 'package:app/balsm_app/tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AdaptiveFrame` — app.css `@container app (min-width: 1024px)`: from the
/// expanded window class a screen is contained at `--content-max` (1024) on
/// the cream canvas; below it the screen fills whatever pane it is given.
void main() {
  Future<double> childWidthAt(WidgetTester tester, double width, {double? minWidth}) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: minWidth == null
          ? const AdaptiveFrame(child: SizedBox.expand(key: Key('c')))
          : AdaptiveFrame(minWidth: minWidth, child: const SizedBox.expand(key: Key('c'))),
    ));
    return tester.getSize(find.byKey(const Key('c'))).width;
  }

  testWidgets('fills a medium window edge to edge', (tester) async {
    expect(await childWidthAt(tester, 900), closeTo(900, 0.5));
  });

  testWidgets('contains an expanded window at --content-max inside the hairlines', (tester) async {
    // 1024 minus the two 1px inline borders.
    expect(await childWidthAt(tester, 1280), closeTo(T.contentMax - 2, 0.5));
  });

  testWidgets('the shell pane threshold is the window threshold less the rail', (tester) async {
    // A 1024 window with the 72px rail leaves a 952 pane — still contained.
    expect(await childWidthAt(tester, 952, minWidth: 952), closeTo(952 - 2, 0.5));
    expect(await childWidthAt(tester, 951, minWidth: 952), closeTo(951, 0.5));
  });
}
