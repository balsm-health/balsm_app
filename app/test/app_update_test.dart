import 'dart:io';

import 'package:app/balsm_app/app_state.dart';
import 'package:app/update/release_notes_html.dart';
import 'package:app/update/update_gate.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The update sheet as an app shell mounts it, and the manifests bundled with
/// the web app. What a manifest demands of a build is tested in core
/// (`packages/core/test/update/`).
UpdateCopy copyFor(PatientAppState s, AppBrand brand) {
  final u = s.strings.update;
  final name = brand.nameIn(s.lang.value);
  return UpdateCopy(
    eyebrowNew: u.upd_eyebrow_new,
    eyebrowRequired: u.upd_eyebrow_required,
    availableTitle: u.upd_available_t(name),
    availableBody: u.upd_available_b,
    requiredTitle: u.upd_required_t(name),
    requiredBody: u.upd_required_b,
    current: u.upd_current,
    newVersion: u.upd_new,
    whatsNew: u.upd_whats_new,
    updateNow: u.upd_now,
    skip: u.upd_skip,
    fullNotes: u.upd_full_notes,
    close: s.strings.common.a11y_close,
  );
}

void main() {
  group('release notes HTML', () {
    Future<void> pumpNotes(WidgetTester tester, String html) => tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ReleaseNotesHtml(html: html, ar: false, linkColor: Colors.blue)),
        ));

    String allText(WidgetTester tester) =>
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.textSpan?.toPlainText() ?? t.data ?? '').join('|');

    testWidgets('renders paragraphs, lists and inline emphasis', (tester) async {
      await pumpNotes(tester, '''
        <h3>Highlights</h3>
        <p>Faster <b>sync</b> and <a href="https://balsm.health/x">details</a>.</p>
        <ul><li>First</li><li>Second</li></ul>
        <ol><li>Alpha</li><li>Beta</li></ol>''');
      final text = allText(tester);
      expect(text, contains('Highlights'));
      expect(text, contains('Faster sync and details.'));
      expect(text, contains('•|First'));
      expect(text, contains('1.|Alpha'));
      expect(text, contains('2.|Beta'));
    });

    testWidgets('scripts, styles and images contribute nothing', (tester) async {
      await pumpNotes(
          tester,
          '<p>Safe</p><script>alert(1)</script><style>p{color:red}</style>'
          '<img src="https://evil.example/x.png" onerror="x()"><iframe src="https://evil.example"></iframe>');
      final text = allText(tester);
      expect(text, 'Safe');
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('only https links are tappable', (tester) async {
      await pumpNotes(tester, '<p><a href="javascript:alert(1)">bad</a> <a href="https://balsm.health">good</a></p>');
      final rich = tester.widget<Text>(find.byType(Text).first).textSpan! as TextSpan;
      final spans = rich.children!.cast<TextSpan>();
      expect(spans.firstWhere((s) => s.text == 'bad').recognizer, isNull);
      expect(spans.firstWhere((s) => s.text == 'good').recognizer, isNotNull);
    });

    testWidgets('unknown tags keep their text', (tester) async {
      await pumpNotes(tester, '<marquee>Still <span>readable</span></marquee>');
      expect(allText(tester), 'Still readable');
    });

    testWidgets('empty or whitespace notes render nothing and do not throw', (tester) async {
      await pumpNotes(tester, '  <p> </p>  ');
      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('UpdateGate', () {
    const notes = [
      ReleaseNote(version: '1.4.0', items: [
        ReleaseNoteItem(icon: 'bell-ring', title: 'Smarter dose reminders', body: 'Even <b>offline</b>.'),
        ReleaseNoteItem(icon: 'no-such-icon', title: 'Fixes and polish'),
      ]),
      ReleaseNote(version: '1.3.0', html: '<p>Security fix</p>'),
    ];
    const optional = AppUpdateInfo(
        status: UpdateStatus.available,
        installed: '1.2.0',
        latest: '1.4.0',
        notes: notes,
        notesUrl: 'https://app.balsm.health/whats-new?brand=balsm&from=1.2.0');
    const forced = AppUpdateInfo(status: UpdateStatus.required, installed: '1.2.0', latest: '1.4.0', notes: notes);

    late UpdateCopy copy;

    Future<PatientAppState> pump(
      WidgetTester tester,
      AppUpdateInfo info, {
      bool ar = false,
      AppBrand brand = AppBrand.balsm,
      Size size = const Size(390, 844),
    }) async {
      final state = PatientAppState();
      if (ar) state.setLang(LanguageCode.ar);
      copy = copyFor(state, brand);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
          builder: (context, child) => UpdateGate(
            brand: brand,
            lang: state.lang.value,
            look: UpdateLook(
                rtl: state.rtl, accent: state.accent, copy: copy, mark: const SizedBox(width: 52, height: 52)),
            cached: (_) async => AppUpdateInfo.none,
            check: (_) async => info,
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('app'))),
        ),
      ));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('shows nothing when up to date', (tester) async {
      await pump(tester, AppUpdateInfo.none);
      expect(find.text('app').hitTestable(), findsOne);
      expect(find.byType(UpdateSheet), findsNothing);
    });

    testWidgets('asks for release notes in the app language', (tester) async {
      String? asked;
      final state = PatientAppState()..setLang(LanguageCode.ar);
      await tester.pumpWidget(AppScope(
        state: state,
        child: MaterialApp(
          builder: (context, child) => UpdateGate(
            brand: AppBrand.balsm,
            lang: state.lang.value,
            look: UpdateLook(
                rtl: true, accent: state.accent, copy: copyFor(state, AppBrand.balsm), mark: const SizedBox()),
            cached: (_) async => AppUpdateInfo.none,
            check: (lang) async {
              asked = lang;
              return AppUpdateInfo.none;
            },
            child: child!,
          ),
          home: const Scaffold(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(asked, 'ar');
    });

    testWidgets('the sheet shows current and new versions and what is new', (tester) async {
      await pump(tester, optional);
      expect(find.text(copy.eyebrowNew.toUpperCase()), findsOne);
      expect(find.text(copy.availableTitle), findsOne);
      expect(find.text('v1.2.0'), findsOne);
      expect(find.text('v1.4.0'), findsOne);
      expect(find.text(copy.whatsNew.toUpperCase()), findsOne);
      expect(find.text('Smarter dose reminders'), findsOne);
      expect(find.text('Fixes and polish'), findsOne);
      // The older release sits under its own version, with its HTML rendered.
      expect(find.text('v1.3.0'), findsOne);
      expect(find.byType(ReleaseNotesHtml), findsExactly(2));
      expect(find.text(copy.fullNotes), findsOne);
    });

    testWidgets('an optional update can be skipped, and stays skipped', (tester) async {
      await pump(tester, optional);
      await tester.tap(find.text(copy.skip));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateSheet), findsNothing);
      expect(find.text('app').hitTestable(), findsOne);
    });

    testWidgets('an optional update closes from the X and from the scrim', (tester) async {
      await pump(tester, optional);
      await tester.tap(find.bySemanticsLabel(copy.close));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateSheet), findsNothing);

      await pump(tester, optional);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateSheet), findsNothing);
    });

    testWidgets('a required update offers no way round', (tester) async {
      await pump(tester, forced);
      expect(find.text(copy.eyebrowRequired.toUpperCase()), findsOne);
      expect(find.text(copy.requiredTitle), findsOne);
      expect(find.text(copy.updateNow), findsOne);
      expect(find.text(copy.skip), findsNothing);
      expect(find.bySemanticsLabel(copy.close), findsNothing);
      expect(find.text(copy.fullNotes), findsNothing, reason: 'this fixture carries no notes link');

      // The scrim does not dismiss it, and the app behind is unreachable.
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.byType(UpdateSheet), findsOne);
      expect(find.text('app').hitTestable(), findsNothing);
    });

    testWidgets('with no notes the sheet still stands', (tester) async {
      await pump(tester, const AppUpdateInfo(status: UpdateStatus.available, installed: '1.0.0', latest: '1.1.0'));
      expect(find.text(copy.whatsNew.toUpperCase()), findsNothing);
      expect(find.text(copy.updateNow), findsOne);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long notes scroll and the button stays reachable on a small phone', (tester) async {
      final long = AppUpdateInfo(status: UpdateStatus.required, installed: '1.0.0', latest: '1.9.0', notes: [
        for (var i = 9; i > 0; i--)
          ReleaseNote(version: '1.$i.0', items: [
            for (var k = 0; k < 5; k++)
              ReleaseNoteItem(
                  title: 'Change $k of release $i', body: 'A fairly long description of what changed here.'),
          ]),
      ]);
      await pump(tester, long, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
      expect(find.text(copy.updateNow).hitTestable(), findsOne);
    });

    testWidgets('another brand gets its own name, in either language', (tester) async {
      await pump(tester, forced, brand: AppBrand.balsm_pro);
      expect(find.text('Update Balsm Pro to continue'), findsOne);

      await pump(tester, optional, brand: AppBrand.balsm_pro, ar: true);
      expect(find.textContaining('بلسم برو'), findsOne);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out in Arabic', (tester) async {
      await pump(tester, forced, ar: true);
      expect(tester.takeException(), isNull);
    });

    test('an unknown note icon still draws something', () {
      expect(releaseNoteIcon('no-such-icon'), releaseNoteIcon(''));
      expect(releaseNoteIcon('bell-ring'), isNot(releaseNoteIcon('')));
    });
  });

  test('every brand with a bundled manifest ships a valid one that blocks nobody', () {
    final files = Directory('web/version').listSync().whereType<File>().toList();
    expect(files.map((f) => f.uri.pathSegments.last), contains('balsm.json'));
    for (final f in files) {
      final brand = f.uri.pathSegments.last.replaceAll('.json', '');
      // The file name is the brand id the app asks for.
      expect(AppBrand.values.map((b) => b.name), contains(brand), reason: 'unknown brand file: $brand');
      _checkBundled(f.readAsStringSync(), brand);
    }
  });
}

void _checkBundled(String m, String brand) {
  AppUpdateInfo eval(String installed, {required String platform, required String m}) =>
      evaluateUpdate(installed: installed, manifest: m, platform: platform);
  {
    for (final p in ['ios', 'android', 'macos']) {
      expect(eval('0.1.0', platform: p, m: m).status, UpdateStatus.none, reason: '$brand/$p');
      // An older build gets an offer with notes, proving the file parses.
      final old = eval('0.0.9', platform: p, m: m);
      expect(old.status, isNot(UpdateStatus.none), reason: '$brand/$p');
      expect(old.url, startsWith('https://'));
    }
  }
}
