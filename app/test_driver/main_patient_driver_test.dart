// UI smoke test for the patient app, driven via Flutter Driver.
//
// Pair: app entrypoint `test_driver/main_patient_driver.dart` (enables the
// driver extension). Run with `scripts/ui_test.sh` or:
//   flutter drive -t test_driver/main_patient_driver.dart \
//     --driver test_driver/main_patient_driver_test.dart -d <device>
//
// Assumes a signed-in session (the app persists it). If the welcome screen is
// showing, it completes the quick social sign-in first.
import 'package:flutter_driver/flutter_driver.dart';
import 'package:flutter_test/flutter_test.dart' hide find;

void main() {
  late FlutterDriver driver;
  const t = Duration(seconds: 12);

  setUpAll(() async => driver = await FlutterDriver.connect());
  tearDownAll(() async => driver.close());

  Future<void> tapText(String s) => driver.tap(find.text(s), timeout: t);
  Future<void> see(String s) => driver.waitFor(find.text(s), timeout: t);

  test('driver healthy', () async {
    expect((await driver.checkHealth()).status, HealthStatus.ok);
  });

  test('reach the app (sign in if needed)', () async {
    try {
      await driver.waitFor(find.text('Get started'), timeout: const Duration(seconds: 3));
      await tapText('Continue with Apple'); // welcome → profile setup
      await tapText('Create my profile'); // → app
    } catch (_) {/* already signed in */}
    await see('Good morning'); // Home
  });

  test('Home tab', () async {
    await tapText('Home');
    await see('Latest readings');
  });

  test('Nearby tab', () async {
    await tapText('Nearby');
    await see('Nearby care');
  });

  test('Meds tab', () async {
    await tapText('Meds');
    await see('Medications');
  });

  test('Profile tab', () async {
    await tapText('Profile');
    await see('Account details');
  });
}
