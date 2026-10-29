import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Product events may only carry keys the PHI allowlist already permits; the
/// scrubber would otherwise redact them, and a new key is a privacy review.
void main() {
  test('every product-event property key is allowlisted', () {
    expect(kTelemetryAllowlist.containsAll(kProductEventPropKeys), isTrue,
        reason: 'not allowlisted: ${kProductEventPropKeys.difference(kTelemetryAllowlist)}');
  });

  test('none of them is a metric, symptom or free-text key', () {
    for (final banned in ['metric', 'symptom', 'value', 'note', 'query', 'reading']) {
      expect(kProductEventPropKeys, isNot(contains(banned)));
    }
  });
}
