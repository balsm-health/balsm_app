// T175 — PHI-leak fuzz test.
//
// Exercises 50+ synthetic PHI payloads (corpus.dart) through every egress
// scrubber and asserts no denied PHI field name, and no URL secret, survives:
//   1. core `scrubTelemetry` — Sentry breadcrumb data, event contexts
//   2. core `scrubPostHogProperties` — PostHog event properties
//   3. `PhiLeakInterceptor.scrubForTelemetry` — the safe copy of a request body
//
// The allowlist is a single shared constant (`kNonPhiAllowlist` in balsm_api),
// aliased by core as `kTelemetryAllowlist`. This file no longer keeps its own
// mirror — it asserts against the real one, so drift is impossible rather than
// merely discouraged.
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'corpus.dart';

/// Field names that must never survive any scrub. Kept here, not derived, on
/// purpose: an independent statement of the requirement is what makes the test
/// meaningful. If a name ever appears in BOTH this set and the allowlist, that
/// is the bug — see the `no key is both allowed and denied` test.
const Set<String> kDenied = {
  'email',
  'dob',
  'date_of_birth',
  'name',
  'phone',
  'national_id',
  'blood_type',
  'allergy',
  'condition',
  'medication',
  'handle',
  'display_name',
  'bio',
  'emergency_contact',
};

void main() {
  final corpus = PhiCorpus.generate();

  test('corpus has at least 50 synthetic payloads', () {
    expect(corpus.length, greaterThanOrEqualTo(50));
  });

  test('no key is both allowed and denied', () {
    // The regression that motivated this test: 'name' sat on the allowlist while
    // being the medication/allergy/contact/patient name key throughout the
    // domain, so `MedicationAdded.toJson()` shipped the medication to telemetry.
    expect(
      kNonPhiAllowlist.intersection(kDenied),
      isEmpty,
      reason: 'A denied PHI field name is on the non-PHI allowlist',
    );
  });

  test('core and balsm_api share ONE allowlist, not two copies', () {
    expect(identical(kTelemetryAllowlist, kNonPhiAllowlist), isTrue);
    expect(identical(PhiLeakInterceptor.allowedFields, kNonPhiAllowlist), isTrue);
  });

  group('core scrubTelemetry (Sentry breadcrumbs + contexts)', () {
    test('drops every denied PHI field across the full corpus', () {
      for (final payload in corpus) {
        final scrubbed = scrubTelemetry(payload);
        for (final entry in scrubbed.entries) {
          if (kDenied.contains(entry.key)) {
            expect(entry.value, kTelemetryRedacted, reason: 'Denied field "${entry.key}" kept its value');
          }
        }
      }
    });

    test('preserves allowed telemetry fields when present', () {
      final scrubbed = scrubTelemetry({'event_id': 'evt-1', 'level': 'error', 'email': 'leak@example.test'});
      expect(scrubbed['event_id'], 'evt-1');
      expect(scrubbed['level'], 'error');
      expect(scrubbed['email'], kTelemetryRedacted);
    });
  });

  group('PostHog scrubPostHogProperties', () {
    test('drops every denied PHI field across the full corpus', () {
      for (final payload in corpus) {
        final scrubbed = scrubPostHogProperties(payload);
        for (final entry in scrubbed.entries) {
          if (kDenied.contains(entry.key)) {
            expect(entry.value, kTelemetryRedacted, reason: 'Denied field "${entry.key}" kept its value');
          }
        }
      }
    });
  });

  group('domain events forwarded by EventBusAnalyticsForwarder', () {
    test('a medication event does not ship the medication name', () {
      // Shape of `MedicationAdded.toJson()`. The forwarder sends this verbatim
      // as `logEvent('medication.added', props: toJson())`, and the event is in
      // kKeyEventNames, so it becomes a searchable Sentry event rather than a
      // breadcrumb that only ships alongside a crash.
      const props = {'medicationId': 'med-1', 'name': 'Metformin 500mg', 'scheduleId': 'sch-1'};
      for (final scrubbed in [scrubTelemetry(props), scrubPostHogProperties(props)]) {
        expect(scrubbed['name'], kTelemetryRedacted);
        expect(scrubbed.values.join(' '), isNot(contains('Metformin')));
      }
    });
  });

  group('URL secrets', () {
    // The emergency-QR AES key is the URL fragment and the magic sign-in token
    // is a query param, so allowlisting the key name is not enough.
    const qr = 'https://balsm.health/t/01J8XYZABC#k=Zm9vYmFyc2VjcmV0a2V5';
    const magicLink = 'balsm://auth/link?t=live-credential-token';

    test('the emergency-QR decryption key never survives', () {
      for (final scrubbed in [
        scrubTelemetry({'url': qr}),
        scrubPostHogProperties({'url': qr}),
        PhiLeakInterceptor.scrubForTelemetry({'url': qr}),
      ]) {
        expect(scrubbed['url'], isNot(contains('#')));
        expect(scrubbed['url'], isNot(contains('Zm9vYmFyc2VjcmV0a2V5')));
      }
    });

    test('the magic sign-in token never survives', () {
      for (final scrubbed in [
        scrubTelemetry({'url': magicLink}),
        scrubPostHogProperties({'url': magicLink}),
      ]) {
        expect(scrubbed['url'], isNot(contains('live-credential-token')));
      }
    });

    test('opaque path segments are masked, route shape is kept', () {
      expect(redactUrl(qr), 'https://balsm.health/t/:id');
      expect(redactUrl('https://api.balsm.health/api/v1/account/0f8a-uuid/profile'),
          'https://api.balsm.health/api/v1/account/:id/profile');
    });

    test('unparseable input is redacted wholesale, never passed through', () {
      expect(redactUrl('::::not a url::::'), kRedacted);
    });
  });

  group('Dio PhiLeakInterceptor', () {
    // The interceptor MUST NOT mutate the outbound body — the API is the trusted
    // recipient and legitimately needs those fields over TLS. It stashes a
    // scrubbed COPY for loggers. The assertion therefore belongs on
    // `extra['phi_safe_body']`; the previous version asserted on the body itself,
    // which contradicted the interceptor's contract and failed permanently.
    test('the wire body is left intact', () {
      final interceptor = PhiLeakInterceptor();
      final payload = {'email': 'patient@example.test', 'name': 'Ahmed'};
      final options = RequestOptions(path: '/v1/profile', data: payload);

      late RequestOptions captured;
      interceptor.onRequest(options, _CapturingRequestHandler((o) => captured = o));

      expect(captured.data, same(payload));
      expect((captured.data as Map)['email'], 'patient@example.test');
    });

    test('the telemetry copy drops every denied PHI field across the corpus', () {
      final interceptor = PhiLeakInterceptor();

      for (final payload in corpus) {
        final options = RequestOptions(path: '/v1/profile', data: payload);
        late RequestOptions captured;
        interceptor.onRequest(options, _CapturingRequestHandler((o) => captured = o));

        final safe = captured.extra['phi_safe_body'] as Map<String, dynamic>;
        for (final entry in safe.entries) {
          if (kDenied.contains(entry.key)) {
            expect(entry.value, kRedacted, reason: 'Denied field "${entry.key}" survived into phi_safe_body');
          }
        }
      }
    });

    test('non-map request bodies pass through untouched and stash nothing', () {
      final interceptor = PhiLeakInterceptor();
      final options = RequestOptions(path: '/v1/ping', data: 'pong');

      late RequestOptions captured;
      interceptor.onRequest(options, _CapturingRequestHandler((o) => captured = o));

      expect(captured.data, 'pong');
      expect(captured.extra.containsKey('phi_safe_body'), isFalse);
    });
  });
}

/// Test double that captures the RequestOptions passed to handler.next().
class _CapturingRequestHandler extends RequestInterceptorHandler {
  _CapturingRequestHandler(this._onNext);

  final void Function(RequestOptions) _onNext;

  @override
  void next(RequestOptions requestOptions) => _onNext(requestOptions);
}
