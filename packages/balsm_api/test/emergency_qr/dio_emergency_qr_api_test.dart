import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('mint posts snake_case body and parses token envelope', () async {
    final adapter = FakeHttpAdapter((options) => jsonResponse(
        '{"data": {"token_id": "jti-1", "expires_at": "2026-07-02T10:00:00Z"}, "error": null}'));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    final res = await api.mint(
        const MintQrRequest(ciphertextBase64: 'abc=', ttlSeconds: 900));

    expect(adapter.requests.single.path, '/emergency-qr/mint');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data,
        {'ciphertext_base64': 'abc=', 'ttl_seconds': 900});
    expect(res.tokenId, 'jti-1');
    expect(res.expiresAt, DateTime.parse('2026-07-02T10:00:00Z'));
  });

  test('mint throws ApiException on HTTP error', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 401));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));
    expect(
      () => api.mint(const MintQrRequest(ciphertextBase64: 'x', ttlSeconds: 1)),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('resolve GETs token path and surfaces nullable ciphertext', () async {
    final adapter = FakeHttpAdapter((_) =>
        jsonResponse(jsonEncode({'data': {'ciphertext_base64': null}})));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    final res = await api.resolve('jti-9');

    expect(adapter.requests.single.path, '/emergency-qr/resolve/jti-9');
    expect(res.ciphertextBase64, isNull);
  });

  test('revoke posts token_id and returns void', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    await api.revoke(const RevokeQrRequest(tokenId: 'jti-9'));

    expect(adapter.requests.single.data, {'token_id': 'jti-9'});
  });
}
