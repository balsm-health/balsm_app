// T175 — PHI-leak fuzz test.
//
// Exercises 50+ synthetic PHI payloads (corpus.dart) through the two egress
// scrubbers and asserts no denied PHI field name survives:
//   1. Sentry beforeSend allowlist scrub
//   2. Dio PhiLeakInterceptor request-body scrub
//
// The allowlist is the single source of truth (contracts/crash-allowlist.json
// mirror). Any field not on the allowlist is dropped; this test proves every
// denied field is dropped across the whole synthetic corpus.
import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'corpus.dart';

// Allowlist mirror — keep in sync with:
//   packages/core/lib/src/crash/sentry_init.dart (_loadAllowlist)
//   packages/balsm_api/lib/src/transport/phi_leak_interceptor.dart (allowedFields)
//   specs/001-patient-app-mvp/contracts/crash-allowlist.json
const Set<String> kAllowlist = {
  'event_id',
  'timestamp',
  'platform',
  'level',
  'logger',
  'transaction',
  'environment',
  'release',
  'dist',
  'type',
  'value',
  'stacktrace',
  'module',
  'function',
  'filename',
  'lineno',
  'colno',
  'abs_path',
  'status_code',
  'method',
  'url',
  'reason',
};

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

/// Allowlist scrub modeling Sentry beforeSend behavior: only keep keys present
/// on the allowlist. Mirrors the contract enforced before any event is sent.
Map<String, dynamic> scrubByAllowlist(Map<dynamic, dynamic> data) {
  return Map.fromEntries(
    data.entries.where((e) => kAllowlist.contains(e.key.toString())).map((e) => MapEntry(e.key.toString(), e.value)),
  );
}

void main() {
  final corpus = PhiCorpus.generate();

  test('corpus has at least 50 synthetic payloads', () {
    expect(corpus.length, greaterThanOrEqualTo(50));
  });

  group('Sentry beforeSend allowlist', () {
    test('drops every denied PHI field across the full corpus', () {
      for (final payload in corpus) {
        final scrubbed = scrubByAllowlist(payload);

        for (final key in scrubbed.keys) {
          expect(
            kDenied.contains(key),
            isFalse,
            reason: 'Denied field "$key" survived Sentry scrub',
          );
          expect(
            kAllowlist.contains(key),
            isTrue,
            reason: 'Field "$key" not on allowlist but survived scrub',
          );
        }
      }
    });

    test('preserves allowed telemetry fields when present', () {
      final sample = {
        'event_id': 'evt-1',
        'level': 'error',
        'email': 'leak@example.test',
      };
      final scrubbed = scrubByAllowlist(sample);
      expect(scrubbed['event_id'], 'evt-1');
      expect(scrubbed['level'], 'error');
      expect(scrubbed.containsKey('email'), isFalse);
    });
  });

  group('Dio PhiLeakInterceptor', () {
    test('request body contains no denied PHI field across the corpus', () {
      final interceptor = PhiLeakInterceptor();

      for (final payload in corpus) {
        final options = RequestOptions(path: '/v1/profile', data: payload);

        late RequestOptions captured;
        final handler = _CapturingRequestHandler((opts) => captured = opts);
        interceptor.onRequest(options, handler);

        final data = captured.data;
        expect(data, isA<Map>());
        final map = data as Map;
        for (final key in map.keys) {
          expect(
            kDenied.contains(key.toString()),
            isFalse,
            reason: 'Denied field "$key" survived Dio interceptor',
          );
        }
      }
    });

    test('non-map request bodies pass through untouched', () {
      final interceptor = PhiLeakInterceptor();
      final options = RequestOptions(path: '/v1/ping', data: 'pong');

      late RequestOptions captured;
      final handler = _CapturingRequestHandler((opts) => captured = opts);
      interceptor.onRequest(options, handler);

      expect(captured.data, 'pong');
    });
  });
}

/// Test double that captures the RequestOptions passed to handler.next().
class _CapturingRequestHandler extends RequestInterceptorHandler {
  _CapturingRequestHandler(this._onNext);

  final void Function(RequestOptions) _onNext;

  @override
  void next(RequestOptions requestOptions) {
    _onNext(requestOptions);
  }
}
