import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('listSessions parses envelope list with UTC dates', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('''
      {"data": [{
        "id": "s1", "device_id": "d1", "device_label": "iPhone",
        "device_type": "ios", "first_seen_at": "2026-01-01T00:00:00+02:00",
        "last_activity_at": "2026-01-02T00:00:00Z",
        "revoked_at": null, "is_current": true
      }], "error": null}'''));
    final api = DioSessionsApi(net: fakeNet(adapter));

    final sessions = await api.listSessions();

    expect(adapter.requests.single.path, '/sessions');
    expect(sessions, hasLength(1));
    expect(sessions.first.id, 's1');
    expect(sessions.first.firstSeenAt.isUtc, isTrue);
    expect(sessions.first.revokedAt, isNull);
    expect(sessions.first.isCurrent, isTrue);
  });

  test('listSessions throws fromEnvelope ApiException on error body', () {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null, "error": {"message": "boom"}}'));
    final api = DioSessionsApi(net: fakeNet(adapter));
    expect(
      api.listSessions(),
      throwsA(isA<ApiException>()
          .having((e) => e.fromEnvelope, 'fromEnvelope', isTrue)
          .having((e) => e.serverMessage, 'serverMessage', 'boom')),
    );
  });

  test('revokeSession DELETEs the session path', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    await DioSessionsApi(net: fakeNet(adapter)).revokeSession('s9');
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/sessions/s9');
  });

  test('revokeAllSessions parses revoked_count with 0 default', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": {"revoked_count": 3}}'));
    final res = await DioSessionsApi(net: fakeNet(adapter)).revokeAllSessions();
    expect(res.revokedCount, 3);

    final adapter2 = FakeHttpAdapter((_) => jsonResponse('{"data": {}}'));
    final res2 = await DioSessionsApi(net: fakeNet(adapter2)).revokeAllSessions();
    expect(res2.revokedCount, 0);
  });
}
