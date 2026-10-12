import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OfflineFailure is an AppFailure distinct from NetworkFailure', () {
    const f = OfflineFailure();
    expect(f, isA<AppFailure>());
    expect(f, isNot(isA<NetworkFailure>()));
  });
}
