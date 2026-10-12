import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('mint posts server-contract snake_case body and parses token envelope', () async {
    final adapter = FakeHttpAdapter((options) =>
        jsonResponse('{"data": {"token_id": "jti-1", "expires_at": "2026-07-02T10:00:00Z"}, "error": null}'));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    final res = await api.mint(const MintQrRequest(ciphertextBase64: 'abc=', ttlSeconds: 900, profileEtag: 'e1'));

    expect(adapter.requests.single.path, '/emergency-qr/mint');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data, {'ciphertext': 'abc=', 'profile_etag': 'e1', 'ttl_seconds': 900});
    expect(res.tokenId, 'jti-1');
    expect(res.expiresAt, DateTime.parse('2026-07-02T10:00:00Z'));
  });

  test('mint of a permanent token surfaces null expiry', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"data": {"token_id": "jti-p", "expires_at": null}, "error": null}'));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    final res = await api.mint(const MintQrRequest(ciphertextBase64: 'abc=', ttlSeconds: 0, profileEtag: 'e1'));

    expect(res.tokenId, 'jti-p');
    expect(res.expiresAt, isNull);
  });

  test('mint throws ApiException on HTTP error', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 401));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));
    expect(
      () => api.mint(const MintQrRequest(ciphertextBase64: 'x', ttlSeconds: 1, profileEtag: 'e')),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });

  test('active GETs and parses the caller token', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(jsonEncode({
          'data': {'token_id': 'jti-2', 'expires_at': null, 'ttl_seconds': 0}
        })));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    final res = await api.active();

    expect(adapter.requests.single.path, '/emergency-qr/active');
    expect(res!.tokenId, 'jti-2');
    expect(res.expiresAt, isNull);
    expect(res.ttlSeconds, 0);
  });

  test('active returns null when no token', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    expect(await api.active(), isNull);
  });

  test('resolve GETs token path and parses the v2.0 envelope', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(jsonEncode({
          'data': {'v': 1, 'type': 'profile', 'expires_at': null, 'ciphertext_base64': 'abc='}
        })));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    final res = await api.resolve('jti-9');

    expect(adapter.requests.single.path, '/emergency-qr/resolve/jti-9');
    expect(res.envelopeVersion, 1);
    expect(res.type, 'profile');
    expect(res.expiresAt, isNull);
    expect(res.ciphertextBase64, 'abc=');
  });

  test('scans GETs history and parses entries', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(jsonEncode({
          'data': {
            'scans': [
              {'token_id': 'jti-1', 'resolved_at': '2026-01-01T00:00:00Z', 'client': 'web', 'country': null},
            ]
          }
        })));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    final scans = await api.scans();

    expect(adapter.requests.single.path, '/emergency-qr/scans');
    expect(scans.single.tokenId, 'jti-1');
    expect(scans.single.client, 'web');
    expect(scans.single.country, isNull);
  });

  test('updateCiphertext PUTs to token path with snake_case body', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": {"updated": true}}'));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    await api.updateCiphertext('jti-3', const UpdateQrCiphertextRequest(ciphertextBase64: 'zzz=', profileEtag: 'e2'));

    expect(adapter.requests.single.path, '/emergency-qr/jti-3/ciphertext');
    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.data, {'ciphertext': 'zzz=', 'profile_etag': 'e2'});
  });

  test('revoke POSTs to token path', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    final api = DioEmergencyQrApi(net: fakeNet(adapter));

    await api.revoke('jti-9');

    expect(adapter.requests.single.path, '/emergency-qr/jti-9/revoke');
    expect(adapter.requests.single.method, 'POST');
  });
}
