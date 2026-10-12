import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The shareable QR must never tell a patient their health code is permanent.
///
/// The token itself has no expiry, but it can be revoked or rotated. A "does
/// not expire" badge is a claim about their own health data that the app
/// cannot keep, which is also why `qrshare.jsx`'s permanence note was never
/// ported.
void main() {
  String bundle(String name) => File('lib/balsm_app/i18n/$name').readAsStringSync();

  test('no permanence copy survives in either bundle', () {
    for (final f in ['strings.i69n.jsonc', 'strings_ar.i69n.jsonc']) {
      final s = bundle(f);
      // Prefix, not exact key: a design sweep reintroduced this as
      // `eqr_permanent_note`, which an exact match waved through.
      expect(s, isNot(contains('"eqr_permanent')), reason: '$f still carries permanence copy');
      expect(s, isNot(contains('"eqr_ttl_permanent"')), reason: '$f still offers an unlimited TTL');
      for (final claim in ['does not expire', "doesn't expire", 'لا تنتهي صلاحيته']) {
        expect(s, isNot(contains(claim)), reason: '$f still claims the code never expires');
      }
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

  test('the sheet offers no TTL picker', () {
    final s = File('lib/balsm_app/screens/personal_details.dart').readAsStringSync();
    // The token is minted permanent and offline-first; a bounded TTL needs
    // the server at mint time, which is what made Generate fail offline.
    expect(s, isNot(contains('_emergencyTtlOptions')), reason: 'the TTL picker came back');
    final c = File('lib/balsm_app/qr/qr_share_controller.dart').readAsStringSync();
    expect(c, contains('call(ttlSeconds: kPermanentQrTtlSeconds)'), reason: 'the sheet mints a server-bound TTL again');
  });

  test('the screen renders no permanence note, however it is worded', () {
    final s = File('lib/balsm_app/screens/personal_details.dart').readAsStringSync();
    // `qrshare.jsx` draws it as an infinity glyph beside the reassurance. The
    // glyph is the tell that the note came back in some other wording.
    expect(s, isNot(contains('LucideIcons.infinity')), reason: 'the permanence note was ported again');
  });
}
