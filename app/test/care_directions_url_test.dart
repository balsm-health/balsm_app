import 'package:app/balsm_app/care/care_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// The link behind the Directions button on a facility's map card.
///
/// It used to be built from `name.en`, and directory data carries one name per
/// place — `CareEntity.fromResponse` maps a missing English name to `''`. For
/// the many places the directory knows only in Arabic that made the URL a
/// search for an empty string, so Maps opened on nothing. The card's own
/// labels never had the bug because they go through `pick()`.
///
/// Coordinates avoid the question entirely: `position` is always a real
/// lat/lng, and a number needs no language.
void main() {
  CareEntity at(LatLng position, {String en = '', String ar = ''}) => CareEntity(
        id: 'e1',
        type: CareEntityType.pharmacy,
        position: position,
        name: (en: en, ar: ar),
        addr: (en: '', ar: ''),
        hours: '',
        distance: '',
        rating: '',
        phone: '',
      );

  test('routes to the facility coordinates, not its name', () {
    final url = careDirectionsUrl(at(const LatLng(30.0444, 31.2357), ar: 'صيدلية الشفاء'));

    expect(url, 'https://www.google.com/maps/dir/?api=1&destination=30.0444,31.2357');
  });

  test('a place the directory knows only in Arabic still gets a destination', () {
    // The case that was broken: en is empty, so the old URL ended in `query=`.
    final e = at(const LatLng(31.2001, 29.9187), ar: 'مستشفى الأمل');

    expect(e.name.en, isEmpty);
    expect(careDirectionsUrl(e), endsWith('destination=31.2001,29.9187'));
    expect(careDirectionsUrl(e), isNot(endsWith('=')));
  });

  test('asks for directions rather than a search', () {
    // The button says Directions; /search/ only finds the place.
    final url = careDirectionsUrl(at(const LatLng(1.5, 2.5)));

    expect(url, contains('/maps/dir/'));
    expect(url, isNot(contains('/maps/search/')));
    expect(url, contains('api=1'));
  });

  test('a southern or western facility keeps its sign', () {
    expect(careDirectionsUrl(at(const LatLng(-33.8688, -70.6693))), endsWith('destination=-33.8688,-70.6693'));
  });
}
