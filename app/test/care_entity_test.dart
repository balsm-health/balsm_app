import 'package:app/balsm_app/care/care_entity.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('pick', () {
    test('falls back to the other language when one side is missing', () {
      // Directory data carries ONE name per place — Overture has no bilingual
      // pair — so an Arabic-only pharmacy must still render in the English UI
      // under its real name rather than as a blank row.
      const arabicOnly = (en: '', ar: 'صيدليات الشلقاني');
      expect(pick(arabicOnly, ar: false), 'صيدليات الشلقاني');
      expect(pick(arabicOnly, ar: true), 'صيدليات الشلقاني');

      const englishOnly = (en: 'Cairo Scan Center', ar: '');
      expect(pick(englishOnly, ar: true), 'Cairo Scan Center');
      expect(pick(englishOnly, ar: false), 'Cairo Scan Center');
    });

    test('prefers the requested language when both exist', () {
      const both = (en: 'Misr Pharmacies', ar: 'صيدليات مصر');
      expect(pick(both, ar: true), 'صيدليات مصر');
      expect(pick(both, ar: false), 'Misr Pharmacies');
    });
  });

  group('CareEntity.fromResponse', () {
    test('maps absent fields to empty strings, never invented values', () {
      final e = CareEntity.fromResponse(const CareEntityResponse(
        id: 'x',
        type: 'pharmacy',
        nameEn: 'Fixture Pharmacy',
        lat: 30.0,
        lng: 31.2,
      ));

      expect(e.name.ar, '');
      expect(e.hours, '', reason: 'no source supplies opening hours');
      expect(e.rating, '', reason: 'no lawful free source supplies ratings');
      expect(e.phone, '');
      expect(e.type, CareEntityType.pharmacy);
    });
  });

  group('CareEntityType', () {
    test('dentist is its own type, not a clinic', () {
      expect(CareEntityType.fromWire('dentist'), CareEntityType.dentist);
      expect(CareEntityType.dentist, isNot(CareEntityType.clinic));
    });

    test('unknown wire values fall back to clinic rather than throwing', () {
      expect(CareEntityType.fromWire('veterinarian'), CareEntityType.clinic);
    });
  });

  group('CareSearch', () {
    test('sends a type server-side only when exactly one is ticked', () {
      // The endpoint filters on a single type; an empty set means "all", and
      // several ticked types stay a client-side union.
      expect(const CareSearch().wireType, isNull);
      expect(const CareSearch(types: {CareEntityType.dentist}).wireType, 'dentist');
      expect(
        const CareSearch(types: {CareEntityType.dentist, CareEntityType.pharmacy}).wireType,
        isNull,
      );
    });

    test('copyWith can clear the map focus back to "near me"', () {
      const focused = CareSearch(focus: LatLng(30.1, 31.3));
      expect(focused.copyWith(clearFocus: true).focus, isNull);
      expect(focused.copyWith(text: 'lab').focus, isNotNull, reason: 'unrelated edits keep the focus');
    });
  });
}
