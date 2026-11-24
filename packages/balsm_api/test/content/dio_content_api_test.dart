import 'dart:convert';

import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

/// A two-week payload in the server's shape. Placeholder copy only.
Map<String, dynamic> _payload({String version = 'v-test'}) => {
      'language': 'ar',
      'version': version,
      'source': 'مصدر تجريبي',
      'disclaimer': 'تنبيه تجريبي',
      'multiples_note': 'توائم تجريبي',
      'weeks': [
        for (final w in [4, 5])
          {
            'week': w,
            'title': 'عنوان $w',
            'body': 'نص $w',
          },
      ],
    };

/// [_payload] with the sources, sizes and labels the server added later.
Map<String, dynamic> _full() => _payload()
  ..['sources'] = [
    {
      'id': 'src-1',
      'title': 'Test page',
      'publisher': 'Test publisher',
      'url': 'https://example.test/',
      'accessed': '2026-11-24',
    },
  ]
  ..['danger_sign_labels'] = {
    'bleeding': 'نزيف',
  }
  ..['labels'] = {
    'sources_more': 'المصادر ({n})',
  }
  ..['topic_labels'] = {
    'visits': 'زيارات',
  }
  ..['illustration_credits'] = {
    'art': {
      'author': 'Test artist',
      'license': 'CC BY-ND 4.0',
      'license_url': 'https://example.test/licence',
      'author_url': 'https://example.test/',
      'text': 'رسم: فنان تجريبي',
    },
  }
  ..['test_labels'] = {
    'early_ultrasound': 'سونار مبكر',
  }
  ..['weeks'] = [
    for (final w in (_payload()['weeks'] as List).cast<Map<String, dynamic>>())
      {
        ...w,
        'fetal_size': {
          'length_mm': null,
          'weight_g': w['week'] == 5 ? 45 : null,
          'comparison': w['week'] == 4 ? 'بذرة' : null,
        },
        'tests_due': ['early_ultrasound'],
        'danger_signs': ['bleeding'],
        'topics': ['visits'],
        'illustration': w['week'] == 5
            ? {'key': 'pregnancy/week-05', 'credit': 'art', 'source_url': 'https://example.test/art'}
            : null,
        'sources': ['src-1'],
      },
  ];

void main() {
  group('DioContentApi.pregnancyWeeks', () {
    test('GETs the route, unwraps the envelope and keeps the ETag', () async {
      final adapter = FakeHttpAdapter(
        (_) => jsonResponse(
          jsonEncode({'data': _payload()}),
          headers: {
            'etag': ['"pw-1"'],
          },
        ),
      );

      final res = await DioContentApi(net: fakeNet(adapter)).pregnancyWeeks(lang: 'ar');

      expect(adapter.requests.single.path, ApiRoutes.content_pregnancy_weeks);
      expect(adapter.requests.single.queryParameters, {'lang': 'ar'});
      expect(adapter.requests.single.headers.containsKey('If-None-Match'), isFalse);
      final fresh = res as Modified<PregnancyWeeksResponse>;
      expect(fresh.etag, '"pw-1"');
      expect(fresh.value.version, 'v-test');
      expect(fresh.value.multiplesNote, 'توائم تجريبي');
      expect(fresh.value.language, 'ar');
      expect(fresh.value.weeks.map((w) => w.week), [4, 5]);
      expect(fresh.value.weeks.last.title, 'عنوان 5');
    });

    test('sends If-None-Match and maps an empty 304 to NotModified', () async {
      final adapter = FakeHttpAdapter((_) => ResponseBody.fromString('', 304));

      final res = await DioContentApi(net: fakeNet(adapter)).pregnancyWeeks(lang: 'ar', etag: '"pw-1"');

      expect(adapter.requests.single.headers['If-None-Match'], '"pw-1"');
      expect(res, isA<NotModified<PregnancyWeeksResponse>>());
    });

    test('a 401 surfaces as ApiException', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse('{}', status: 401));

      expect(
        () => DioContentApi(net: fakeNet(adapter)).pregnancyWeeks(lang: 'en'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('PregnancyWeeksResponse', () {
    test('toJson round-trips fromJson', () {
      final parsed = PregnancyWeeksResponse.fromJson(_full());

      final again = PregnancyWeeksResponse.fromJson(parsed.toJson());

      expect(again.toJson(), parsed.toJson());
    });

    test('reads the sources, sizes and labels', () {
      final parsed = PregnancyWeeksResponse.fromJson(_full());
      final (four, five) = (parsed.weeks.first, parsed.weeks.last);

      expect(parsed.sources.single.accessed, '2026-11-24');
      expect(parsed.dangerSignLabels['bleeding'], 'نزيف');
      expect(parsed.testLabels['early_ultrasound'], 'سونار مبكر');
      expect((four.fetalSize.lengthMm, four.fetalSize.weightG, four.fetalSize.comparison), (null, null, 'بذرة'));
      expect((five.fetalSize.weightG, five.fetalSize.comparison), (45, null));
      expect(five.testsDue, ['early_ultrasound']);
      expect(five.dangerSigns, ['bleeding']);
      expect(five.topics, ['visits']);
      expect(five.sources, ['src-1']);
      expect(four.illustration, isNull);
      expect((five.illustration!.key, five.illustration!.credit), ('pregnancy/week-05', 'art'));
      expect(parsed.illustrationCredits['art']!.text, 'رسم: فنان تجريبي');
      expect(parsed.labels['sources_more'], 'المصادر ({n})');
      expect(parsed.topicLabels['visits'], 'زيارات');
    });

    test('a copy cached before those fields reads them as empty', () {
      final parsed = PregnancyWeeksResponse.fromJson(_payload());
      final week = parsed.weeks.first;

      expect(parsed.sources, isEmpty);
      expect(parsed.dangerSignLabels, isEmpty);
      expect(parsed.testLabels, isEmpty);
      expect(parsed.labels, isEmpty);
      expect(parsed.topicLabels, isEmpty);
      expect((week.fetalSize.lengthMm, week.fetalSize.comparison, week.illustration), (null, null, null));
      expect(week.testsDue, isEmpty);
    });

    test('a text that is not a string arrives as empty, not a crash', () {
      final json = _payload()..['source'] = {'en': 'An old both-languages shape'};

      final parsed = PregnancyWeeksResponse.fromJson(json);

      expect(parsed.source, '');
    });

    test('a week without a number is skipped', () {
      final json = _payload();
      (json['weeks'] as List).add({
        'title': 'x',
      });

      expect(PregnancyWeeksResponse.fromJson(json).weeks, hasLength(2));
    });

    test('no version or no weeks is a FormatException', () {
      expect(() => PregnancyWeeksResponse.fromJson(_payload()..remove('version')), throwsFormatException);
      expect(() => PregnancyWeeksResponse.fromJson(_payload()..['weeks'] = <dynamic>[]), throwsFormatException);
    });
  });
}
