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
}
