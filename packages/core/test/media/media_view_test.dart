import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_source/media_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A 1×1 transparent PNG.
final Uint8List _png =
    base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

const _gender = MediaAxis(
  id: 'gender',
  source: MediaAxisSource.user,
  label: 'Baby',
  options: [MediaOption(value: 'girl', label: 'Girl'), MediaOption(value: 'boy', label: 'Boy')],
  defaultValue: 'girl',
);

final _media = Media(
  alt: 'Week 12 illustration',
  axes: const [_gender],
  renditions: [
    MediaRendition(when: const {'gender': 'girl'}, file: ImageNetworkMedia.url('girl')),
    MediaRendition(when: const {'gender': 'boy'}, file: ImageNetworkMedia.url('boy')),
  ],
);

void main() {
  late GlobalKVDataSource kv;
  // One image per url, so the drawn one can be told apart.
  late Map<String, MemoryImage> images;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    kv = SharedPrefsKVDataSource(await SharedPreferences.getInstance());
    images = {};
  });

  ImageProvider loads(String url) => images.putIfAbsent(url, () => MemoryImage(Uint8List.fromList(_png)));
  ImageProvider fails(String url) => MemoryImage(Uint8List.fromList([1, 2, 3]));

  Future<void> pump(WidgetTester tester, Media media, MediaImageFor imageFor) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [globalKVDataSourceProvider.overrideWithValue(kv)],
          child: MaterialApp(
            home: Scaffold(
              body: MediaView(media: media, height: 100, imageFor: imageFor, footer: const Text('credit')),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
  }

  Image drawn(WidgetTester tester) => tester.widget<Image>(find.byType(Image));

  testWidgets('a file that cannot be loaded hides the media, frame and footer', (tester) async {
    await pump(tester, _media, fails);

    expect(find.byType(Image), findsNothing);
    expect(find.text('credit'), findsNothing);
    expect(find.text('Girl'), findsNothing);
  });

  testWidgets('shows the default option until the user picks', (tester) async {
    await pump(tester, _media, loads);

    expect(drawn(tester).image, images['girl']);
    expect(find.text('credit'), findsOneWidget);
    expect(find.bySemanticsLabel('Week 12 illustration'), findsOneWidget);
  });

  testWidgets('the switch changes the shown file and remembers the choice on the device', (tester) async {
    await pump(tester, _media, loads);

    await tester.tap(find.text('Boy'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(drawn(tester).image, images['boy']);
    expect(await kv.get<String>(MediaChoices.storageKey('gender')), 'boy');
  });

  testWidgets('a remembered choice is used on the next view', (tester) async {
    await kv.put<String>(MediaChoices.storageKey('gender'), 'boy');

    await pump(tester, _media, loads);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(drawn(tester).image, images['boy']);
  });

  testWidgets('a media without a user axis shows no switch; compact shows the thumbnail', (tester) async {
    final plain = Media(
      renditions: [MediaRendition(file: ImageNetworkMedia.url('full'), thumbnail: ImageNetworkMedia.url('thumb'))],
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [globalKVDataSourceProvider.overrideWithValue(kv)],
          child: MaterialApp(
            home: Scaffold(body: MediaView(media: plain, compact: true, height: 100, imageFor: loads)),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(drawn(tester).image, images['thumb']);
    expect(find.byType(BalsmSegmented<MediaOption>), findsNothing);
  });

  testWidgets('precacheMedia fetches every user-axis option and each thumbnail', (tester) async {
    final asked = <String>[];
    final withThumb = Media(
      axes: const [_gender],
      renditions: [
        MediaRendition(
          when: const {'gender': 'girl'},
          file: ImageNetworkMedia.url('girl'),
          thumbnail: ImageNetworkMedia.url('girl-t'),
        ),
        MediaRendition(when: const {'gender': 'boy'}, file: ImageNetworkMedia.url('boy')),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => const SizedBox())));
    final context = tester.element(find.byType(SizedBox));
    await tester.runAsync(
      () => precacheMedia(
        context,
        [withThumb],
        imageFor: (url) {
          asked.add(url);
          return loads(url);
        },
      ),
    );

    expect(asked, unorderedEquals(['girl', 'girl-t', 'boy']));
  });
}
