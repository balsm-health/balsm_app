import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allowlisted keys survive, unknown keys are redacted', () {
    final out = scrubTelemetry({
      'route': '/account/settings', // allowlisted
      'count': 3, // allowlisted
      'email': 'a@b.c', // NOT allowlisted → redacted
      'handle': 'hoss', // NOT allowlisted → redacted
    });
    expect(out['route'], '/account/settings');
    expect(out['count'], 3);
    expect(out['email'], '[redacted]');
    expect(out['handle'], '[redacted]');
  });

  test('a non-allowlisted key redacts its whole (possibly nested) value', () {
    final out = scrubTelemetry({
      'profile': {'email': 'a@b.c', 'dob': '1990-01-01'},
    });
    expect(out['profile'], '[redacted]'); // whole subtree gone, not just leaves
  });

  test('null / empty tolerated', () {
    expect(scrubTelemetry(null), isEmpty);
    expect(scrubTelemetry(const {}), isEmpty);
  });

  test('non-string keys are stringified then matched', () {
    expect(scrubTelemetry({1: 'x'}), {'1': '[redacted]'});
  });
}
