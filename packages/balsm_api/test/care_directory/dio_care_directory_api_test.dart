import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('nearby parses snake_case list + sends lat/lng/type query', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": [{'
        '"id":"e1","type":"pharmacy","name_en":"El-Ezaby","name_ar":"العزبي",'
        '"address_en":"Tahrir Sq","address_ar":"التحرير","lat":30.04,"lng":31.23,'
        '"hours":"24/7","phone":"+20 2 2574 3210","distance_km":0.4,"rating":4.5}]}'));
    final api = DioCareDirectoryApi(net: fakeNet(adapter));

    final res = await api.nearby(const NearbyCareQuery(lat: 30.0, lng: 31.2, type: 'pharmacy'));

    final req = adapter.requests.single;
    expect(req.path, '/care/entities');
    expect(req.queryParameters['lat'], 30.0);
    expect(req.queryParameters['lng'], 31.2);
    expect(req.queryParameters['type'], 'pharmacy');
    expect(res, hasLength(1));
    final e = res.single;
    expect(e.id, 'e1');
    expect(e.type, 'pharmacy');
    expect(e.nameAr, 'العزبي');
    expect(e.lat, 30.04);
    expect(e.distanceKm, 0.4);
    expect(e.rating, 4.5);
  });

  test('nearby omits null query params + trims q', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": []}'));
    await DioCareDirectoryApi(net: fakeNet(adapter)).nearby(const NearbyCareQuery(lat: 1, lng: 2, query: '  '));

    final q = adapter.requests.single.queryParameters;
    expect(q['lat'], 1.0);
    expect(q.containsKey('type'), isFalse);
    expect(q.containsKey('radius_km'), isFalse);
    expect(q.containsKey('q'), isFalse); // blank query dropped
  });

  test('packs sends lang and parses basemap/places pair', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": [{'
        '"id":"cairo","name":"Cairo","bounds":[31.21,29.75,31.91,30.32],'
        '"basemap":{"version":"20260913","size_bytes":27145146,'
        '"sha256":"0372f6996c9435ff7e98d774aa11bb22cc33dd44ee55ff66007788990011aabb",'
        '"url":"https://cdn.balsm.health/packs/cairo-20260913.pmtiles","count":null},'
        '"places":{"version":"20260914","size_bytes":1051648,'
        '"sha256":"0372f6996c9435ff7e98d774aa11bb22cc33dd44ee55ff66007788990011aabb",'
        '"url":"https://cdn.balsm.health/places/cairo-20260914.ndjson.gz","count":10920}'
        '}]}'));
    final api = DioCareDirectoryApi(net: fakeNet(adapter));

    final res = await api.packs(const MapPacksQuery(lang: 'ar'));

    final req = adapter.requests.single;
    expect(req.path, '/care/packs');
    expect(req.queryParameters['lang'], 'ar');
    final pack = res.single;
    expect(pack.id, 'cairo');
    expect(pack.name, 'Cairo');
    expect(pack.bounds, [31.21, 29.75, 31.91, 30.32]);
    expect(pack.basemap.version, '20260913');
    expect(pack.basemap.count, isNull);
    expect(pack.places.count, 10920);
  });
}
