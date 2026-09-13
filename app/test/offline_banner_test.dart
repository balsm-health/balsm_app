import 'package:app/balsm_app/offline_banner.dart';
import 'dart:async';
import 'package:core/core.dart' show onlineProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Stream<bool> online) => ProviderScope(
      overrides: [onlineProvider.overrideWith((ref) => online)],
      child: const MaterialApp(
        home: Scaffold(body: OfflineBanner(message: 'No connection')),
      ),
    );

/// A stand-in for a page header, which is what the banner was covering.
const _headerKey = Key('header');

Widget _hostWithHeader(Stream<bool> online, {required bool inFlow}) => ProviderScope(
      overrides: [onlineProvider.overrideWith((ref) => online)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              const header = SizedBox(key: _headerKey, height: 60, child: Text('Header'));
              const banner = OfflineBanner(message: 'No connection');
              // inFlow: the fix. Otherwise: the original overlay, kept so the
              // test proves it actually catches the bug.
              return inFlow
                  ? const Column(children: [banner, Expanded(child: header)])
                  : const Stack(children: [header, Positioned(top: 0, left: 0, right: 0, child: banner)]);
            },
          ),
        ),
      ),
    );

void main() {
  testWidgets('hidden while online', (t) async {
    await t.pumpWidget(_host(Stream.value(true)));
    await t.pump();
    expect(find.text('No connection'), findsNothing);
  });

  testWidgets('shown while offline', (t) async {
    await t.pumpWidget(_host(Stream.value(false)));
    await t.pump();
    expect(find.text('No connection'), findsOneWidget);
  });

  testWidgets('hidden before connectivity is known', (t) async {
    await t.pumpWidget(_host(const Stream<bool>.empty()));
    await t.pump();
    expect(find.text('No connection'), findsNothing,
        reason: 'an unknown state must not be reported as offline — it would '
            'flash the banner on every launch');
  });

  testWidgets('appears and disappears as connectivity changes', (t) async {
    final controller = StreamController<bool>();
    addTearDown(controller.close);
    await t.pumpWidget(_host(controller.stream));

    controller.add(false);
    // Two pumps: the first lets the stream event reach the provider, the
    // second rebuilds with it.
    await t.pump();
    await t.pump();
    expect(find.text('No connection'), findsOneWidget);

    controller.add(true);
    await t.pump();
    await t.pump();
    expect(find.text('No connection'), findsNothing);
  });

  group('layout', () {
    // Regression: the first version mounted the banner in a Stack at top:0, so
    // it painted over each page's header instead of pushing it down. A screen's
    // top spacing comes from PadTop inside the page, not from any inset the
    // shell reserves, so an overlay always covers it.
    testWidgets('in flow, the banner sits entirely above the header', (t) async {
      await t.pumpWidget(_hostWithHeader(Stream.value(false), inFlow: true));
      await t.pump();

      final banner = t.getRect(find.text('No connection'));
      final header = t.getRect(find.byKey(_headerKey));

      expect(banner.bottom, lessThanOrEqualTo(header.top),
          reason: 'the banner must push the header down, never cover it');
    });

    testWidgets('the overlay version really did overlap — the bug this guards', (t) async {
      await t.pumpWidget(_hostWithHeader(Stream.value(false), inFlow: false));
      await t.pump();

      final banner = t.getRect(find.text('No connection'));
      final header = t.getRect(find.byKey(_headerKey));

      expect(banner.bottom, greaterThan(header.top),
          reason: 'if this ever passes as non-overlapping, the test above proves nothing');
    });

    testWidgets('online, nothing is inserted above the header', (t) async {
      await t.pumpWidget(_hostWithHeader(Stream.value(true), inFlow: true));
      await t.pump();

      expect(t.getRect(find.byKey(_headerKey)).top, 0,
          reason: 'the layout must not shift while the connection is fine');
    });
  });
}
