import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for BALSM-APP-V / BALSM-APP-T: a bare `host:port`
/// typed into Dev Config's custom-server field used to reach `dio`'s
/// `Uri.parse` unchanged and throw `FormatException: Scheme not starting
/// with alphabetic character`.
void main() {
  test('adds http:// to a schemeless host:port', () {
    expect(normalizeServerUrl('192.168.8.3:5050'), 'http://192.168.8.3:5050');
  });

  test('leaves an already-schemed URL alone', () {
    expect(normalizeServerUrl('https://staging.example.com/api'), 'https://staging.example.com/api');
  });

  test('trims surrounding whitespace before checking for a scheme', () {
    expect(normalizeServerUrl('  localhost:5050  '), 'http://localhost:5050');
  });

  test('rejects empty input', () {
    expect(normalizeServerUrl(''), isNull);
    expect(normalizeServerUrl('   '), isNull);
  });
}
