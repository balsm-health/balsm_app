@Tags(['e2e'])
library;

// T185 — E2E: emergency card QR generate -> scan -> public view round-trip.
// Runner: Patrol (patrolTest). Stub body only.
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('generate emergency card, open public link, view decrypts', (tester) async {
    // TODO(T185): drive with Patrol:
    //  1. authenticated user generates an emergency card (TTL set)
    //  2. capture the produced URL '/emergency/<token>#k=<base64url-key>'
    //  3. open that URL as an UNAUTHENTICATED visitor (web public route)
    //  4. assert the card payload decrypts with the fragment key and renders
    //  5. revoke the card and assert the public link now shows "expired"
  }, skip: true);
}
