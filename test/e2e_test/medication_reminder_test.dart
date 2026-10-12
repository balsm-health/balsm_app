@Tags(['e2e'])
library;

// T186 — E2E: medication reminder schedule -> notification -> outcome capture.
// Runner: Patrol (patrolTest). Stub body only.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('schedule medication, fire reminder, record outcome', (tester) async {
    // TODO(T186): drive with Patrol:
    //  1. add a medication with a near-future schedule
    //  2. advance time / trigger the local notification
    //  3. assert the notification body is GENERIC (no drug name) per FR-018
    //  4. tap the reminder and record an outcome (taken/skipped/snoozed)
    //  5. assert the outcome is persisted and reflected in Today's list
  }, skip: true);
}
