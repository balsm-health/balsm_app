import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/home_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app.css window-class layer, for the rules that are not the shell:
/// `.pad-top` / `.appbar` chrome allowances and the `.metric-grid` track
/// count. Thresholds come from the window, because the design hangs every
/// container query off `.app-body`.
void main() {
  Future<Size> renderAt(WidgetTester tester, Size window, Widget child, Key key, {EdgeInsets? padding}) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: window, padding: padding ?? EdgeInsets.zero),
        child: Directionality(textDirection: TextDirection.ltr, child: child),
      ),
    ));
    return tester.getSize(find.byKey(key));
  }

  group('PadTop', () {
    const padTop = Key('pad');
    Widget host() => const Column(children: [SizedBox(key: padTop, child: PadTop())]);

    testWidgets('clears the dynamic island on a phone', (tester) async {
      final size =
          await renderAt(tester, const Size(390, 844), host(), padTop, padding: const EdgeInsets.only(top: 59));
      expect(size.height, 59 + 6, reason: 'compact keeps a 6px breath under the island');
    });

    testWidgets('drops to the 20px allowance once the nav is a rail', (tester) async {
      final size = await renderAt(tester, const Size(834, 1194), host(), padTop);
      expect(size.height, 20);
    });

    testWidgets('still clears a real top inset at rail width', (tester) async {
      // The design measures 20px in a browser frame with no status bar; an
      // iPad reports one, and it must not be painted over.
      final size =
          await renderAt(tester, const Size(834, 1194), host(), padTop, padding: const EdgeInsets.only(top: 24));
      expect(size.height, 24);
    });

    testWidgets('reclaims vertical room in a short window', (tester) async {
      final size = await renderAt(tester, const Size(874, 402), host(), padTop);
      expect(size.height, 12, reason: 'the short rule is the later one in app.css');
    });
  });

  group('AppBarRow', () {
    const bar = Key('bar');

    testWidgets('tightens its bottom padding in a short window', (tester) async {
      Future<double> heightAt(Size window) async {
        final size = await renderAt(
          tester,
          window,
          // A Column so the row takes its natural height instead of the screen's.
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBarRow(key: bar, children: [SizedBox(height: 20, width: 20)])
            ],
          ),
          bar,
        );
        return size.height;
      }

      expect(await heightAt(const Size(390, 844)), 20 + 6 + 12);
      expect(await heightAt(const Size(874, 402)), 20 + 6 + 6);
    });
  });

  group('MetricGrid', () {
    Widget grid() => MetricGrid(
          tiles: [for (var i = 0; i < 4; i++) SizedBox(key: Key('t$i'), height: 40)],
        );

    Future<int> columnsAt(WidgetTester tester, Size window) async {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          // 20px page gutters, as every screen sets.
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: grid()),
        ),
      ));
      final top = tester.getRect(find.byKey(const Key('t0'))).top;
      return [for (var i = 0; i < 4; i++) tester.getRect(find.byKey(Key('t$i')))].where((r) => r.top == top).length;
    }

    testWidgets('stays two up on a phone', (tester) async {
      expect(await columnsAt(tester, const Size(402, 1200)), 2);
    });

    testWidgets('fills the wider column from the medium class', (tester) async {
      // 834 − 40 gutters = 794; (794 + 12) / 162 → 4 tracks.
      expect(await columnsAt(tester, const Size(834, 1194)), 4);
    });
  });
}
