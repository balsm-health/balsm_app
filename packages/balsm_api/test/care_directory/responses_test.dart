import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

void main() {
  group('CareEntityResponse.fromJson', () {
    test('parses a row with no Arabic name, hours, phone or rating', () {
      // Overture supplies one name per place, has no hours or ratings field at
      // all, and omits a phone for ~8% of rows — so nulls here are the common
      // case, not an edge case. Casting these with `as String` would throw and
      // take the whole care directory down.
      final r = CareEntityResponse.fromJson(const {
        'id': 'fixture-1',
        'type': 'pharmacy',
        'name_en': 'Fixture Pharmacy',
        'name_ar': null,
        'address_en': 'Fixture Street',
        'address_ar': null,
        'lat': 30.0444,
        'lng': 31.2357,
        'hours': null,
        'phone': null,
        'distance_km': 0.6,
        'rating': null,
      });

      expect(r.nameEn, 'Fixture Pharmacy');
      expect(r.nameAr, isNull);
      expect(r.hours, isNull);
      expect(r.phone, isNull);
      expect(r.rating, isNull);
      expect(r.distanceKm, 0.6);
    });

    test('parses an Arabic-only row', () {
      final r = CareEntityResponse.fromJson(const {
        'id': 'fixture-2',
        'type': 'lab',
        'name_en': null,
        'name_ar': 'معمل الاختبار',
        'address_en': null,
        'address_ar': 'شارع الاختبار',
        'lat': 30.05,
        'lng': 31.23,
        'hours': null,
        'phone': null,
        'distance_km': null,
        'rating': null,
      });

      expect(r.nameEn, isNull);
      expect(r.nameAr, 'معمل الاختبار');
      expect(r.addressAr, 'شارع الاختبار');
    });

    test('parses a fully populated row', () {
      final r = CareEntityResponse.fromJson(const {
        'id': 'fixture-3',
        'type': 'dentist',
        'name_en': 'Fixture Dental Clinic',
        'name_ar': 'عيادة الاختبار للاسنان',
        'address_en': 'Fixture Street',
        'address_ar': 'شارع الاختبار',
        'lat': 30.046,
        'lng': 31.237,
        'hours': '09:00-21:00',
        'phone': '+201000000005',
        'distance_km': 1.2,
        'rating': 4.5,
      });

      expect(r.nameEn, 'Fixture Dental Clinic');
      expect(r.nameAr, 'عيادة الاختبار للاسنان');
      expect(r.hours, '09:00-21:00');
      expect(r.rating, 4.5);
    });
  });
}
