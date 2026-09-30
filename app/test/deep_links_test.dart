import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/care/care_entity.dart';
import 'package:app/balsm_app/deep_links.dart';
import 'package:app/balsm_app/routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// The deep-link route table. Every URL shape the app can be opened with —
/// App Link / Universal Link, the `balsm://` scheme, and the web shell's own
/// `Uri.base` — must reach the same destination with the same arguments.
void main() {
  DeepLinkTarget? parse(String url) => parseDeepLink(Uri.parse(url));

  group('the three URL shapes agree', () {
    for (final url in ['https://app.balsm.health/meds', 'balsm://meds', 'http://localhost:8080/meds']) {
      test(url, () {
        final t = parse(url);
        expect(t, isA<TabTarget>());
        expect((t! as TabTarget).tab, AppTab.meds);
      });
    }
  });

  group('profile QR carries its arguments', () {
    test('token id from the path, key from the #k= fragment', () {
      final t = parse('https://app.balsm.health/t/01J8XyZaBc#k=Zm9v-YmFy_c2Vj') as EmergencyCardTarget;
      expect(t.tokenId, '01J8XyZaBc', reason: 'case preserved — the id is case-sensitive');
      expect(t.key, 'Zm9v-YmFy_c2Vj', reason: 'base64url key untouched');
      expect(t.requiresSession, isFalse, reason: 'the scanner is a first responder, not the owner');
    });

    test('legacy /emergency/ alias and the custom scheme parse identically', () {
      for (final url in ['https://app.balsm.health/emergency/01J8XyZaBc#k=abc', 'balsm://t/01J8XyZaBc#k=abc']) {
        final t = parse(url) as EmergencyCardTarget;
        expect(t.tokenId, '01J8XyZaBc');
        expect(t.key, 'abc');
      }
    });

    test('a link that lost its fragment still routes, with no key', () {
      final t = parse('https://app.balsm.health/t/01J8XyZaBc') as EmergencyCardTarget;
      expect(t.key, isNull);
    });
  });

  group('magic sign-in link', () {
    test('https and custom-scheme forms carry the token', () {
      for (final url in ['https://app.balsm.health/auth/link?t=tok_123', 'balsm://auth/link?t=tok_123']) {
        expect((parse(url) as MagicLinkTarget).token, 'tok_123');
      }
    });

    test('a truncated link routes with no token, so it can be reported as malformed', () {
      expect((parse('balsm://auth/link') as MagicLinkTarget).token, isNull);
      expect((parse('balsm://auth/link?t=') as MagicLinkTarget).token, isNull);
    });
  });

  group('account deletion, current and legacy paths', () {
    test('delete', () {
      expect(parse('https://app.balsm.health/delete-account'), isA<DeleteAccountTarget>());
      expect(parse('https://app.balsm.health/account/delete'), isA<DeleteAccountTarget>());
    });

    test('cancel', () {
      expect(parse('https://app.balsm.health/delete-account-cancel'), isA<DeleteAccountCancelTarget>());
      expect(parse('https://app.balsm.health/account/delete-cancelled'), isA<DeleteAccountCancelTarget>());
    });
  });

  group('signed-in shell', () {
    test('every tab has a link', () {
      for (final tab in AppTab.values) {
        final t = parse('https://app.balsm.health/${tab.id}');
        expect(t!.requiresSession, isTrue, reason: tab.id);
        if (tab == AppTab.map) {
          expect(t, isA<MapTarget>(), reason: 'the map takes a type filter');
        } else {
          expect((t as TabTarget).tab, tab);
        }
      }
    });

    test('every pushed screen has a link', () {
      for (final screen in AppScreen.values) {
        final t = parse('https://app.balsm.health/${screen.path}');
        expect(t, isA<ScreenTarget>(), reason: screen.path);
        expect((t! as ScreenTarget).screen, screen);
        expect(t.requiresSession, isTrue);
      }
    });

    test('trailing slash, case and campaign params do not change the destination', () {
      final t = parse('https://app.balsm.health/Profile/Privacy/?utm_source=newsletter');
      expect((t! as ScreenTarget).screen, AppScreen.privacy);
    });
  });

  group('map type filter', () {
    Set<CareEntityType> types(String url) => (parse(url)! as MapTarget).types;

    test('a bare /map is unfiltered — empty means "All", like the map itself', () {
      expect(types('https://app.balsm.health/map'), isEmpty);
    });

    test('a single type', () {
      expect(types('https://app.balsm.health/map?type=pharmacy'), {CareEntityType.pharmacy});
    });

    test('a comma list, repeated params, or both', () {
      const both = {CareEntityType.pharmacy, CareEntityType.lab};
      expect(types('https://app.balsm.health/map?type=pharmacy,lab'), both);
      expect(types('https://app.balsm.health/map?type=pharmacy&type=lab'), both);
      expect(types('balsm://map?type=pharmacy,lab&type=scan'), {...both, CareEntityType.scan});
    });

    test('case and whitespace do not matter', () {
      expect(types('https://app.balsm.health/map?type=Pharmacy,%20LAB'), {CareEntityType.pharmacy, CareEntityType.lab});
    });

    test('an unknown type is dropped, never coerced to clinic', () {
      // CareEntityType.fromWire falls back to clinic; a typo in a campaign link
      // must not become a clinics-only map.
      expect(types('https://app.balsm.health/map?type=pharmacyy'), isEmpty);
      expect(types('https://app.balsm.health/map?type=pharmacy,nope'), {CareEntityType.pharmacy});
    });

    test('every care type is reachable by its wire id', () {
      for (final type in CareEntityType.values) {
        expect(types('https://app.balsm.health/map?type=${type.wire}'), {type});
      }
    });

    test('campaign params ride alongside without affecting the filter', () {
      expect(types('https://app.balsm.health/map?type=lab&utm_source=newsletter'), {CareEntityType.lab});
    });
  });

  group('PatientAppState.openMap', () {
    test('switches to the map tab and issues the filter', () {
      final s = PatientAppState()..openMap(types: {CareEntityType.pharmacy});
      expect(s.tab, AppTab.map);
      expect(s.mapFilterRequest!.types, {CareEntityType.pharmacy});
    });

    test('the same filter twice is still two distinct requests', () {
      // So a second tap on the same link re-applies over a filter the patient
      // changed by hand in between.
      final s = PatientAppState()..openMap(types: {CareEntityType.lab});
      final first = s.mapFilterRequest!.serial;
      s.openMap(types: {CareEntityType.lab});
      expect(s.mapFilterRequest!.serial, isNot(first));
    });
  });

  group('not a deep link / unknown', () {
    test('the bare root is not a deep link — a normal web load or launch', () {
      expect(parse('https://app.balsm.health/'), isNull);
      expect(parse('https://app.balsm.health'), isNull);
      expect(parse('balsm://'), isNull);
    });

    test('an unknown path is an UnknownTarget, never a guessed destination', () {
      expect(parse('https://app.balsm.health/nope'), isA<UnknownTarget>());
      expect(parse('https://app.balsm.health/t/'), isA<UnknownTarget>(), reason: 'no token id');
      expect(parse('https://app.balsm.health/t/a/b'), isA<UnknownTarget>());
    });
  });

  group('telemetry kind', () {
    test('is a constant label, never a slice of the URL', () {
      const urls = [
        'balsm://auth/link?t=live-credential-token',
        'https://app.balsm.health/t/01J8XYZ#k=Zm9vYmFyc2VjcmV0',
      ];
      for (final url in urls) {
        final kind = parse(url)!.kind;
        for (final secret in ['live-credential-token', 'Zm9vYmFyc2VjcmV0', '01J8XYZ']) {
          expect(kind, isNot(contains(secret)));
        }
      }
    });
  });
}
