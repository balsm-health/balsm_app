import 'package:app/balsm_app/deep_link_handler.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// `deepLinkKind` is the only thing standing between an inbound link and a
/// telemetry prop, and inbound links carry two live secrets: the magic-link
/// token (`?t=`) and the emergency-QR AES key (`#k=`). It must return a constant
/// and nothing else.
void main() {
  group('classification (kinds come from the route table in deep_links.dart)', () {
    test('native magic-link scheme', () {
      expect(deepLinkKind(Uri.parse('balsm://auth/link?t=tok')), 'auth_magic_link');
    });

    test('web magic-link form', () {
      expect(deepLinkKind(Uri.parse('https://app.balsm.health/auth/link?t=tok')), 'auth_magic_link');
    });

    test('emergency card, both the /t/ and /emergency/ shapes', () {
      expect(deepLinkKind(Uri.parse('https://app.balsm.health/t/01J8ABC#k=key')), 'emergency_card');
      expect(deepLinkKind(Uri.parse('https://app.balsm.health/emergency/01J8ABC#k=key')), 'emergency_card');
    });

    test('account deletion, and its cancellation, are distinct', () {
      expect(deepLinkKind(Uri.parse('https://app.balsm.health/account/delete')), 'account_delete');
      expect(
        deepLinkKind(Uri.parse('https://app.balsm.health/account/delete-cancelled')),
        'account_delete_cancelled',
      );
    });

    test('anything unrecognised is "other", never the path', () {
      expect(deepLinkKind(Uri.parse('https://app.balsm.health/some/unknown/page')), 'other');
      expect(deepLinkKind(Uri.parse('balsm://something-else')), 'other');
      // Not routes in this build: the recovery claim has a use case but no
      // screen, and there is no in-app status page.
      expect(deepLinkKind(Uri.parse('https://app.balsm.health/auth/recovery?token=x')), 'other');
      expect(deepLinkKind(Uri.parse('https://app.balsm.health/status')), 'other');
    });
  });

  group('no secret can reach telemetry through it', () {
    const withSecrets = [
      'balsm://auth/link?t=live-credential-token',
      'https://app.balsm.health/t/01J8XYZ#k=Zm9vYmFyc2VjcmV0',
      'https://app.balsm.health/auth/recovery?token=recovery-secret',
    ];

    test('the returned kind contains no part of the URI', () {
      for (final raw in withSecrets) {
        final kind = deepLinkKind(Uri.parse(raw));
        expect(kind, isNot(contains('live-credential-token')));
        expect(kind, isNot(contains('Zm9vYmFyc2VjcmV0')));
        expect(kind, isNot(contains('recovery-secret')));
        expect(kind, isNot(contains('01J8XYZ')));
      }
    });

    test('every kind survives the telemetry scrub intact', () {
      // Both prop keys must be allowlisted, or the dashboard shows [redacted].
      for (final raw in withSecrets) {
        final scrubbed = scrubTelemetry({'source': deepLinkKind(Uri.parse(raw)), 'result': 'ok'});
        expect(scrubbed['source'], isNot(kTelemetryRedacted));
        expect(scrubbed['result'], 'ok');
      }
    });
  });

  group('per-link campaign on deep_link_opened', () {
    test('a campaign link reports its own utm_source / utm_campaign', () {
      final props = campaignPropertiesFrom(
        Uri.parse('https://app.balsm.health/auth/link?t=secret&utm_source=newsletter&utm_campaign=reengage-oct'),
      );
      expect(props, {'utm_source': 'newsletter', 'utm_campaign': 'reengage-oct'});
      expect(props.values.join(' '), isNot(contains('secret')));
    });

    test('a link with no campaign adds nothing — it does not inherit first touch', () {
      expect(campaignPropertiesFrom(Uri.parse('balsm://auth/link?t=secret')), isEmpty);
    });
  });
}
