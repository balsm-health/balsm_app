import 'package:app/balsm_app/care/care_entity.dart';
import 'package:app/balsm_app/screens/map_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Nearby-care type filter — multi-select.
///
/// The design's dropdown single-selects; the app's multi-selects, so the set
/// semantics need pinning down. The load-bearing rule is that an empty set
/// means "All": otherwise unticking the last type would leave the map with
/// nothing to plot and no obvious way back.
CareEntity _entity(String id, CareEntityType type, {String en = 'Place', String ar = 'مكان'}) => CareEntity(
      id: id,
      type: type,
      position: const LatLng(30.0, 31.2),
      name: (en: en, ar: ar),
      addr: (en: '$en street', ar: 'شارع'),
      hours: '9–5',
      distance: '0.8 km',
      rating: '4.5',
      phone: '+20000000000',
    );

void main() {
  final all = [
    _entity('h', CareEntityType.hospital, en: 'Nile Hospital', ar: 'مستشفى النيل'),
    _entity('c', CareEntityType.clinic, en: 'Nour Clinic', ar: 'عيادة نور'),
    _entity('p', CareEntityType.pharmacy, en: 'Zahran Pharmacy', ar: 'صيدلية زهران'),
    _entity('l', CareEntityType.lab, en: 'City Lab', ar: 'معمل المدينة'),
    _entity('d', CareEntityType.dentist, en: 'Smile Dental', ar: 'عيادة الابتسامة للأسنان'),
  ];

  List<String> ids(List<CareEntity> r) => r.map((e) => e.id).toList();

  test('no types ticked shows everything', () {
    expect(ids(filterCareEntities(all, query: '', types: {})), ['h', 'c', 'p', 'l', 'd']);
  });

  test('dentist filters independently of clinic', () {
    // Dentistry is ~7.4k of the ~38k Egyptian directory — the second largest
    // category — so it is its own type rather than a slice of "Clinics".
    expect(ids(filterCareEntities(all, query: '', types: {CareEntityType.dentist})), ['d']);
    expect(ids(filterCareEntities(all, query: '', types: {CareEntityType.clinic})), ['c']);
  });

  test('one type narrows to that type', () {
    expect(ids(filterCareEntities(all, query: '', types: {CareEntityType.clinic})), ['c']);
  });

  test('several types are a union, not an intersection', () {
    final r = filterCareEntities(all, query: '', types: {CareEntityType.hospital, CareEntityType.lab});
    expect(ids(r), ['h', 'l']);
  });

  test('every type ticked matches the all-types result', () {
    final everything = filterCareEntities(all, query: '', types: CareEntityType.values.toSet());
    expect(ids(everything), ids(filterCareEntities(all, query: '', types: {})));
  });

  test('search composes with the type filter', () {
    final r = filterCareEntities(
      all,
      query: 'nile',
      types: {CareEntityType.hospital, CareEntityType.pharmacy},
    );
    expect(ids(r), ['h'], reason: 'the pharmacy matches the type but not the query');
  });

  test('a query outside the ticked types yields nothing', () {
    final r = filterCareEntities(all, query: 'zahran', types: {CareEntityType.lab});
    expect(r, isEmpty);
  });

  test('Arabic search matches the untouched query, not the lowercased one', () {
    expect(ids(filterCareEntities(all, query: 'صيدلية', types: {})), ['p']);
  });

  test('search is case- and padding-insensitive', () {
    expect(ids(filterCareEntities(all, query: '  CITY  ', types: {})), ['l']);
  });
}
