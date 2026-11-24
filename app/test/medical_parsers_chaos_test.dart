import 'dart:math';

import 'package:app/balsm_app/screens/family/health_log_form.dart' show formatMeasure, parseMeasure;
import 'package:app/balsm_app/widgets/auth_fields.dart';
import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hostile text through the medical-number parsers: whatever a patient pastes or
/// types — mixed scripts, invisible marks, emoji, absurd lengths — the parsers
/// return null or a finite number, never throw.
void main() {
  final rng = Random(7);

  final nasty = <String>[
    '', ' ', '\n', '\t', '--', '+', '.', ',', '٫', '٬', '1e5', '1E-9', '0x10', '1_000', '١٢٣', '۱۲۳', '१२३',
    '‏٧٢‏', '72​', '\u202E72', '٧٢٫٥', '72٫5', '72,5', '72.5.1', '1,2,3', '1.2,3', 'NaN', 'Infinity',
    '-Infinity', '٩٩٩٩٩٩٩٩٩٩٩٩٩٩٩٩٩٩٩٩', '9' * 400, '0' * 400, '😀', '72😀', 'seventy', "72'; DROP TABLE vitals;--",
    '<script>alert(1)</script>', '\u0000', '72\u0000', 'ｌ２３', '１２３', // full-width digits
  ];

  group('parseMeasure', () {
    test('every nasty string returns null or a finite non-NaN number, never throws', () {
      for (final t in nasty) {
        expect(() => parseMeasure(t), returnsNormally, reason: t);
        final v = parseMeasure(t);
        if (v != null) expect(v.isNaN, isFalse, reason: 'NaN from "$t"');
      }
    });

    test('2000 random strings never throw', () {
      const alphabet = '0123456789٠١٢٣٤٥٦٧٨٩۰۱۲۳.,٫-+eE ‏​😀abc';
      final chars = alphabet.runes.toList();
      for (var i = 0; i < 2000; i++) {
        final len = rng.nextInt(12);
        final t = String.fromCharCodes(List.generate(len, (_) => chars[rng.nextInt(chars.length)]));
        expect(() => parseMeasure(t), returnsNormally, reason: t);
      }
    });

    test('real readings survive decoration', () {
      expect(parseMeasure('٧٢٫٥'), 72.5);
      expect(parseMeasure(' 72,5 '), 72.5);
    });
  });

  group('formatMeasure', () {
    test('finite doubles format without exponent or crash', () {
      for (final v in [0.0, 0.004, 0.5, 9.85, 100.0, 120.0, 999.99, 12345.678]) {
        final s = formatMeasure(v);
        expect(s.contains('e'), isFalse, reason: '$v → $s');
        expect(double.parse(s), closeTo(v, 0.006), reason: '$v → $s');
      }
    });

    test('NaN and infinity do not throw', () {
      for (final v in [double.nan, double.infinity, double.negativeInfinity]) {
        expect(() => formatMeasure(v), returnsNormally);
      }
    });
  });

  group('one-time code', () {
    test('codeFromText never throws and only returns digits', () {
      for (final t in nasty) {
        expect(() => codeFromText(t), returnsNormally, reason: t);
        final c = codeFromText(t);
        if (c != null) expect(RegExp(r'^\d{1,6}$').hasMatch(c), isTrue, reason: '"$t" → "$c"');
      }
    });

    test('formatter keeps the field at most six ASCII digits for any edit', () {
      const f = CodeInputFormatter();
      TextEditingValue v(String t) => TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
      for (var i = 0; i < 2000; i++) {
        final old = String.fromCharCodes(List.generate(rng.nextInt(7), (_) => 0x30 + rng.nextInt(10)));
        final next = nasty[rng.nextInt(nasty.length)];
        final out = f.formatEditUpdate(v(old), v(old + next)).text;
        expect(RegExp(r'^\d{0,6}$').hasMatch(out), isTrue, reason: '"$old" + "$next" → "$out"');
      }
    });
  });

  group('digits', () {
    test('toWesternDigits is idempotent and keeps length', () {
      for (final t in nasty) {
        final once = toWesternDigits(t);
        expect(toWesternDigits(once), once, reason: t);
        expect(once.runes.length, t.runes.length, reason: t);
      }
    });
  });

  group('email', () {
    test('isPlausibleEmail never throws, even on huge or hostile input', () {
      for (final t in [...nasty, 'a@${'b.' * 5000}c', 'a' * 100000 + '@x.io']) {
        expect(() => isPlausibleEmail(t), returnsNormally);
      }
    });
  });
}
