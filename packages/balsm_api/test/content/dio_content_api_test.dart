import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

/// A two-week payload in the server's shape. Placeholder copy only.
Map<String, dynamic> _payload({String version = 'v-test'}) => {
      'version': version,
      'source': {'en': 'Test source', 'ar': 'مصدر تجريبي'},
      'disclaimer': {'en': 'Test disclaimer', 'ar': 'تنبيه تجريبي'},
      'multiples_note': {'en': 'Test multiples', 'ar': 'توائم تجريبي'},
      'weeks': [
        for (final w in [4, 5])
          {
            'week': w,
            'title': {'en': 'Title $w', 'ar': 'عنوان $w'},
            'body': {'en': 'Body $w', 'ar': 'نص $w'},
          },
      ],
    };

void main() {
  group('DioContentApi.pregnancyWeeks', () {
    test('GETs the route, unwraps the envelope and keeps the ETag', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse(jsonEncode({'data': _payload()}), headers: {
            'etag': ['"pw-1"'],
          }));

      final res = await DioContentApi(net: fakeNet(adapter)).pregnancyWeeks();

      expect(adapter.requests.single.path, ApiRoutes.content_pregnancy_weeks);
      expect(adapter.requests.single.headers.containsKey('If-None-Match'), isFalse);
      final fresh = res as Modified<PregnancyWeeksResponse>;
      expect(fresh.etag, '"pw-1"');
      expect(fresh.value.version, 'v-test');
      expect(fresh.value.multiplesNote.ar, 'توائم تجريبي');
      expect(fresh.value.weeks.map((w) => w.week), [4, 5]);
      expect(fresh.value.weeks.last.title.en, 'Title 5');
    });

    test('sends If-None-Match and maps an empty 304 to NotModified', () async {
      final adapter = FakeHttpAdapter((_) => ResponseBody.fromString('', 304));

      final res = await DioContentApi(net: fakeNet(adapter)).pregnancyWeeks(etag: '"pw-1"');

      expect(adapter.requests.single.headers['If-None-Match'], '"pw-1"');
      expect(res, isA<NotModified<PregnancyWeeksResponse>>());
    });

    test('a 401 surfaces as ApiException', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 401));

      expect(
        () => DioContentApi(net: fakeNet(adapter)).pregnancyWeeks(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('PregnancyWeeksResponse', () {
    test('toJson round-trips fromJson', () {
      final parsed = PregnancyWeeksResponse.fromJson(_payload());

      final again = PregnancyWeeksResponse.fromJson(parsed.toJson());

      expect(again.toJson(), parsed.toJson());
    });

    test('a missing language arrives as empty, not a crash', () {
      final json = _payload()..['source'] = {'en': 'Only English'};

      final parsed = PregnancyWeeksResponse.fromJson(json);

      expect(parsed.source.ar, '');
    });

    test('a week without a number is skipped', () {
      final json = _payload();
      (json['weeks'] as List).add({
        'title': {'en': 'x'}
      });

      expect(PregnancyWeeksResponse.fromJson(json).weeks, hasLength(2));
    });

    test('no version or no weeks is a FormatException', () {
      expect(() => PregnancyWeeksResponse.fromJson(_payload()..remove('version')), throwsFormatException);
      expect(() => PregnancyWeeksResponse.fromJson(_payload()..['weeks'] = []), throwsFormatException);
    });
  });
}
