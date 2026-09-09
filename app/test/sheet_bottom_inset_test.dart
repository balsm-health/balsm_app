import 'package:app/balsm_app/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bottom-sheet footer inset.
///
/// The design clears the home indicator explicitly — app.css ends its sheet
/// footers with `calc(env(safe-area-inset-bottom, 0px) + 24px)`. Every app
/// sheet used a flat pad instead, so on a notched phone the last control (the
/// primary CTA in the add-record, quick-log, prescriptions and storage sheets)
/// rendered underneath the home indicator, where iOS swallows the touch.
void main() {
  const notch = EdgeInsets.only(top: 62, bottom: 34);

  /// Reads the helper through a real element, the way the sheets call it.
  Future<double> inset(
    WidgetTester tester, {
    required MediaQueryData data,
    double? base,
  }) async {
    late double result;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: data,
        child: Builder(builder: (context) {
          result = base == null ? sheetBottomInset(context) : sheetBottomInset(context, base: base);
          return const SizedBox.shrink();
        }),
      ),
    ));
    return result;
  }

  testWidgets('adds the home-indicator inset to the sheet base padding', (tester) async {
    final value = await inset(tester, data: const MediaQueryData(padding: notch), base: 36);
    expect(value, 34 + 36);
  });

  testWidgets('defaults to the design\'s 38px .flow-foot base', (tester) async {
    final value = await inset(tester, data: const MediaQueryData(padding: notch));
    expect(value, 34 + 38);
  });

  testWidgets('collapses to the bare base on a device without a home indicator', (tester) async {
    final value = await inset(tester, data: const MediaQueryData(), base: 32);
    expect(value, 32);
  });

  testWidgets('lifts the body clear of an open keyboard', (tester) async {
    // With the keyboard up iOS reports the bottom padding as consumed, so the
    // two never double-count: the inset is the keyboard height plus the base.
    final value = await inset(
      tester,
      data: const MediaQueryData(
        padding: EdgeInsets.only(top: 62),
        viewInsets: EdgeInsets.only(bottom: 336),
      ),
      base: 36,
    );
    expect(value, 336 + 36);
  });

  testWidgets('keyboard and indicator insets both count when both are reported', (tester) async {
    final value = await inset(
      tester,
      data: const MediaQueryData(padding: notch, viewInsets: EdgeInsets.only(bottom: 300)),
      base: 34,
    );
    expect(value, 300 + 34 + 34);
  });
}
