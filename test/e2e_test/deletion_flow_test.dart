@Tags(['e2e'])
library;

// T187 — E2E: account deletion request -> grace period -> cancel/confirm.
// Runner: Patrol (patrolTest). Stub body only.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('request deletion, enter grace period, cancel restores account', (tester) async {
    // TODO(T187): drive with Patrol:
    //  1. authenticated user opens Account -> Delete account
    //  2. confirm deletion; assert grace-period messaging is shown
    //  3. open the '/account/delete-cancelled' deep link (from email)
    //  4. assert deletion is cancelled and the account remains active
  }, skip: true);
}
