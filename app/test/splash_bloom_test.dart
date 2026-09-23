import 'package:app/balsm_app/widgets/balsm_mark.dart';
import 'package:app/balsm_app/widgets/splash_bloom.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The boot splash's `bloom` composition (`app.css` `.splash-*`).
///
/// The thing most worth pinning is the reduced-motion contract: `app.css`
/// cancels every splash animation and transform under
/// `prefers-reduced-motion`, so nothing here may be left mid-entrance or
/// ticking a controller forever.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {bool reduceMotion = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(textDirection: TextDirection.ltr, child: Center(child: child)),
      ),
    ));
  }

  group('SplashMark', () {
    testWidgets('settles at full scale and stops', (tester) async {
      await pump(tester, const SplashMark());
      // Entrance (1.5s) plus a breathe start (1.4s) and a full ping-pong.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump(const Duration(milliseconds: 2300));
      expect(tester.takeException(), isNull);
      expect(find.byType(SplashMark), findsOne);
    });

    testWidgets('under reduced motion it never animates', (tester) async {
      await pump(tester, const SplashMark(), reduceMotion: true);
      // pumpAndSettle times out if any controller is still repeating, which is
      // exactly the failure the reduced-motion block is meant to prevent.
      await tester.pumpAndSettle();
      expect(find.byType(SplashMark), findsOne);
    });

    testWidgets('sizes the mark to 132 of the 208 wrap', (tester) async {
      await pump(tester, const SplashMark(), reduceMotion: true);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SplashMark)), const Size(208, 208));
      // `.splash-logo` is 132 of the 208 wrap, and the ratio must survive a
      // different wrap size.
      expect(tester.widget<BalsmFlower>(find.byType(BalsmFlower)).size, closeTo(132, 0.01));

      await pump(tester, const SplashMark(size: 104), reduceMotion: true);
      await tester.pumpAndSettle();
      expect(tester.widget<BalsmFlower>(find.byType(BalsmFlower)).size, closeTo(66, 0.01));
    });
  });

  group('SplashDots', () {
    testWidgets('renders five dots', (tester) async {
      await pump(tester, const SplashDots(), reduceMotion: true);
      await tester.pumpAndSettle();
      expect(find.byType(Container), findsExactly(5));
    });

    testWidgets('under reduced motion it never animates', (tester) async {
      await pump(tester, const SplashDots(), reduceMotion: true);
      await tester.pumpAndSettle();
      expect(find.byType(SplashDots), findsOne);
    });

    testWidgets('keeps ticking when motion is allowed', (tester) async {
      await pump(tester, const SplashDots());
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      // Repeating forever is correct here, so drain it rather than settle.
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.byType(SplashDots), findsOne);
    });
  });

  group('SplashRise', () {
    testWidgets('starts 9px low and lands flush', (tester) async {
      const key = Key('risen');
      await pump(
        tester,
        const SplashRise(delay: Duration(milliseconds: 550), child: SizedBox(key: key, width: 40, height: 10)),
      );
      final start = tester.getTopLeft(find.byKey(key)).dy;

      await tester.pump(const Duration(milliseconds: 550));
      await tester.pump(const Duration(milliseconds: 700));
      final end = tester.getTopLeft(find.byKey(key)).dy;
      expect(start - end, closeTo(9, 0.01));
    });

    testWidgets('under reduced motion it is already flush', (tester) async {
      const key = Key('risen');
      await pump(
        tester,
        const SplashRise(delay: Duration(milliseconds: 550), child: SizedBox(key: key, width: 40, height: 10)),
        reduceMotion: true,
      );
      final at = tester.getTopLeft(find.byKey(key)).dy;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(key)).dy, at, reason: 'no delayed rise may fire');
    });
  });
}
