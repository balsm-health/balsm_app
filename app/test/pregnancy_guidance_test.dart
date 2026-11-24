import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/family/profile_family_members.dart';
import 'package:app/balsm_app/flags.dart';
import 'package:app/balsm_app/pregnancy/api_pregnancy_guidance.dart';
import 'package:app/balsm_app/pregnancy/profile_pregnancy_babies.dart';
import 'package:app/balsm_app/screens/pregnancy/pregnancy_guidance.dart';
import 'package:app/balsm_app/screens/pregnancy/pregnancy_screen.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flag_overrides.dart';

/// Weekly pregnancy guidance: the API adapter that keeps the last good copy on
/// the device, the card on the pregnancy screen and "Week by week". All copy
/// here is invented test text — no partner content, nothing about a patient.
PregnancyWeeksResponse _content({String version = 'v-test'}) => PregnancyWeeksResponse.fromJson({
      'version': version,
      'source': {'en': 'Test Source Org', 'ar': 'جهة تجريبية'},
      'disclaimer': {'en': 'Test disclaimer.', 'ar': 'تنبيه تجريبي.'},
      'multiples_note': {'en': 'Test multiples note', 'ar': 'ملاحظة توائم تجريبية'},
      'labels': {
        for (final (k, en) in [
          ('size_title', 'Test size'),
          ('size_about', 'Test about {thing}'),
          ('size_length', 'Test length {value}'),
          ('size_weight', 'Test weight {value}'),
          ('unit_mm', 'mm'),
          ('unit_cm', 'cm'),
          ('unit_g', 'g'),
          ('unit_kg', 'kg'),
          ('tests_due', 'Test tests heading'),
          ('dangers_now', 'Test call now'),
          ('dangers_all', 'Test signs to know'),
          ('topics_title', 'Test topics heading'),
          ('sources_title', 'Test sources heading'),
          ('sources_more', 'Test sources ({n}) and more'),
          ('illustration', 'Test week {week} art'),
        ])
          k: {'en': en, 'ar': 'ع $en'},
      },
      'topic_labels': {
        'movements': {'en': 'Test movements', 'ar': 'حركة تجريبية'},
      },
      'sources': [
        {
          'id': 's1',
          'title': 'Test guideline',
          'publisher': 'Test publisher',
          'url': 'https://example.test/g',
          'accessed': '2026-11-24',
        },
      ],
      'danger_sign_labels': {
        'bleeding': {'en': 'Test bleeding', 'ar': 'نزيف تجريبي'},
        'fever': {'en': 'Test fever', 'ar': 'حرارة تجريبية'},
      },
      'test_labels': {
        'gdm': {'en': 'Test sugar test', 'ar': 'تحليل تجريبي'},
      },
      'weeks': [
        for (var w = 4; w <= 40; w++)
          {
            'week': w,
            'title': {'en': 'Test title $w', 'ar': 'عنوان تجريبي $w'},
            'body': {'en': 'Test body $w ($version)', 'ar': 'نص تجريبي $w'},
            // Week 24 is the current week in the screen tests: a size, a
            // test, topics (one with no label) and no danger sign;
            // week 25 warns of bleeding.
            'fetal_size': {'length_mm': w == 24 ? 210 : null, 'weight_g': w == 24 ? 630 : null, 'comparison': null},
            'tests_due': [if (w == 24) 'gdm'],
            'danger_signs': [if (w == 25) 'bleeding'],
            'topics': [
              if (w == 24) ...['movements', 'not-a-topic'],
            ],
            'illustration': null,
            'sources': ['s1'],
          },
      ],
    });

const _offline = ApiException(code: 'offline', isOffline: true);

void main() {
  const user = UserId.value('u-guidance-test');
  late GlobalKVDataSource kv;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    kv = await SharedPrefsKVDataSource.create();
  });

  group('ApiPregnancyGuidance', () {
    test('keeps the first copy with its ETag, then revalidates with it and gets 304', () async {
      final api = FakeContentApi(weeks: _content(), etag: '"e1"');
      final source = ApiPregnancyGuidance(api: api, kv: kv);

      expect(await source.cached(), isNull);
      final first = await source.refresh();
      final second = await source.refresh();

      expect(first!.forWeek(24)!.title.en, 'Test title 24');
      expect(second!.version, 'v-test');
      expect(api.sentEtags, [null, '"e1"']);
      expect((await kv.get<Map<String, dynamic>>(ApiPregnancyGuidance.storageKey))!['etag'], '"e1"');
    });

    test('a copy kept in the older shape (before labels) is not used: it is fetched again', () async {
      await kv.put<Map<String, dynamic>>('content.pregnancy_weeks.v1', {'etag': '"e1"', 'data': _content().toJson()});
      final api = FakeContentApi(weeks: _content(), etag: '"e1"');
      final source = ApiPregnancyGuidance(api: api, kv: kv);

      expect(await source.cached(), isNull);
      await source.refresh();

      expect(api.sentEtags, [null], reason: 'no ETag from the old copy, so the server sends the full body');
    });

    test('a new version replaces the kept copy', () async {
      final api = FakeContentApi(weeks: _content(), etag: '"e1"');
      final source = ApiPregnancyGuidance(api: api, kv: kv);
      await source.refresh();

      api
        ..weeks = _content(version: 'v2')
        ..etag = '"e2"';
      final fresh = await source.refresh();

      expect(fresh!.version, 'v2');
      expect((await source.cached())!.version, 'v2');
    });

    test('offline after the first fetch: the kept copy', () async {
      final api = FakeContentApi(weeks: _content());
      final source = ApiPregnancyGuidance(api: api, kv: kv);
      await source.refresh();

      api.failWith = _offline;

      expect((await source.refresh())!.version, 'v-test');
      expect((await ApiPregnancyGuidance(api: api, kv: kv).cached())!.forWeek(4)!.body.en, 'Test body 4 (v-test)');
    });

    test('nothing kept and the fetch fails: null, no throw', () async {
      final source = ApiPregnancyGuidance(api: FakeContentApi()..failWith = _offline, kv: kv);

      expect(await source.refresh(), isNull);
      expect(await ApiPregnancyGuidance(api: FakeContentApi(), kv: kv).refresh(), isNull, reason: '404');
    });

    test('an unreadable kept copy counts as none and is replaced', () async {
      await kv.put<Map<String, dynamic>>(ApiPregnancyGuidance.storageKey, {'etag': '"old"', 'data': 'garbage'});
      final api = FakeContentApi(weeks: _content());
      final source = ApiPregnancyGuidance(api: api, kv: kv);

      expect(await source.cached(), isNull);
      expect((await source.refresh())!.version, 'v-test');
      expect(api.sentEtags, [null]);
    });
  });

  group('screens', () {
    late AppDatabase db;
    late FakeContentApi api;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      api = FakeContentApi(weeks: _content());
    });
    tearDown(() => db.close());

    PatientAppState state({LanguageCode lang = LanguageCode.en}) {
      final flags = flagsWith({AppFlags.motherChild: true});
      return PatientAppState()
        ..lang = lang
        ..attachFlags(flags);
    }

    Future<ProviderContainer> pump(WidgetTester tester, Widget screen, PatientAppState s) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final container = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWithValue(user),
          globalKVDataSourceProvider.overrideWithValue(kv),
          familyMembersPortProvider.overrideWith(profileFamilyMembersPort),
          pregnancyBabiesPortProvider.overrideWith(profilePregnancyBabiesPort),
          contentApiProvider.overrideWithValue(api),
          pregnancyGuidanceSourceProvider.overrideWith(apiPregnancyGuidanceSource),
          accountSummaryProvider.overrideWith(
            (ref) async => const AccountSummary(
              id: user,
              displayName: 'Test Mother',
              countryCode: 'EG',
              preferredLanguage: 'en',
              deletionState: 'ACTIVE',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: AppScope(
            state: s,
            child: MaterialApp(
              builder: (_, child) => Directionality(textDirection: s.dir, child: child!),
              home: Scaffold(body: screen),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    /// A pregnancy 110 days before its due date — week 24.
    Future<void> start(ProviderContainer c, {int babies = 1}) async {
      final self = await c.read(selfProfileIdProvider.future);
      final now = DateTime.now();
      await c.read(startPregnancyUseCaseProvider)(
        motherId: self!,
        dueDate: now.add(const Duration(days: 110)),
        babyCount: babies,
        now: now,
      );
    }

    testWidgets(
        "the card shows this week's guidance and compact guide, source and disclaimer; one baby, no multiples note",
        (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      await start(await pump(tester, const SizedBox(), s));
      await pump(tester, const PregnancyScreen(), s);

      expect(find.text(p.guidance_week(24)), findsOne);
      expect(find.text(p.all_weeks), findsOne);
      expect(find.text('Test title 24'), findsOne);
      expect(find.text('Test body 24 (v-test)'), findsOne);
      expect(find.text('Test disclaimer. Test Source Org.'), findsOne);
      expect(find.text('Test multiples note'), findsNothing);
      expect(find.text('Test size'), findsOne);
      expect(find.text('Test length 21 cm · Test weight 630 g'), findsOne);
      expect(find.text('Test tests heading'), findsOne);
      expect(find.text('Test sugar test'), findsOne);
      expect(find.text('Test movements'), findsOne);
      expect(find.text('not-a-topic'), findsNothing, reason: 'a topic the content does not name is left out');
      expect(
        find.text('Test signs to know'),
        findsNothing,
        reason: 'the compact guide has no danger list for a quiet week',
      );
      expect(find.text('Test sources (1) and more'), findsOne);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Test week 24 art'), findsOne);
      expect(
        find.text('Test guideline', findRichText: true),
        findsNothing,
        reason: 'sources are listed in Week by week',
      );
      expect(api.sentEtags, isNotEmpty, reason: 'opening the screen asks the server');
    });

    testWidgets('twins: the card carries the multiples note', (tester) async {
      final s = state();
      await start(await pump(tester, const SizedBox(), s), babies: 2);
      await pump(tester, const PregnancyScreen(), s);

      expect(find.text('Test multiples note'), findsOne);
    });

    testWidgets('Arabic: the copy comes in Arabic', (tester) async {
      final s = state(lang: LanguageCode.ar);
      final p = s.strings.pregnancy;
      await start(await pump(tester, const SizedBox(), s));
      await pump(tester, const PregnancyScreen(), s);

      expect(find.text(p.guidance_week(24)), findsOne);
      expect(find.text('عنوان تجريبي 24'), findsOne);
      expect(find.text('تنبيه تجريبي. جهة تجريبية.'), findsOne);
      expect(find.text('Test title 24'), findsNothing);
    });

    testWidgets('no guidance kept and none fetched: no card, no error', (tester) async {
      api.failWith = _offline;
      final s = state();
      final p = s.strings.pregnancy;
      await start(await pump(tester, const SizedBox(), s));
      await pump(tester, const PregnancyScreen(), s);

      expect(find.text(p.guidance_week(24)), findsNothing);
      expect(find.text(p.all_weeks), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('offline after a fetch: the kept guidance still shows', (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      await start(await pump(tester, const SizedBox(), s));
      await pump(tester, const PregnancyScreen(), s);
      await tester.pumpWidget(const SizedBox());

      api.failWith = _offline;
      await pump(tester, const PregnancyScreen(), s);

      expect(find.text(p.guidance_week(24)), findsOne);
      expect(find.text('Test title 24'), findsOne);
    });

    testWidgets('"All weeks" opens Week by week with the current week open and scrolled to', (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      await start(await pump(tester, const SizedBox(), s));
      await pump(tester, const PregnancyScreen(), s);

      await tester.tap(find.text(p.all_weeks));
      await tester.pumpAndSettle();

      expect(find.byType(PregnancyWeeksScreen), findsOne);
      expect(find.text(p.weeks_title), findsOne);
      expect(find.text('${p.this_week} · Test title 24'), findsOne);
      expect(find.text('Test body 24 (v-test)'), findsOne);
      expect(find.text('Test body 23 (v-test)'), findsNothing, reason: 'only the current week starts open');
      expect(find.text('Test title 23'), findsOne, reason: 'a closed week shows its title');
      expect(tester.getRect(find.text(p.week_n(24))).top, inInclusiveRange(0, 400), reason: 'scrolled to the top');
      expect(tester.getRect(find.text(p.week_n(4))).bottom, lessThan(0), reason: 'earlier weeks scrolled past');
    });

    testWidgets('Week by week: tapping another week opens it and closes the current one', (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      await start(await pump(tester, const SizedBox(), s));
      await pump(tester, const PregnancyWeeksScreen(), s);

      await tester.tap(find.text(p.week_n(25)));
      await tester.pumpAndSettle();

      expect(find.text('Test body 25 (v-test)'), findsOne);
      expect(find.text('Test body 24 (v-test)'), findsNothing);
    });

    testWidgets("Week by week: a week's warnings, its sources, and every danger sign behind a fold on a quiet week",
        (tester) async {
      final s = state();
      final p = s.strings.pregnancy;
      await start(await pump(tester, const SizedBox(), s));
      await pump(tester, const PregnancyWeeksScreen(), s);

      expect(find.text('Test signs to know'), findsOne, reason: 'week 24 warns of nothing');
      expect(find.text('Test bleeding'), findsNothing);
      await tester.tap(find.text('Test signs to know'));
      await tester.pumpAndSettle();
      expect(find.text('Test bleeding'), findsOne);
      expect(find.text('Test fever'), findsOne);
      expect(find.text('Test topics heading'), findsOne);
      expect(find.text('Test sources heading'), findsOne);
      expect(find.text('Test guideline — Test publisher', findRichText: true), findsOne);

      await tester.tap(find.text(p.week_n(25)));
      await tester.pumpAndSettle();
      expect(find.text('Test call now'), findsOne);
      expect(find.text('Test bleeding'), findsOne);
      expect(find.text('Test fever'), findsNothing, reason: 'only the signs week 25 names');
    });
  });
}
