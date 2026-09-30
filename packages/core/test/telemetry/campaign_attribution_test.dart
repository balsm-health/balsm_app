import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPrefsKVDataSource> kv([Map<String, Object>? seed]) async {
    SharedPreferences.setMockInitialValues(seed ?? {});
    return SharedPrefsKVDataSource(await SharedPreferences.getInstance());
  }

  group('campaignPropertiesFrom', () {
    test('reads the campaign parameters off the query', () {
      final props = campaignPropertiesFrom(
        Uri.parse('https://balsm.health/?utm_source=instagram&utm_medium=cpc&utm_campaign=ramadan-2026'),
      );
      expect(props, {'utm_source': 'instagram', 'utm_medium': 'cpc', 'utm_campaign': 'ramadan-2026'});
    });

    test('ignores any parameter that is not a campaign parameter', () {
      // A marketing link is attacker-controllable input as far as the app is
      // concerned; it must not be able to put an arbitrary key on every event.
      final props = campaignPropertiesFrom(
        Uri.parse('https://balsm.health/?utm_source=x&email=patient@example.test&dob=1990-01-01'),
      );
      expect(props, {'utm_source': 'x'});
    });

    test('never reads the path, token or fragment', () {
      final props = campaignPropertiesFrom(Uri.parse('https://balsm.health/t/01J8ABC?t=secret#k=aeskey'));
      expect(props, isEmpty);
    });

    test('caps a long value', () {
      final props = campaignPropertiesFrom(Uri.parse('https://balsm.health/?utm_source=${'a' * 500}'));
      expect(props['utm_source']!.length, 100);
    });

    test('a plain launch has no campaign', () {
      expect(campaignPropertiesFrom(Uri.parse('https://balsm.health/')), isEmpty);
      expect(campaignPropertiesFrom(Uri.parse('balsm://auth/link?t=token')), isEmpty);
    });

    test('blank values are dropped rather than stored empty', () {
      expect(campaignPropertiesFrom(Uri.parse('https://balsm.health/?utm_source=%20&utm_medium=cpc')),
          {'utm_medium': 'cpc'});
    });
  });

  group('CampaignAttribution.resolve', () {
    test('records the campaign from the launch link', () async {
      final store = await kv();
      final resolved = await CampaignAttribution.resolve(
        store,
        launchUri: Uri.parse('https://balsm.health/?utm_source=instagram'),
      );
      expect(resolved, {'utm_source': 'instagram'});
    });

    test('is FIRST touch — a later link does not re-attribute the install', () async {
      final store = await kv();
      await CampaignAttribution.resolve(store, launchUri: Uri.parse('https://balsm.health/?utm_source=instagram'));

      final second = await CampaignAttribution.resolve(
        store,
        launchUri: Uri.parse('https://balsm.health/?utm_source=retargeting'),
      );
      expect(second, {'utm_source': 'instagram'});
    });

    test('an organic launch after an attributed one keeps the attribution', () async {
      final store = await kv();
      await CampaignAttribution.resolve(store, launchUri: Uri.parse('https://balsm.health/?utm_source=instagram'));
      expect(await CampaignAttribution.resolve(store), {'utm_source': 'instagram'});
    });

    test('an organic install stores nothing and reports nothing', () async {
      final store = await kv();
      expect(await CampaignAttribution.resolve(store), isEmpty);
      expect(await CampaignAttribution.resolve(store, launchUri: Uri.parse('https://balsm.health/')), isEmpty);
      expect(await TelemetryPrefs(store).campaign(), isNull);
    });

    test('a value persisted by an older build is re-filtered on read', () async {
      // Defence against a future build widening what it stores: the allowlist is
      // applied again at read time, not just at write time.
      final store = await kv({
        'telemetry.campaign': '{"utm_source":"instagram","email":"patient@example.test"}',
      });
      expect(await CampaignAttribution.resolve(store), {'utm_source': 'instagram'});
    });
  });

  group('initialCampaignSuperProperties', () {
    test('first touch is registered under initial_*, never plain utm_*', () {
      // Plain utm_* is reserved for the campaign on a specific event; sharing
      // the name would let an organic open inherit the install's campaign.
      expect(
        initialCampaignSuperProperties({'utm_source': 'instagram', 'utm_campaign': 'ramadan-2026'}),
        {'initial_utm_source': 'instagram', 'initial_utm_campaign': 'ramadan-2026'},
      );
    });

    test('every initial_* key survives the scrub', () {
      final initial = initialCampaignSuperProperties({for (final k in kCampaignParameters) k: 'x'});
      final scrubbed = scrubPostHogProperties(initial);
      expect(scrubbed.values, everyElement('x'), reason: 'an initial_* key is missing from the allowlist');
    });

    test('an organic install registers nothing', () {
      expect(initialCampaignSuperProperties(const {}), isEmpty);
    });
  });
}
