import 'dart:async';

import 'package:app/balsm_app/deep_link_handler.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for bugs found on a device (iOS simulator, app_links 6.4.1):
/// re-creating the handler killed live link delivery, and replayed an old link
/// on every re-creation. The inbox is the process-wide fix.
void main() {
  late StreamController<Uri> platform;
  setUp(() => platform = StreamController<Uri>.broadcast());
  tearDown(() => platform.close());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a link that arrives before any handler is attached is queued, not lost', () async {
    final inbox = DeepLinkInbox.forTest(platform.stream);
    platform.add(Uri.parse('balsm://meds'));
    await settle();

    final got = <Uri>[];
    inbox.attach(got.add);
    expect(got, [Uri.parse('balsm://meds')]);
  });

  test('the launch link is delivered once', () async {
    final inbox = DeepLinkInbox.forTest(platform.stream, launchLink: Future.value(Uri.parse('balsm://checkin')));
    final got = <Uri>[];
    inbox.attach(got.add);
    await settle();
    expect(got, [Uri.parse('balsm://checkin')]);
  });

  test('a re-created handler keeps receiving live links after the old one disposes', () async {
    // The device bug: the NEW handler attaches, THEN the old one's dispose runs.
    // The old dispose must not cut the new one off.
    final inbox = DeepLinkInbox.forTest(platform.stream);
    final oldHandler = <Uri>[];
    final newHandler = <Uri>[];
    inbox.attach(oldHandler.add);
    inbox.attach(newHandler.add);
    inbox.detach(oldHandler.add);

    platform.add(Uri.parse('balsm://meds'));
    await settle();
    expect(newHandler, [Uri.parse('balsm://meds')]);
    expect(oldHandler, isEmpty);
  });

  test('re-attaching never replays an earlier link', () async {
    // The other half of the device bug: after one /map link, every re-created
    // handler re-received it and pulled the app back to the map.
    final inbox = DeepLinkInbox.forTest(platform.stream);
    final first = <Uri>[];
    inbox.attach(first.add);
    platform.add(Uri.parse('balsm://map?type=lab'));
    await settle();

    final second = <Uri>[];
    inbox.attach(second.add);
    await settle();
    expect(second, isEmpty);
  });

  test('an immediate identical echo is dropped; a different link is not', () async {
    final inbox = DeepLinkInbox.forTest(platform.stream);
    final got = <Uri>[];
    inbox.attach(got.add);
    platform
      ..add(Uri.parse('balsm://t/abc#k=key'))
      ..add(Uri.parse('balsm://t/abc#k=key')) // iOS cold-start echo
      ..add(Uri.parse('balsm://meds'));
    await settle();
    expect(got, [Uri.parse('balsm://t/abc#k=key'), Uri.parse('balsm://meds')]);
  });
}
