import 'package:app/balsm_app/shell.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone tab bar against each bottom system inset it meets.
void main() {
  test('with no inset the bar keeps its 22px foot', () => expect(tabBarBottomPadding(0), 22));

  test('the iPhone home indicator adds at most 12', () => expect(tabBarBottomPadding(34), 34));

  test('Android gesture navigation keeps the same spacing', () => expect(tabBarBottomPadding(24), 34));

  test('the Android 3-button bar is cleared in full', () {
    // A Galaxy A17 on Android 16: the solid bar is 48dp and nothing may sit under it.
    expect(tabBarBottomPadding(48), greaterThanOrEqualTo(48));
  });
}
