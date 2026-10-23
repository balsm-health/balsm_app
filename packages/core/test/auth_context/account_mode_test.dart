import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wire round-trip', () {
    for (final m in AccountMode.values) {
      expect(AccountMode.fromWire(m.wire), m);
    }
  });
  test('missing or unknown means online (existing installs)', () {
    expect(AccountMode.fromWire(null), AccountMode.online);
    expect(AccountMode.fromWire('garbage'), AccountMode.online);
  });
}
