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
}
