import 'package:balsm_api/balsm_api.dart' show MediaAxisDto, MediaDto, MediaFileDto, MediaRenditionDto;
import 'package:media_source/media_source.dart';

/// Who fills an axis value: the app from its own state, or the user with a
/// switch on the media.
enum MediaAxisSource { app, user }

/// A picture the API points at, in [renditions] that vary along [axes].
/// Public content, never patient data. Pick a file with `MediaSelector`.
class Media {
  const Media({required this.renditions, this.alt = '', this.credit = '', this.sourceUrl = '', this.axes = const []});

  /// Null when [dto] has no rendition to show.
  static Media? fromDto(MediaDto? dto) {
    if (dto == null) return null;
    final renditions = [
      for (final r in dto.renditions)
        if (MediaRendition._fromDto(r) case final rendition?) rendition,
    ];
    if (renditions.isEmpty) return null;
    return Media(
      alt: dto.alt,
      credit: dto.credit,
      sourceUrl: dto.sourceUrl,
      axes: [
        for (final a in dto.axes)
          if (MediaAxis._fromDto(a) case final axis?) axis,
      ],
      renditions: renditions,
    );
  }

  /// Spoken description; empty when the content names none.
  final String alt;

  /// Key of the content's credits table; empty when none.
  final String credit;

  /// Where the artwork was published; empty when unknown.
  final String sourceUrl;
  final List<MediaAxis> axes;
  final List<MediaRendition> renditions;

  /// The axes shown as a switch on the media.
  Iterable<MediaAxis> get userAxes => axes.where((a) => a.source == MediaAxisSource.user);
}

/// A dimension the renditions vary along. A user axis has [label],
/// [options] and a [defaultValue]; an app axis has only its [id]
/// (`theme`, `locale`, `platform`).
class MediaAxis {
  const MediaAxis({
    required this.id,
    required this.source,
    this.label = '',
    this.options = const [],
    this.defaultValue = '',
  });

  /// Null for an unknown source, or a user axis with nothing to pick.
  static MediaAxis? _fromDto(MediaAxisDto dto) {
    final source = switch (dto.source) {
      'app' => MediaAxisSource.app,
      'user' => MediaAxisSource.user,
      _ => null,
    };
    if (source == null) return null;
    final options = [for (final o in dto.options) MediaOption(value: o.value, label: o.label)];
    if (source == MediaAxisSource.user && options.isEmpty) return null;
    return MediaAxis(id: dto.id, source: source, label: dto.label, options: options, defaultValue: dto.defaultValue);
  }

  final String id;
  final MediaAxisSource source;
  final String label;
  final List<MediaOption> options;
  final String defaultValue;

  /// [value] when it is one of [options], else [defaultValue] (else the first option).
  String resolve(String? value) {
    bool known(String? v) => v != null && options.any((o) => o.value == v);
    if (known(value)) return value!; // known() checked it is non-null.
    if (known(defaultValue) || options.isEmpty) return defaultValue;
    return options.first.value;
  }
}

/// One value of a user axis and the label the switch shows for it.
class MediaOption {
  const MediaOption({required this.value, required this.label});
  final String value;
  final String label;
}

/// A [file] served when every axis in [when] has that value; an axis absent
/// from [when] matches anything. [width] and [height] are [file]'s pixels,
/// 0 when unknown (media_source carries no dimensions).
class MediaRendition {
  const MediaRendition({required this.file, this.when = const {}, this.thumbnail, this.width = 0, this.height = 0});

  /// Null when [dto]'s file url cannot be parsed. A thumbnail whose url
  /// cannot be parsed is dropped.
  static MediaRendition? _fromDto(MediaRenditionDto dto) {
    final file = _network(dto.file);
    if (file == null) return null;
    return MediaRendition(
      when: dto.when,
      file: file,
      thumbnail: switch (dto.thumbnail) {
        final t? => _network(t),
        null => null,
      },
      width: dto.file.width,
      height: dto.file.height,
    );
  }

  /// The CDN file as the media_source subtype for its mime type
  /// ([ImageNetworkMedia] for an image), with its size and name.
  static NetworkMediaSource? _network(MediaFileDto dto) => NetworkMediaSource.fromUrlOrNull(
        dto.url,
        mimeType: dto.mime.isEmpty ? null : dto.mime,
        size: dto.bytes > 0 ? FileSize.b(dto.bytes) : null,
      );

  final Map<String, String> when;
  final NetworkMediaSource file;

  /// A smaller file for lists and cards; null when there is none.
  final NetworkMediaSource? thumbnail;
  final int width;
  final int height;

  /// [file] paired with its [thumbnail]; just [file] when there is none.
  MediaSource get source => switch (thumbnail) {
        final t? => ThumbnailMediaSource(original: file, thumbnail: t),
        null => file,
      };
}
