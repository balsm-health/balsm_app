import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

MediaRendition _r(String url, {Map<String, String> when = const {}, int width = 600, String? thumb}) => MediaRendition(
      when: when,
      file: MediaFile(url: url, width: width),
      thumbnail: thumb == null ? null : MediaFile(url: thumb, width: 160),
    );

const _theme = MediaAxis(id: 'theme', source: MediaAxisSource.app);
const _gender = MediaAxis(
  id: 'gender',
  source: MediaAxisSource.user,
  label: 'Baby',
  options: [MediaOption(value: 'girl', label: 'Girl'), MediaOption(value: 'boy', label: 'Boy')],
  defaultValue: 'girl',
);

String? _pick(Media m, {Map<String, String> app = const {}, Map<String, String> choices = const {}, double w = 0}) =>
    MediaSelector.file(m, MediaSelector.contextFor(m, app: app, choices: choices), minWidth: w)?.url;

void main() {
  group('MediaSelector', () {
    test('prefers the most specific matching rendition', () {
      final m = Media(
        axes: const [_theme, _gender],
        renditions: [
          _r('any'),
          _r('light', when: {'theme': 'light'}),
          _r('light-boy', when: {'theme': 'light', 'gender': 'boy'}),
        ],
      );

      expect(_pick(m, app: {'theme': 'light'}, choices: {'gender': 'boy'}), 'light-boy');
      expect(_pick(m, app: {'theme': 'light'}), 'light');
      expect(_pick(m, app: {'theme': 'dark'}), 'any');
    });

    test('an axis absent from when matches any value; an unknown app axis is unset', () {
      final m = Media(
        axes: const [_theme],
        renditions: [
          _r('dark', when: {'theme': 'dark'}),
          _r('fallback'),
        ],
      );

      expect(_pick(m, app: {'theme': 'dark'}), 'dark');
      expect(_pick(m), 'fallback');
      expect(MediaSelector.contextFor(m, app: const {}), isEmpty);
    });

    test('no match gives null', () {
      final m = Media(
        axes: const [
          _theme,
        ],
        renditions: [
          _r('dark', when: {'theme': 'dark'}),
        ],
      );

      expect(_pick(m, app: {'theme': 'light'}), isNull);
    });

    test('picks the smallest width covering the slot, else the widest', () {
      final m = Media(renditions: [_r('s', width: 400), _r('l', width: 1600), _r('m', width: 800)]);

      expect(_pick(m, w: 300), 's');
      expect(_pick(m, w: 401), 'm');
      expect(_pick(m, w: 800), 'm');
      expect(_pick(m, w: 3000), 'l');
    });

    test('a user axis uses its default until the user picks, and ignores an unknown pick', () {
      final m = Media(
        axes: const [_gender],
        renditions: [
          _r('girl', when: {'gender': 'girl'}),
          _r('boy', when: {'gender': 'boy'}),
        ],
      );

      expect(_pick(m), 'girl');
      expect(_pick(m, choices: {'gender': 'boy'}), 'boy');
      expect(_pick(m, choices: {'gender': 'cat'}), 'girl');
    });

    test('compact shows the thumbnail when there is one', () {
      final m = Media(renditions: [_r('full', thumb: 'thumb')]);
      final none = Media(renditions: [_r('full')]);

      expect(MediaSelector.file(m, const {}, compact: true)?.url, 'thumb');
      expect(MediaSelector.file(none, const {}, compact: true)?.url, 'full');
    });

    test('everyUserContext spans every user option, app axes at their current value', () {
      final m = Media(axes: const [_theme, _gender], renditions: [_r('x')]);

      final all = MediaSelector.everyUserContext(m, app: {'theme': 'light'});

      expect([for (final c in all) '${c['theme']}-${c['gender']}'], ['light-girl', 'light-boy']);
    });
  });

  group('Media.fromDto', () {
    test('maps axes and renditions; drops a media with no rendition', () {
      const dto = MediaDto(
        alt: 'Week 12',
        credit: 'art',
        sourceUrl: 'https://example.test/src',
        axes: [
          MediaAxisDto(id: 'theme', source: 'app'),
          MediaAxisDto(id: 'odd', source: 'elsewhere'),
          MediaAxisDto(
            id: 'gender',
            source: 'user',
            label: 'Baby',
            options: [MediaOptionDto(value: 'girl', label: 'Girl')],
            defaultValue: 'girl',
          ),
        ],
        renditions: [
          MediaRenditionDto(
            when: {'theme': 'light'},
            file: MediaFileDto(url: 'https://cdn.example.test/a.jpg', width: 679),
            thumbnail: MediaFileDto(url: 'https://cdn.example.test/a-t.jpg'),
          ),
        ],
      );

      final m = Media.fromDto(dto)!;

      expect((m.alt, m.credit, m.sourceUrl), ('Week 12', 'art', 'https://example.test/src'));
      expect([for (final a in m.axes) a.id], ['theme', 'gender']);
      expect(m.userAxes.single.options.single.label, 'Girl');
      expect(m.renditions.single.file.width, 679);
      expect(m.renditions.single.thumbnail?.url, 'https://cdn.example.test/a-t.jpg');
      expect(Media.fromDto(const MediaDto()), isNull);
      expect(Media.fromDto(null), isNull);
    });
  });
}
