import 'package:app/balsm_app/tokens.dart';
import 'package:app/balsm_app/widgets/auth_fields.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A verification code reads left to right in every language: the first digit
/// lands in the leftmost box, Arabic included.
void main() {
  Future<void> pumpRow(WidgetTester tester, TextDirection screenDirection) => tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: screenDirection,
            child: const Scaffold(body: OtpBoxRow(code: '123', accent: Accent.violet)),
          ),
        ),
      );

  for (final direction in TextDirection.values) {
    testWidgets('the boxes run left to right on a ${direction.name} screen', (tester) async {
      await pumpRow(tester, direction);

      final x = [for (var i = 0; i < 6; i++) tester.getCenter(find.byType(OtpBox).at(i)).dx];
      expect(x, orderedEquals([...x]..sort()), reason: 'box 1 is the leftmost, box 6 the rightmost');
      for (final (i, digit) in ['1', '2', '3'].indexed) {
        expect(
          tester.getCenter(find.text(digit)).dx,
          closeTo(x[i], 0.5),
          reason: 'digit ${i + 1} sits in box ${i + 1}',
        );
      }
    });
  }
}
