import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The shareable QR must never tell a patient their health code is permanent.
///
/// It is the FR-017 emergency QR: it mints against a chosen TTL and can be
/// revoked. A "does not expire" badge — or an ∞ in the TTL picker — is a claim
/// about their own health data that the app cannot keep, which is also why
/// `qrshare.jsx`'s permanence note was never ported.
void main() {
  String bundle(String name) => File('lib/balsm_app/i18n/$name').readAsStringSync();

  test('no permanence copy survives in either bundle', () {
    for (final f in ['strings.i69n.jsonc', 'strings_ar.i69n.jsonc']) {
      final s = bundle(f);
      expect(s, isNot(contains('"eqr_permanent"')), reason: '$f still carries the permanent badge');
      expect(s, isNot(contains('"eqr_ttl_permanent"')), reason: '$f still offers an unlimited TTL');
      expect(s, isNot(contains('does not expire')), reason: '$f still claims the code never expires');
    }
  });

  test('the code is signed: name and handle sit together under it', () {
    final s = File('lib/balsm_app/screens/personal_details.dart').readAsStringSync();
    // One block, used by the card AND the pre-mint view — the card only
    // exists once a token is minted, so a lone call site means the sheet
    // identifies nobody until you generate.
    expect(RegExp(r'\.\.\._identity\(\)').allMatches(s).length, 2,
        reason: 'identity must render under the QR and before minting');
    // The handle reads as a handle, not as the copyable URL.
    expect(s, contains("Text('@\$handle'"));
    expect(s, isNot(contains("balsm.health/@\$handle")), reason: 'the URL belongs to the link row');
  });

  test('every offered TTL is bounded', () {
    final s = File('lib/balsm_app/screens/personal_details.dart').readAsStringSync();
    final block = RegExp(r'_emergencyTtlOptions = <[^>]*>\[(.*?)\];', dotAll: true).firstMatch(s);
    expect(block, isNotNull, reason: 'the TTL option list moved');
    final seconds = RegExp(r'seconds: (\d+)').allMatches(block!.group(1)!).map((m) => int.parse(m.group(1)!));
    expect(seconds, isNotEmpty);
    // 0 is the sentinel the mint API reads as "never expires".
    expect(seconds, everyElement(greaterThan(0)), reason: 'an unbounded TTL is offered again');
  });
}
