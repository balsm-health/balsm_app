import 'package:balsm_api/balsm_api.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  test('requestIntake POSTs and parses grace_until as UTC', () async {
    final adapter = FakeHttpAdapter((_) =>
        jsonResponse('{"data": {"grace_until": "2026-07-30T00:00:00+02:00", "deletion_state": "DELETION_REQUESTED"}}'));
    final api = DioDeletionApi(net: fakeNet(adapter));

    final res = await api.requestIntake();

    expect(adapter.requests.single.path, '/deletion/intake');
    expect(adapter.requests.single.method, 'POST');
    expect(res.graceUntil.isUtc, isTrue);
    expect(res.deletionState, 'DELETION_REQUESTED');
  });

  test('cancel POSTs and parses deletion_state', () async {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"data": {"deletion_state": "DELETION_CANCELLED"}}'));
    final res = await DioDeletionApi(net: fakeNet(adapter)).cancel();
    expect(res.deletionState, 'DELETION_CANCELLED');
  });

  test('envelope error surfaces as fromEnvelope ApiException', () {
    final adapter = FakeHttpAdapter((_) => jsonResponse('{"error": {"message": "already pending"}}'));
    expect(
      DioDeletionApi(net: fakeNet(adapter)).requestIntake(),
      throwsA(isA<ApiException>().having((e) => e.serverMessage, 'serverMessage', 'already pending')),
    );
  });
}
