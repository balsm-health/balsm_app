@Tags(['e2e'])
library;

// T184 — E2E: signup flow through to the home screen.
// Runner: Patrol (patrolTest). Stub body only; wire up once the Patrol harness
// and app entrypoint fixture exist.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signup -> country -> email -> otp -> disclosure -> home',
      (tester) async {
    // TODO(T184): drive with Patrol:
    //  1. launch app shell (main_dev)
    //  2. select country (EG)
    //  3. enter synthetic email, submit
    //  4. enter OTP from test inbox/stub
    //  5. accept regulatory disclosure
    //  6. assert Home greeting + onboarding nudges are visible
  }, skip: true);
}
