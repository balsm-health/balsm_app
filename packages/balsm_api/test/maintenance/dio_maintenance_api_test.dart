import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('GETs /api/v1/maintenance and parses the envelope', () async {
    final adapter = FakeHttpAdapter(
      (_) => jsonResponse(
          '{"data": {"mode": "readonly", "message": " Back soon ", "ends_at": "2025-01-01T02:00:00+00:00", '
          '"updated_at": "2025-01-01T00:00:00+00:00"}}'),
    );

    final res = await DioMaintenanceApi(net: fakeNet(adapter)).getStatus();

    expect(adapter.requests.single.path, '/api/v1/maintenance');
    expect(adapter.requests.single.method, 'GET');
    expect(res.mode, 'readonly');
    expect(res.message, 'Back soon');
    expect(res.endsAt, DateTime.utc(2025, 1, 1, 2));
    expect(res.updatedAt, DateTime.utc(2025));
  });

  test('null message / end time stay null; blank message is null', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"data": {"mode": "BLOCK", "message": "  ", "ends_at": null}}'));

    final res = await DioMaintenanceApi(net: fakeNet(adapter)).getStatus();

    expect((res.mode, res.message, res.endsAt), ('block', null, null));
  });

  test('a server error surfaces as ApiException', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 503));

    expect(DioMaintenanceApi(net: fakeNet(adapter)).getStatus(), throwsA(isA<ApiException>()));
  });
}
