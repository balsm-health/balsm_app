import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart' show ResponseBody;
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

const _link = '''
{"data": {
  "id": "00000000-0000-0000-0000-0000000000a1",
  "relation": "daughter",
  "status": "Linked",
  "direction": "incoming",
  "other_account_id": "00000000-0000-0000-0000-000000000002",
  "other_display_name": "Test Parent",
  "other_handle": "test_parent",
  "other_public_key": "cHVibGlj",
  "card_shared_by_me": true,
  "card_shared_with_me": false,
  "created_at": "2026-10-01T12:00:00Z",
  "updated_at": "2026-10-02T12:00:00Z"
}, "error": null}''';

const _row = '''{
  "id": "00000000-0000-0000-0000-0000000000a1",
  "relation": "son",
  "status": "pending",
  "other_display_name": "Test Parent",
  "created_at": "2026-10-01T12:00:00Z"
}''';

void main() {
  const id = '00000000-0000-0000-0000-0000000000a1';

  test('create posts id, jti, relation and public_key', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": {"id": "$id"}, "error": null}', status: 201));

    await DioFamilyLinksApi(net: fakeNet(adapter)).create(
      const CreateFamilyLinkRequest(id: id, jti: 'jti-1', relation: 'daughter', publicKey: 'cHVi'),
    );

    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/api/v1/family-links');
    expect(req.data, {'id': id, 'jti': 'jti-1', 'relation': 'daughter', 'public_key': 'cHVi'});
  });

  test('create surfaces a 404 for an unknown jti', () async {
    final adapter = FakeHttpAdapter(
      (_) => jsonResponse('{"data": null, "error": {"code": "not_found", "message": "x"}}', status: 404),
    );

    expect(
      () => DioFamilyLinksApi(net: fakeNet(adapter)).create(
        const CreateFamilyLinkRequest(id: id, jti: 'jti-1', relation: 'son', publicKey: 'k'),
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('incoming sends the status filter and reads a bare list', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": [$_row], "error": null}'));

    final rows = await DioFamilyLinksApi(net: fakeNet(adapter)).incoming(status: 'pending');

    expect(adapter.requests.single.path, '/api/v1/family-links/incoming');
    expect(adapter.requests.single.queryParameters['status'], 'pending');
    expect(rows.single.direction, 'incoming');
    expect(rows.single.relation, 'son');
    expect(rows.single.otherDisplayName, 'Test Parent');
  });

  test('outgoing reads a paged list from data.items', () async {
    final adapter = FakeHttpAdapter(
      (_) => jsonResponse('{"data": {"items": [$_row], "total_count": 1}, "error": null}'),
    );

    final rows = await DioFamilyLinksApi(net: fakeNet(adapter)).outgoing();

    expect(adapter.requests.single.path, '/api/v1/family-links/outgoing');
    expect(rows.single.direction, 'outgoing');
    expect(rows.single.status, 'pending');
  });

  test('get parses every field, lower-casing the status', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(_link));

    final link = await DioFamilyLinksApi(net: fakeNet(adapter)).get(id);

    expect(adapter.requests.single.path, '/api/v1/family-links/$id');
    expect(link.status, 'linked');
    expect(link.direction, 'incoming');
    expect(link.otherAccountId, '00000000-0000-0000-0000-000000000002');
    expect(link.otherPublicKey, 'cHVibGlj');
    expect(link.cardSharedByMe, isTrue);
    expect(link.cardSharedWithMe, isFalse);
    expect(link.updatedAt, DateTime.utc(2026, 10, 2, 12));
  });

  test('approve posts the public key; decline posts no body', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(_link));
    final api = DioFamilyLinksApi(net: fakeNet(adapter));

    await api.approve(id, const FamilyLinkKeyRequest(publicKey: 'cHVi'));
    await api.decline(id);

    expect(adapter.requests[0].path, '/api/v1/family-links/$id/approve');
    expect(adapter.requests[0].data, {'public_key': 'cHVi'});
    expect(adapter.requests[1].path, '/api/v1/family-links/$id/decline');
    expect(adapter.requests[1].method, 'POST');
  });

  test('delete treats 404 as already gone', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 404));

    await DioFamilyLinksApi(net: fakeNet(adapter)).delete(id);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/api/v1/family-links/$id');
  });

  test('putKeys and putCard send snake_case bodies', () async {
    final adapter = FakeHttpAdapter((_) => ResponseBody.fromString('', 204));
    final api = DioFamilyLinksApi(net: fakeNet(adapter));

    await api.putKeys(id, const FamilyLinkKeyRequest(publicKey: 'cHVi'));
    await api.putCard(
      id,
      const PutSealedCardRequest(version: 7, ephemeralPublicKey: 'ZXBr', nonce: 'bm9uY2U=', ciphertext: 'Y3Q='),
    );

    expect(adapter.requests[0].method, 'PUT');
    expect(adapter.requests[0].path, '/api/v1/family-links/$id/keys');
    expect(adapter.requests[1].path, '/api/v1/family-links/$id/card');
    expect(adapter.requests[1].data, {
      'version': 7,
      'ephemeral_public_key': 'ZXBr',
      'nonce': 'bm9uY2U=',
      'ciphertext': 'Y3Q=',
    });
  });

  test('putCard surfaces a 409 for a stale version', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"error": {"code": "stale_version"}}', status: 409));

    expect(
      () => DioFamilyLinksApi(net: fakeNet(adapter))
          .putCard(id, const PutSealedCardRequest(version: 1, ephemeralPublicKey: 'a', nonce: 'b', ciphertext: 'c')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
  });

  test('getCard parses the sealed card and maps 404 to null', () async {
    var status = 200;
    final adapter = FakeHttpAdapter((_) => jsonResponse(
          '{"data": {"version": 3, "ephemeral_public_key": "ZXBr", "nonce": "bg==", "ciphertext": "Y3Q=", '
          '"updated_at": "2026-10-03T08:00:00Z"}, "error": null}',
          status: status,
        ));
    final api = DioFamilyLinksApi(net: fakeNet(adapter));

    final card = await api.getCard(id);
    status = 404;
    final none = await api.getCard(id);

    expect(adapter.requests.first.path, '/api/v1/family-links/$id/card');
    expect(card!.version, 3);
    expect(card.ephemeralPublicKey, 'ZXBr');
    expect(card.updatedAt, DateTime.utc(2026, 10, 3, 8));
    expect(none, isNull);
  });

  test('deleteCard treats 404 as nothing shared', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 404));

    await DioFamilyLinksApi(net: fakeNet(adapter)).deleteCard(id);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/api/v1/family-links/$id/card');
  });
}
