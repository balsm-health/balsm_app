import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assets = [
    'assets/body/male_front.svg',
    'assets/body/male_back.svg',
    'assets/body/female_front.svg',
    'assets/body/female_back.svg',
    'assets/body/muscles_front.svg',
    'assets/body/muscles_back.svg',
    'assets/body/bones_front.svg',
    'assets/body/bones_back.svg',
    'assets/body/joints_front.svg',
    'assets/body/joints_back.svg',
    'assets/body/tendons_front.svg',
    'assets/body/tendons_back.svg',
    'assets/body/nerves_front.svg',
    'assets/body/nerves_back.svg',
    'assets/body/organs_front.svg',
    'assets/body/organs_back.svg',
  ];

  for (final asset in assets) {
    testWidgets('$asset parses and renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 200,
              height: 384,
              child: SvgPicture.asset(asset),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
