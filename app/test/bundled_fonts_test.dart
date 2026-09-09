import 'dart:io';

import 'package:app/balsm_app/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// The design system self-hosts its type on purpose: "offline-default is
/// value #1 … nothing in the type stack touches the network at runtime".
/// These guard that the Flutter side keeps that promise — the app must not
/// regress to fetching brand faces from a CDN at launch.
void main() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;

  test('brand faces are declared as bundled assets, not fetched', () {
    final families =
        ((pubspec['flutter'] as YamlMap)['fonts'] as YamlList).map((f) => (f as YamlMap)['family'] as String).toSet();
    expect(
      families,
      containsAll(<String>['Montserrat', 'IBM Plex Sans', 'IBM Plex Sans Arabic', 'IBM Plex Mono']),
      reason: 'every family Typo names must ship with the app',
    );
  });

  test('every declared font file exists on disk', () {
    for (final family in (pubspec['flutter'] as YamlMap)['fonts'] as YamlList) {
      for (final f in (family as YamlMap)['fonts'] as YamlList) {
        final asset = (f as YamlMap)['asset'] as String;
        expect(File(asset).existsSync(), isTrue, reason: '$asset is declared but missing');
      }
    }
  });

  test('no runtime font fetching dependency remains', () {
    final deps = pubspec['dependencies'] as YamlMap;
    expect(deps.containsKey('google_fonts'), isFalse,
        reason: 'google_fonts fetches from fonts.gstatic.com at runtime, which '
            'breaks the offline-default promise the design system is built on');
    final kit = File('lib/balsm_app/kit.dart').readAsStringSync();
    expect(kit.contains('GoogleFonts'), isFalse);
  });

  test('Typo resolves the bundled families for both scripts', () {
    expect(Typo.body().fontFamily, 'IBM Plex Sans');
    expect(Typo.body(ar: true).fontFamily, 'IBM Plex Sans Arabic');
    expect(Typo.title().fontFamily, 'Montserrat');
    expect(Typo.title(ar: true).fontFamily, 'IBM Plex Sans Arabic');
    expect(Typo.num().fontFamily, 'IBM Plex Mono');
  });

  // `flutter test` substitutes a fixed-width test font for everything, so the
  // real file has to be loaded explicitly before glyph metrics mean anything.
  testWidgets('the variable wght axis is applied, not faux-bolded', (tester) async {
    const family = 'MontserratProbe';
    final bytes = File('assets/fonts/Montserrat-VariableFont_wght.ttf').readAsBytesSync();
    final loader = FontLoader(family)..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();

    double widthAt(FontWeight w) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Balsm health',
          style: TextStyle(fontFamily: family, fontSize: 26, fontWeight: w),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    final regular = widthAt(FontWeight.w400);
    final heavy = widthAt(FontWeight.w800);
    // A variable font whose axis is honoured gets wider as weight climbs. If the
    // engine ignored the axis both measurements would be identical.
    expect(heavy, greaterThan(regular),
        reason: 'wght axis not applied — headings would render at Regular '
            '(measured w400=$regular, w800=$heavy)');
  });
}
