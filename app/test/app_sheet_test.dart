import 'package:app/balsm_app/kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// `showAppSheet` — app.css `.app-sheet` in both placements.
///
/// Compact windows keep the bottom sheet. From the medium window class the
/// same body is a centred dialog: `min(460px, 100% − 48px)` wide (640 for the
/// `--lg` forms), and `.sheet-grab` is hidden, so a body never has to know
/// which presentation it landed in.
void main() {
  Future<void> open(WidgetTester tester, Size window, {SheetSize size = SheetSize.md}) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppSheet<void>(
            context,
            size: size,
            builder: (_) => Container(
              key: const Key('body'),
              color: Colors.white,
              width: double.infinity,
              height: 200,
              child: const Column(mainAxisSize: MainAxisSize.min, children: [SheetGrab()]),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('compact: a bottom sheet, drag pill shown', (tester) async {
    await open(tester, const Size(390, 844));
    final body = tester.getRect(find.byKey(const Key('body')));
    expect(body.bottom, closeTo(844, 0.5), reason: 'sheet must sit on the bottom edge');
    expect(body.width, closeTo(390, 0.5));
    expect(tester.getSize(find.byType(SheetGrab)).height, 4);
  });

  testWidgets('medium: a centred 460px dialog, drag pill hidden', (tester) async {
    await open(tester, const Size(834, 1194));
    final body = tester.getRect(find.byKey(const Key('body')));
    expect(body.width, closeTo(460, 0.5));
    expect(body.center.dx, closeTo(834 / 2, 0.5));
    expect(body.center.dy, closeTo(1194 / 2, 0.5));
    expect(tester.getSize(find.byType(SheetGrab)), Size.zero);
  });

  testWidgets('the large variant widens to 640', (tester) async {
    await open(tester, const Size(1280, 800), size: SheetSize.lg);
    expect(tester.getRect(find.byKey(const Key('body'))).width, closeTo(640, 0.5));
  });

  testWidgets('the dialog keeps a 24px gutter each side on a narrow medium window', (tester) async {
    // `min(640px, 100% − 48px)`: at the medium threshold the large variant is
    // wider than the window allows, so the gutter wins.
    await open(tester, const Size(600, 900), size: SheetSize.lg);
    expect(tester.getRect(find.byKey(const Key('body'))).width, closeTo(600 - 48, 0.5));
  });

  testWidgets('pop from the body closes either presentation', (tester) async {
    for (final window in const [Size(390, 844), Size(834, 1194)]) {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSheet<void>(
              context,
              builder: (ctx) => TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('close')),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('close'), findsOneWidget);
      await tester.tap(find.text('close'));
      await tester.pumpAndSettle();
      expect(find.text('close'), findsNothing, reason: 'window $window');
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
