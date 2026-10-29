import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// `GET /status` as the API sends it: every body wrapped in `{ "data": … }`.
void main() {
  test('the enveloped body is read inside data', () {
    final health = ServiceHealth.fromJson({
      'data': {'status': 'operational', 'checked_at': '2026-10-29T05:52:04Z', 'version': '0.1.2.0'},
    });

    expect(health.level, ServiceStatusLevel.operational);
  });

  test('a bare body still parses', () {
    expect(ServiceHealth.fromJson({'status': 'degraded'}).level, ServiceStatusLevel.degraded);
  });

  test('an envelope without a status reads as unknown', () {
    expect(ServiceHealth.fromJson({'data': <String, dynamic>{}}).level, ServiceStatusLevel.unknown);
  });
}
