import 'package:app/balsm_app/care/care_cache.dart';
import 'package:app/balsm_app/care/care_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

CareEntity _place(String id) => CareEntity(
      id: id,
      type: CareEntityType.pharmacy,
      position: const LatLng(30.0444, 31.2357),
      name: (en: 'Fixture $id', ar: ''),
      addr: (en: 'Fixture Street', ar: ''),
      hours: '',
      distance: '',
      rating: '',
      phone: '',
    );

void main() {
  group('CareDirectoryCache', () {
    test('returns a stored result and misses on an unknown key', () {
      final cache = CareDirectoryCache();
      cache.put('k1', [_place('a')]);

      expect(cache.get('k1')!.single.id, 'a');
      expect(cache.get('k2'), isNull);
    });

    test('expires entries past the TTL', () {
      var now = DateTime(2026, 1, 1, 12);
      final cache = CareDirectoryCache(ttl: const Duration(minutes: 10), clock: () => now);
      cache.put('k', [_place('a')]);

      now = now.add(const Duration(minutes: 9));
      expect(cache.get('k'), isNotNull, reason: 'still inside the TTL');

      now = now.add(const Duration(minutes: 2));
      expect(cache.get('k'), isNull, reason: 'past the TTL');
    });

    test('evicts the least recently used once full', () {
      final cache = CareDirectoryCache(maxEntries: 3);
      cache.put('a', [_place('a')]);
      cache.put('b', [_place('b')]);
      cache.put('c', [_place('c')]);

      // Touching 'a' must make 'b' the coldest, not 'a'.
      cache.get('a');
      cache.put('d', [_place('d')]);

      expect(cache.length, 3);
      expect(cache.get('b'), isNull, reason: 'b was least recently used');
      expect(cache.get('a'), isNotNull);
      expect(cache.get('c'), isNotNull);
      expect(cache.get('d'), isNotNull);
    });

    test('overwriting a key does not grow the cache', () {
      final cache = CareDirectoryCache(maxEntries: 2);
      cache.put('a', [_place('a1')]);
      cache.put('a', [_place('a2')]);

      expect(cache.length, 1);
      expect(cache.get('a')!.single.id, 'a2');
    });
  });

  group('careCacheKey', () {
    test('small pans collapse onto one key', () {
      // ~2m of drift. Rounding is what lets the device cache AND the server's
      // vary-by-query output cache hit at all.
      const a = LatLng(30.044412, 31.235711);
      const b = LatLng(30.044431, 31.235690);

      expect(careCacheKey(a, const CareSearch()), careCacheKey(b, const CareSearch()));
    });

    test('a real move produces a different key', () {
      const cairo = LatLng(30.0444, 31.2357);
      const alexandria = LatLng(31.2001, 29.9187);

      expect(careCacheKey(cairo, const CareSearch()), isNot(careCacheKey(alexandria, const CareSearch())));
    });

    test('every field that changes the response changes the key', () {
      const c = LatLng(30.0444, 31.2357);
      final base = careCacheKey(c, const CareSearch());

      expect(careCacheKey(c, const CareSearch(text: 'lab')), isNot(base));
      expect(careCacheKey(c, const CareSearch(types: {CareEntityType.dentist})), isNot(base));
      expect(careCacheKey(c, const CareSearch(radiusKm: 25)), isNot(base));
    });

    test('text is matched case- and padding-insensitively', () {
      const c = LatLng(30.0444, 31.2357);
      expect(
        careCacheKey(c, const CareSearch(text: '  Lab ')),
        careCacheKey(c, const CareSearch(text: 'lab')),
      );
    });

    test('multi-type selection shares one key, since the server sees no type', () {
      // wireType is null for several ticked types — the narrowing happens on the
      // device, so the SERVER response is the same and may be reused.
      const c = LatLng(30.0444, 31.2357);
      expect(
        careCacheKey(c, const CareSearch(types: {CareEntityType.dentist, CareEntityType.lab})),
        careCacheKey(c, const CareSearch(types: {CareEntityType.hospital, CareEntityType.store})),
      );
    });
  });
}
