import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ValueObject equality is type-strict', () {
    test('same type + props → equal; different type → not', () {
      expect(CurrencyCode('EGP'), CurrencyCode.egp);
      expect(CurrencyCode('EGP').hashCode, CurrencyCode.egp.hashCode);
      // A CurrencyCode and a CountryCode both "EG"-ish are never equal.
      expect(CurrencyCode('EGP') == CountryCode.fromCode('EG'), isFalse);
    });
  });

  group('CurrencyCode', () {
    test('known currencies carry minor-unit digits', () {
      expect(CurrencyCode.egp.minorUnitDigits, 2);
      expect(CurrencyCode.egp.minorUnitsPerMajor, 100);
      expect(CurrencyCode.kwd.minorUnitDigits, 3); // Kuwaiti dinar
      expect(CurrencyCode.kwd.minorUnitsPerMajor, 1000);
    });

    test('unknown but well-formed code defaults to 2 digits', () {
      final c = CurrencyCode('xyz');
      expect(c.value, 'XYZ');
      expect(c.minorUnitDigits, 2);
    });

    test('malformed code throws', () {
      expect(() => CurrencyCode('E1'), throwsArgumentError);
    });
  });

  group('Money respects currency precision', () {
    test('EGP is 2-decimal', () {
      final m = Money.fromMajor(12.5, CurrencyCode.egp);
      expect(m.minorUnits, 1250);
      expect(m.amount, 12.5);
      expect(m.toString(), 'EGP 12.50');
    });

    test('KWD is 3-decimal (would round wrong on a hard-coded /100)', () {
      final m = Money.fromMajor(1.5, CurrencyCode.kwd);
      expect(m.minorUnits, 1500);
      expect(m.amount, 1.5);
      expect(m.toString(), 'KWD 1.500');
    });

    test('add rejects currency mismatch', () {
      final egp = Money.fromMajor(1, CurrencyCode.egp);
      final sar = Money.fromMajor(1, CurrencyCode.sar);
      expect(() => egp + sar, throwsArgumentError);
      expect((egp + Money.fromMajor(2, CurrencyCode.egp)).minorUnits, 300);
    });
  });

  group('LanguageCode', () {
    test('keeps facts const: endonym + rtl', () {
      expect(LanguageCode.ar.nativeName, 'العربية'); // endonym = fact
      expect(LanguageCode.ar.isRtl, isTrue);
      expect(LanguageCode.en.isRtl, isFalse);
    });

    test('toTag composes a BCP-47 tag', () {
      expect(LanguageCode.ar.toTag('eg'), 'ar-EG');
      expect(LanguageCode.ar.toTag(), 'ar');
    });
  });

  group('CountryCode reference hub (structural facts only)', () {
    test('exposes dial code + currency, no localized strings', () {
      final eg = CountryCode.fromCode('eg');
      expect(eg.dialCode, '+20');
      expect(eg.currency, CurrencyCode.egp);
      expect(eg.defaultTimezone, 'Africa/Cairo');
      expect(eg.isKnown, isTrue);
    });

    test('unlisted country gets neutral defaults', () {
      final zz = CountryCode.fromCode('ZZ');
      expect(zz.isKnown, isFalse);
      expect(zz.dialCode, '');
      expect(zz.currency, CurrencyCode.usd);
    });
  });

  group('localized names resolve from the i69n bundle (extension)', () {
    const catalog = TranslationCatalog();

    test('country name + demonym per locale', () {
      final eg = CountryCode.fromCode('EG');
      expect(eg.name(catalog, locale: 'en'), 'Egypt');
      expect(eg.name(catalog, locale: 'ar'), 'مصر');
      expect(eg.demonym(catalog, locale: 'en'), 'Egyptian');
      expect(eg.demonym(catalog, locale: 'ar'), 'مصري');
    });

    test('language name in the UI locale (distinct from endonym)', () {
      expect(LanguageCode.ar.name(catalog, locale: 'en'), 'Arabic');
      expect(LanguageCode.ar.name(catalog, locale: 'ar'), 'العربية');
    });

    test('nationality demonym', () {
      final n = Nationality.ofCode('EG');
      expect(n.demonym(catalog, locale: 'en'), 'Egyptian');
      expect(n, Nationality.ofCode('eg'));
    });

    test('unlisted country falls back to the ISO code, not a bare key', () {
      final zz = CountryCode.fromCode('ZZ');
      expect(zz.name(catalog, locale: 'en'), 'ZZ');
    });
  });

  group('PhoneNumber', () {
    final eg = CountryCode.fromCode('EG');

    test('normalizes formatting and leading zero', () {
      final r = PhoneNumber.create(country: eg, raw: '0100 123 4567');
      expect(r.isSuccess, isTrue);
      final p = (r as AppSuccess<PhoneNumber>).data;
      expect(p.nationalNumber, '1001234567');
      expect(p.e164, '+201001234567');
    });

    test('maps Arabic-Indic and Persian digits to Western (FR-213)', () {
      final r = PhoneNumber.create(country: eg, raw: '٠١٠٠١٢٣٤٥٦٧');
      expect(r.isSuccess, isTrue);
      expect((r as AppSuccess<PhoneNumber>).data.nationalNumber, '1001234567');
    });

    test('strips a pasted +dialcode prefix', () {
      final r = PhoneNumber.create(country: eg, raw: '+20 100 1234567');
      expect((r as AppSuccess<PhoneNumber>).data.nationalNumber, '1001234567');
    });

    test('returns failure codes, not localized text', () {
      expect(
        PhoneNumber.create(country: eg, raw: '   ').error.message,
        'phone.empty',
      );
      expect(
        PhoneNumber.create(country: eg, raw: '12').error.message,
        'phone.too_short',
      );
      expect(
        PhoneNumber.create(country: eg, raw: '1234567890123456').error.message,
        'phone.too_long',
      );
    });

    test('tryParse recovers country from E.164', () {
      final p = PhoneNumber.tryParse('+201001234567');
      expect(p, isNotNull);
      expect(p!.country.value, 'EG');
      expect(p.nationalNumber, '1001234567');
      expect(PhoneNumber.tryParse('nonsense'), isNull);
    });

    test('display groups digits, phone stays LTR', () {
      final p = (PhoneNumber.create(country: eg, raw: '1001234567')
              as AppSuccess<PhoneNumber>)
          .data;
      expect(p.display(), '+20 100 123 456 7');
    });
  });
}
