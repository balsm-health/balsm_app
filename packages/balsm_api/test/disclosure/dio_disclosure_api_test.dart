import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('accept posts snake_case disclosure payload', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": null}'));
    await DioDisclosureApi(dio: fakeDio(adapter)).accept(
      const AcceptDisclosureRequest(
        disclosureId: 'disc-1',
        version: '2',
        countryCode: 'EG',
        supervisoryAuthority: 'PDPC',
        preferredLanguage: 'ar',
      ),
    );
    expect(adapter.requests.single.path, '/disclosure/accept');
    expect(adapter.requests.single.data, {
      'disclosure_id': 'disc-1',
      'version': '2',
      'country_code': 'EG',
      'supervisory_authority': 'PDPC',
      'preferred_language': 'ar',
    });
  });
}
