import 'package:account/account.dart' show kHandleFormat;
import 'package:app/balsm_app/screens/family/health_log_form.dart' show formatMeasure, parseMeasure;
import 'package:app/balsm_app/widgets/auth_fields.dart';
import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every field-level regex in one place, exercised with realistic input:
/// what a patient actually types, pastes, or gets from an Arabic keyboard.
void main() {
  group('email (isPlausibleEmail)', () {
    test('accepts ordinary addresses', () {
      for (final e in ['a@b.co', 'first.last+tag@mail.example.com', 'محمد@مثال.مصر', ' padded@x.io ']) {
        expect(isPlausibleEmail(e), isTrue, reason: e);
      }
    });

    test('rejects what is not an address', () {
      for (final e in ['', 'plain', 'a@b', '@b.co', 'a@.co', 'a b@c.co', 'a@@b.co', 'a@b c.co']) {
        expect(isPlausibleEmail(e), isFalse, reason: e);
      }
    });
  });

  group('handle (kHandleFormat)', () {
    test('accepts 3-30 of a-z 0-9 _ .', () {
      for (final h in ['abc', 'a_b.c', 'user.name_01', 'a' * 30]) {
        expect(kHandleFormat.hasMatch(h), isTrue, reason: h);
      }
    });

    test('rejects short, long, uppercase, spaced or symbol handles', () {
      for (final h in ['ab', 'a' * 31, 'Abc', 'a b', 'a-b', 'a@b', 'عمر', '']) {
        expect(kHandleFormat.hasMatch(h), isFalse, reason: h);
      }
    });
  });

  group('one-time code', () {
    test('formatter accepts digits up to six and refuses the rest', () {
      const f = CodeInputFormatter();
      TextEditingValue v(String t) => TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
      expect(f.formatEditUpdate(v('12345'), v('123456')).text, '123456');
      expect(f.formatEditUpdate(v('123456'), v('1234567')).text, '123456');
      expect(f.formatEditUpdate(v('12'), v('12a')).text, '12');
    });

    test('Arabic-Indic digits typed on an Arabic keyboard are read as digits', () {
      expect(codeFromText('١٢٣٤٥٦'), '123456');
      expect(codeFromText('١٢٣ ٤٥٦'), '123456');
    });

    test('formatter lets an Arabic-Indic digit keystroke through as its Latin digit', () {
      const f = CodeInputFormatter();
      TextEditingValue v(String t) => TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
      expect(f.formatEditUpdate(v('12'), v('12٣')).text, '123');
    });
  });

  group('measurements', () {
    test('parseMeasure reads Latin, Arabic-Indic and comma/Arabic-decimal forms', () {
      expect(parseMeasure('72.5'), 72.5);
      expect(parseMeasure('72,5'), 72.5);
      expect(parseMeasure('٧٢٫٥'), 72.5);
      expect(parseMeasure('۷۲.۵'), 72.5);
      expect(parseMeasure('  98 '), 98);
    });

    test('parseMeasure is null for blank or unreadable text', () {
      for (final t in ['', '  ', 'abc', '1.2.3', '--']) {
        expect(parseMeasure(t), isNull, reason: t);
      }
    });

    test('formatMeasure drops only trailing zeros', () {
      expect(formatMeasure(100), '100');
      expect(formatMeasure(10.5), '10.5');
      expect(formatMeasure(9.85), '9.85');
      expect(formatMeasure(0), '0');
      expect(formatMeasure(120), '120');
    });
  });

  group('digits and recovery codes', () {
    test('toWesternDigits maps Arabic-Indic and Persian digits only', () {
      expect(toWesternDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
      expect(toWesternDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
      expect(toWesternDigits('a١b'), 'a1b');
    });

    test('recovery code normalisation strips separators and upper-cases', () {
      expect(RecoveryCode.normalize('abcd-efgh 1234'), 'ABCDEFGH1234');
    });
  });
}
