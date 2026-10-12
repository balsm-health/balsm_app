import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// The wire values are already written to on-device rows, so they are a
/// compatibility surface, not an implementation detail.
void main() {
  test('wire values are the persisted strings', () {
    expect(AllergySeverity.mild.wire, 'mild');
    expect(AllergySeverity.moderate.wire, 'moderate');
    expect(AllergySeverity.severe.wire, 'severe');
  });

  test('round-trips through the persisted form', () {
    for (final level in AllergySeverity.values) {
      expect(AllergySeverity.fromWire(level.wire), level);
    }
  });

  test('an unknown value is null, not a crash', () {
    // A row written by a newer build must not make the profile unreadable.
    expect(AllergySeverity.fromWire('life-threatening'), isNull);
    expect(AllergySeverity.fromWire(''), isNull);
  });

  test('parsing is exact — no case folding or trimming', () {
    expect(AllergySeverity.fromWire('Mild'), isNull);
    expect(AllergySeverity.fromWire(' mild'), isNull);
  });

  test('kAllergySeverities stays in step with the enum', () {
    expect(kAllergySeverities, AllergySeverity.wireValues);
    expect(kAllergySeverities, ['mild', 'moderate', 'severe']);
  });

  test('labels resolve per language', () {
    expect(AllergySeverity.severe.labelForLang('en'), 'Severe');
  });
}
