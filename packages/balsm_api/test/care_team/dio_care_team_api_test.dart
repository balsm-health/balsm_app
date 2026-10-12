import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

const _row = '''
{"data": [{
  "id": "cp-1",
  "health_profile_id": "hp-1",
  "type": "doctor",
  "name": "Provider Alpha",
  "specialty": null, "phone": null, "phone2": null, "email": null,
  "clinic": null, "address": null, "map_url": null, "notes": null,
  "created_at": "2026-09-01T12:00:00Z",
  "updated_at": "2026-09-02T12:00:00Z",
  "is_deleted": false
}], "error": null}''';

void main() {
  test('pull sends health_profile_id and since as query parameters', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": [], "error": null}'));
    final api = DioCareTeamApi(net: fakeNet(adapter));

    await api.pull(healthProfileId: 'hp-1', since: DateTime.utc(2026, 9, 1, 12));

    expect(adapter.requests.single.path, '/care-team/providers');
    expect(adapter.requests.single.queryParameters['health_profile_id'], 'hp-1');
    expect(adapter.requests.single.queryParameters['since'], '2026-09-01T12:00:00.000Z');
  });

  test('pull omits since when null', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": [], "error": null}'));
    await DioCareTeamApi(net: fakeNet(adapter)).pull(healthProfileId: 'hp-1');

    expect(adapter.requests.single.queryParameters.containsKey('since'), isFalse);
  });

  test('pull parses a row with UTC timestamps', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(_row));

    final rows = await DioCareTeamApi(net: fakeNet(adapter)).pull(healthProfileId: 'hp-1');

    expect(rows, hasLength(1));
    expect(rows.single.id, 'cp-1');
    expect(rows.single.name, 'Provider Alpha');
    expect(rows.single.isDeleted, isFalse);
    expect(rows.single.updatedAt, DateTime.utc(2026, 9, 2, 12));
    expect(rows.single.updatedAt.isUtc, isTrue);
  });

  test('pull parses a tombstone', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(_row.replaceAll('"is_deleted": false', '"is_deleted": true')));

    final rows = await DioCareTeamApi(net: fakeNet(adapter)).pull(healthProfileId: 'hp-1');

    expect(rows.single.isDeleted, isTrue);
  });

  test('upsert posts snake_case body', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": {"id": "cp-1"}, "error": null}'));

    await DioCareTeamApi(net: fakeNet(adapter)).upsert(UpsertCareProviderRequest(
      id: 'cp-1',
      healthProfileId: 'hp-1',
      type: 'doctor',
      name: 'Provider Alpha',
      mapUrl: 'https://maps.example.test/x',
      createdAt: DateTime.utc(2026, 9, 1, 12),
    ));

    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/care-team/providers');
    final body = req.data as Map<String, dynamic>;
    expect(body['id'], 'cp-1');
    expect(body['health_profile_id'], 'hp-1');
    expect(body['map_url'], 'https://maps.example.test/x');
    expect(body['created_at'], '2026-09-01T12:00:00.000Z');
  });

  test('delete targets the id path', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));

    await DioCareTeamApi(net: fakeNet(adapter)).delete('cp-1');

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/care-team/providers/cp-1');
  });

  test('delete treats 404 as success — the row is already gone', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}', status: 404));

    await expectLater(DioCareTeamApi(net: fakeNet(adapter)).delete('cp-1'), completes);
  });

  test('delete rethrows a non-404 failure so the outbox retries', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}', status: 500));

    await expectLater(
      DioCareTeamApi(net: fakeNet(adapter)).delete('cp-1'),
      throwsA(isA<ApiException>()),
    );
  });
}
