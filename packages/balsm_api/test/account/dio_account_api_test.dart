import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('getSelf parses camelCase payload', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"data": {"id": "u1", "handle": "hoss", "displayName": "Hossam", "countryCode": "EG", "preferredLanguage": "ar", "deletionState": "ACTIVE"}}'));
    final res = await DioAccountApi(net: fakeNet(adapter)).getSelf();
    expect(adapter.requests.single.path, '/account/self');
    expect(res!.id, 'u1');
    expect(res.displayName, 'Hossam');
    expect(res.deletionState, 'ACTIVE');
  });

  test('getSelf returns null on 404', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 404));
    final res = await DioAccountApi(net: fakeNet(adapter)).getSelf();
    expect(res, isNull);
  });

  test('getSelf deletionState defaults to ACTIVE', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse(
        '{"data": {"id": "u1", "countryCode": "EG", "preferredLanguage": "en"}}'));
    final res = await DioAccountApi(net: fakeNet(adapter)).getSelf();
    expect(res!.deletionState, 'ACTIVE');
  });

  test('claimHandle posts handle and echoes claimed handle', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"data": {"handle": "hoss"}}'));
    final res = await DioAccountApi(net: fakeNet(adapter))
        .claimHandle(const ClaimHandleRequest(handle: 'hoss'));
    expect(adapter.requests.single.path, '/account/handle/claim');
    expect(adapter.requests.single.data, {'handle': 'hoss'});
    expect(res.handle, 'hoss');
  });

  test('changeLanguage/changeCountry send camelCase keys', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    final api = DioAccountApi(net: fakeNet(adapter));
    await api.changeLanguage(const ChangeLanguageRequest(preferredLanguage: 'ar'));
    await api.changeCountry(const ChangeCountryRequest(countryCode: 'EG'));
    expect(adapter.requests[0].data, {'preferredLanguage': 'ar'});
    expect(adapter.requests[1].data, {'countryCode': 'EG'});
  });

  test('checkHandleAvailability sends query param, default false', () async {
    final adapter =
        FakeHttpAdapter((_) => jsonResponse('{"data": {"available": true}}'));
    final api = DioAccountApi(net: fakeNet(adapter));
    final res = await api.checkHandleAvailability('hoss');
    expect(adapter.requests.single.queryParameters, {'handle': 'hoss'});
    expect(res.available, isTrue);

    final adapter2 = FakeHttpAdapter((_) => jsonResponse('{"data": {}}'));
    final res2 = await DioAccountApi(net: fakeNet(adapter2))
        .checkHandleAvailability('x');
    expect(res2.available, isFalse);
  });
}
