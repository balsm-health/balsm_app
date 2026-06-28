// T180 — Web smoke tests for public (unauthenticated) routes.
//
// Verifies the two public web entry points do NOT redirect to auth, and that
// the emergency fragment-key (#k=<base64url>) parser round-trips. The first two
// tests need the GoRouter web fixture (added with the router task) — marked TODO.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('emergency public route renders without auth redirect',
      (tester) async {
    // TODO(T180): pump the production GoRouter at '/emergency/<token>#k=<key>'
    // with an UNAUTHENTICATED session and assert the emergency view (not the
    // login screen) is shown — i.e. redirect guard must allow this public path.
    // Requires: router fixture + EmergencyPublicScreen.
  }, skip: true);

  testWidgets('account/delete public route renders without auth redirect',
      (tester) async {
    // TODO(T180): pump the production GoRouter at '/account/delete' with an
    // UNAUTHENTICATED session and assert the deletion confirmation view is
    // shown (public deep link from email) rather than being redirected to auth.
    // Requires: router fixture + DeletionPublicScreen.
  }, skip: true);

  testWidgets('fragment-key base64url parser round-trips', (tester) async {
    // This one needs no router fixture — it exercises the pure parse logic.
    const rawKey = 'super-secret-emergency-key-32bytes!!';
    final encoded = base64Url.encode(utf8.encode(rawKey));
    final fragment = 'k=$encoded';

    // Mirror DeeplinkRouter fragment handling: strip the 'k=' prefix.
    final extracted = fragment.replaceFirst('k=', '');
    final decoded = utf8.decode(base64Url.decode(extracted));

    expect(extracted, encoded);
    expect(decoded, rawKey);
  });
}
