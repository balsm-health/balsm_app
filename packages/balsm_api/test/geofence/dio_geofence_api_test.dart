import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('parses enveloped denied_codes', () async {
    final adapter = FakeHttpAdapter(
        (_) => jsonResponse('{"data": {"denied_codes": ["kp", " ir "]}}'));
    final res = await DioGeofenceApi(dio: fakeDio(adapter)).getDeniedCountries();
    expect(adapter.requests.single.path, '/geofence/denied-countries');
    expect(res.deniedCodes, ['kp', ' ir ']); // raw — module normalizes
  });

  test('falls back to flat body when data missing (legacy tolerance)', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"denied_codes": ["kp"]}'));
    final res = await DioGeofenceApi(dio: fakeDio(adapter)).getDeniedCountries();
    expect(res.deniedCodes, ['kp']);
  });

  test('non-list denied_codes → empty', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"data": {"denied_codes": "oops"}}'));
    final res = await DioGeofenceApi(dio: fakeDio(adapter)).getDeniedCountries();
    expect(res.deniedCodes, isEmpty);
  });
}
