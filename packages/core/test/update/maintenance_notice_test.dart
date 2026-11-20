import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the maintenance block', () {
    final n = parseMaintenanceNotice(
        '{"versions":{},"maintenance":{"mode":"readonly","message":"Back soon","ends_at":"2026-11-21T02:00:00Z"}}');

    expect((n?.mode, n?.message, n?.endsAt), ('readonly', 'Back soon', DateTime.utc(2026, 11, 21, 2)));
  });

  test('a manifest without the block says off', () {
    expect(parseMaintenanceNotice('{"versions":{}}')?.mode, 'off');
  });

  test('a blank message and an unreadable end time are left out', () {
    final n = parseMaintenanceNotice('{"maintenance":{"mode":"block","message":"  ","ends_at":"soon"}}');

    expect((n?.mode, n?.message, n?.endsAt), ('block', null, null));
  });

  test('anything malformed is not an announcement', () {
    expect(parseMaintenanceNotice('<html>captive portal</html>'), isNull);
    expect(parseMaintenanceNotice('[]'), isNull);
    expect(parseMaintenanceNotice('{"maintenance":"block"}'), isNull);
    expect(parseMaintenanceNotice('{"maintenance":{"mode":3}}'), isNull);
  });
}
