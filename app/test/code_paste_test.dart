import 'package:app/balsm_app/widgets/auth_fields.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reading a pasted or suggested one-time code (#99).
void main() {
  group('codeFromText', () {
    test('a bare code reads as itself', () => expect(codeFromText('123456'), '123456'));

    test('a spaced or dashed code reads without the gap', () {
      expect(codeFromText('123 456'), '123456');
      expect(codeFromText('123-456'), '123456');
    });

    test('the code is found inside a sentence', () => expect(codeFromText('Your code is 123456.'), '123456'));

    test('other numbers in the message do not leak into the code',
        () => expect(codeFromText('Valid for 10 minutes. Your code: 482913'), '482913'));

    test('a partial code is kept', () => expect(codeFromText('12'), '12'));

    test('more than six loose digits are not guessed at', () => expect(codeFromText('12345678'), isNull));

    test('nothing usable is null', () {
      expect(codeFromText(null), isNull);
      expect(codeFromText('no digits here'), isNull);
    });
  });

  group('CodeInputFormatter', () {
    const f = CodeInputFormatter();
    TextEditingValue v(String text) =>
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));

    test('a typed digit is kept', () => expect(f.formatEditUpdate(v('12'), v('123')).text, '123'));

    test('a typed letter is refused', () => expect(f.formatEditUpdate(v('12'), v('12a')).text, '12'));

    test('a seventh digit is refused', () => expect(f.formatEditUpdate(v('123456'), v('1234567')).text, '123456'));

    test('a pasted message becomes its code', () {
      expect(f.formatEditUpdate(v(''), v('Your code is 123 456')).text, '123456');
    });

    test('a paste after typed digits replaces them with the pasted code', () {
      expect(f.formatEditUpdate(v('12'), v('12654321')).text, '654321');
    });

    test('a paste with no code leaves the field as it was',
        () => expect(f.formatEditUpdate(v('12'), v('12hello')).text, '12'));
  });
}
