import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The version check: what a brand's manifest demands of an installed build.
void main() {
  const manifest = '''
  {
    "stores": { "ios": "https://apps.apple.com/app/id1", "android": "ftp://nope" },
    "min": { "ios": "1.0.0" },
    "versions": {
      "1.2.0": { "force": false, "platforms": ["ios", "android"], "notes": { "en": ["one-two"], "ar": ["واحد"] } },
      "1.3.0": { "force": true,  "platforms": ["ios"],            "notes": { "en": ["one-three"] } },
      "1.4.0": { "force": false, "platforms": ["ios", "android"], "date": "2026-10-09",
                 "notes": { "en": [ { "title": "Smarter reminders", "body": " Even offline. " },
                                    { "title": "" }, 7, { "body": "no title" }, "  Fixes  " ] } },
      "1.10.0": { "force": false, "platforms": ["macos"] }
    }
  }''';

  AppUpdateInfo eval(String installed, {String platform = 'ios', String? m = manifest, String lang = 'en'}) =>
      evaluateUpdate(installed: installed, manifest: m, platform: platform, lang: lang);

  group('compareVersions', () {
    test('compares numerically, not as text', () {
      expect(compareVersions('1.10.0', '1.9.3')! > 0, isTrue);
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('0.1.0+7', '0.1.0'), 0, reason: 'the build number is not the version');
    });

    test('an unreadable version compares to nothing', () {
      expect(compareVersions('abc', '1.0.0'), isNull);
      expect(compareVersions('1.0.0', ''), isNull);
    });
  });

  group('evaluateUpdate', () {
    test('the newest build owes nothing', () {
      expect(eval('1.4.0').status, UpdateStatus.none);
      expect(eval('2.0.0').status, UpdateStatus.none, reason: 'a build ahead of the manifest is fine');
    });

    test('a newer optional release is offered', () {
      final info = eval('1.3.0');
      expect(info.status, UpdateStatus.available);
      expect(info.latest, '1.4.0');
      expect(info.url, 'https://apps.apple.com/app/id1');
      expect(info.installed, '1.3.0');
    });

    test('the installed version is shown without its build number', () {
      expect(eval('1.3.0+42').installed, '1.3.0');
    });

    test('a forced release cannot be skipped by a later optional one', () {
      // 1.3.0 is forced; 1.4.0 after it is not. A 1.2.0 install is still forced.
      final info = eval('1.2.0');
      expect(info.status, UpdateStatus.required);
      expect(info.latest, '1.4.0', reason: 'it is sent to the newest, not the forced one');
    });

    test('a forced release behind the installed build no longer forces', () {
      expect(eval('1.3.0').status, UpdateStatus.available);
    });

    test('a release only counts on the platforms it names', () {
      // 1.3.0 is forced for iOS only.
      expect(eval('1.2.0', platform: 'android').status, UpdateStatus.available);
      expect(eval('1.2.0', platform: 'android').latest, '1.4.0');
      expect(eval('1.4.0', platform: 'macos').latest, '1.10.0');
    });

    test('below the platform minimum is required even with nothing forced', () {
      const m = '{"min": {"ios": "2.0.0"}, "versions": {}}';
      final info = eval('1.9.0', m: m);
      expect(info.status, UpdateStatus.required);
      expect(info.latest, '2.0.0');
      expect(eval('1.9.0', m: m, platform: 'android').status, UpdateStatus.none);
    });

    test('notes cover every release the build is behind, newest first', () {
      final notes = eval('1.1.0').notes;
      expect(notes.map((n) => n.version), ['1.4.0', '1.3.0', '1.2.0']);
      expect(notes[1].items.single.title, 'one-three');
    });

    test('a note is a title with an optional body, or just a string; bad entries are dropped', () {
      final note = eval('1.3.0').notes.single;
      expect(note.date, DateTime(2026, 10, 9));
      expect(note.items.map((i) => i.title), ['Smarter reminders', 'Fixes']);
      expect(note.items.first.body, 'Even offline.');
      expect(note.items.last.body, isEmpty);
    });

    test('notes are plain text: markup is not interpreted, and HTML strings are not notes', () {
      const m = '{"versions": {"2.0.0": {"notes": {"en": [{"title": "<b>Bold</b>", "body": "a &amp; b"}]}}, '
          '"2.1.0": {"notes": {"en": "<p>old html form</p>"}}}}';
      final notes = eval('1.0.0', m: m).notes;
      expect(notes.single.version, '2.0.0', reason: 'a string where a list belongs is ignored');
      expect(notes.single.items.single.title, '<b>Bold</b>');
      expect(notes.single.items.single.body, 'a &amp; b');
    });

    test('a release with no usable notes contributes none', () {
      const m = '{"versions": {"2.0.0": {"notes": {"en": []}}, "2.1.0": {"notes": {"en": ["  "]}}, "2.2.0": {}}}';
      final info = eval('1.0.0', m: m);
      expect(info.status, UpdateStatus.available);
      expect(info.notes, isEmpty);
    });

    test('notes come in the asked language, falling back to English', () {
      final notes = eval('1.1.0', lang: 'ar').notes;
      expect(notes.last.items.single.title, 'واحد');
      expect(notes.first.items.first.title, 'Smarter reminders', reason: '1.4.0 has no Arabic');
    });

    test('a non-https store link is not followed', () {
      expect(eval('1.2.0', platform: 'android').url, kAppDownloadUrl);
    });

    test('fails open: a bad manifest never blocks the app', () {
      for (final m in <String?>[
        null,
        '',
        'not json',
        '[]',
        '{"versions": "nope"}',
        '{"versions": {"x.y": {"force": true}}}',
        '{"versions": {"9.0.0": "nope"}}',
        '{"min": {"ios": "soon"}}',
      ]) {
        expect(eval('0.0.1', m: m).status, UpdateStatus.none, reason: 'manifest: $m');
      }
    });

    test('a build the manifest does not list is left alone', () {
      // Dev and unreleased builds must not be treated as retired.
      expect(eval('1.3.5').status, UpdateStatus.available);
      expect(eval('7.7.7').status, UpdateStatus.none);
    });

    test('an unreadable installed version is left alone', () {
      expect(eval('dev').status, UpdateStatus.none);
    });
  });

  group('full release notes link', () {
    test('is narrowed to this build: brand, platform, language, installed version', () {
      final uri = Uri.parse(evaluateUpdate(
        installed: '1.2.0+9',
        manifest: manifest,
        platform: 'ios',
        lang: 'ar',
        brand: AppBrand.balsm_pro,
      ).notesUrl!);
      expect('${uri.scheme}://${uri.host}${uri.path}', kReleaseNotesUrl);
      expect(uri.queryParameters, {'brand': 'balsm_pro', 'from': '1.2.0', 'platform': 'ios', 'lang': 'ar'});
    });

    test('a manifest may point somewhere else, over https only', () {
      const base = '{"versions": {"2.0.0": {}}, "more": ';
      final custom = Uri.parse(eval('1.0.0', m: '$base"https://pro.balsm.health/notes?x=1"}').notesUrl!);
      expect(custom.host, 'pro.balsm.health');
      expect(custom.queryParameters['x'], '1');
      expect(custom.queryParameters['from'], '1.0.0');
      expect(eval('1.0.0', m: '$base"javascript:alert(1)"}').notesUrl, startsWith(kReleaseNotesUrl));
      expect(eval('1.0.0', m: '${base}7}').notesUrl, startsWith(kReleaseNotesUrl));
    });

    test('nothing to update, nothing to link', () {
      expect(eval('9.9.9').notesUrl, isNull);
    });
  });

  group('per brand', () {
    test('every brand reads its own manifest', () {
      expect(appVersionUrl(AppBrand.balsm), 'https://app.balsm.health/version/balsm.json');
      expect(appVersionUrl(AppBrand.balsm_pro), 'https://app.balsm.health/version/balsm_pro.json');
      expect({for (final b in AppBrand.values) appVersionUrl(b)}.length, AppBrand.values.length);
    });

    test('a brand is named in the language of the sentence around it', () {
      expect(AppBrand.balsm.nameIn('en'), 'Balsm');
      expect(AppBrand.balsm_pro.nameIn('en'), 'Balsm Pro');
      expect(AppBrand.balsm.nameIn('ar'), 'بلسم');
      expect(AppBrand.balsm_pro.nameIn('ar'), 'بلسم برو');
    });
  });
}
