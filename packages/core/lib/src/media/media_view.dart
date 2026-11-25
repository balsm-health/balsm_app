import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../kit/widgets/balsm_segmented.dart';
import 'media.dart';
import 'media_app_axes.dart';
import 'media_choices.dart';
import 'media_selector.dart';

/// Turns a file url into the image to draw; [NetworkImage] unless a test
/// supplies another.
typedef MediaImageFor = ImageProvider Function(String url);

ImageProvider _network(String url) => NetworkImage(url);

/// Shows the rendition of [media] that fits this app, slot and the user's
/// remembered choices. Draws nothing until the file has loaded, and nothing
/// at all if it cannot be fetched — never an empty frame. [compact] (lists,
/// cards) shows the rendition's thumbnail when it has one. A media with a
/// user axis gets a switch under the picture that changes the remembered
/// choice for every media sharing that axis.
class MediaView extends ConsumerStatefulWidget {
  const MediaView({
    required this.media,
    super.key,
    this.compact = false,
    this.height,
    this.decoration,
    this.semanticLabel,
    this.footer,
    this.imageFor = _network,
  });

  final Media media;
  final bool compact;

  /// The picture's height; null lets the image size itself.
  final double? height;

  /// The frame behind the picture (border, background).
  final BoxDecoration? decoration;

  /// Spoken description; [Media.alt] when null.
  final String? semanticLabel;

  /// Shown under the picture once it has loaded (e.g. the credit).
  final Widget? footer;
  final MediaImageFor imageFor;

  @override
  ConsumerState<MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends ConsumerState<MediaView> {
  @override
  void initState() {
    super.initState();
    final ids = [for (final a in widget.media.userAxes) a.id];
    if (ids.isNotEmpty) unawaited(ref.read(mediaChoicesProvider.notifier).load(ids));
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final choices = media.userAxes.isEmpty ? const <String, String>{} : ref.watch(mediaChoicesProvider);
    final values = MediaSelector.contextFor(media, app: mediaAppAxes(context), choices: choices);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final file = MediaSelector.file(media, values, minWidth: width * ratio, compact: widget.compact);
        if (file == null) return const SizedBox.shrink();
        final image = widget.imageFor(file.url);
        return _ShownWhenLoaded(
          image: image,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                image: true,
                label: widget.semanticLabel ?? (media.alt.isEmpty ? null : media.alt),
                child: Container(
                  height: widget.height,
                  clipBehavior: widget.decoration == null ? Clip.none : Clip.antiAlias,
                  decoration: widget.decoration,
                  child: Image(image: image, fit: BoxFit.contain, excludeFromSemantics: true),
                ),
              ),
              for (final axis in media.userAxes)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 8),
                  child: _AxisSwitch(axis: axis, selected: values[axis.id]),
                ),
              if (widget.footer case final footer?) footer,
            ],
          ),
        );
      },
    );
  }
}

/// The options of a user axis as a segmented control; picking one
/// remembers it on this device.
class _AxisSwitch extends ConsumerWidget {
  const _AxisSwitch({required this.axis, required this.selected});
  final MediaAxis axis;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = axis.options.firstWhere((o) => o.value == selected, orElse: () => axis.options.first);
    return Semantics(
      container: true,
      label: axis.label.isEmpty ? null : axis.label,
      child: BalsmSegmented<MediaOption>(
        options: axis.options,
        labelOf: (o) => o.label.isEmpty ? o.value : o.label,
        selected: current,
        onChanged: (o) => unawaited(ref.read(mediaChoicesProvider.notifier).choose(axis.id, o.value)),
      ),
    );
  }
}

/// [child] once [image] has loaded; nothing before, nothing on error.
class _ShownWhenLoaded extends StatefulWidget {
  const _ShownWhenLoaded({required this.image, required this.child});
  final ImageProvider image;
  final Widget child;

  @override
  State<_ShownWhenLoaded> createState() => _ShownWhenLoadedState();
}

class _ShownWhenLoadedState extends State<_ShownWhenLoaded> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(
    (_, __) {
      if (mounted && !_loaded) setState(() => _loaded = true);
    },
    onError: (_, __) {},
  );

  // View-local: whether this image has arrived.
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_ShownWhenLoaded old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      _loaded = false;
      _resolve();
    }
  }

  void _resolve() {
    _stream?.removeListener(_listener);
    _stream = widget.image.resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _loaded ? widget.child : const SizedBox.shrink();
}

/// Fetches, for each of [media], the file shown now and the file for every
/// option of its user axes (app axes: only the current value), with their
/// thumbnails. Asking for all of them keeps a user's choice — and for
/// week-by-week content, which item they are on — from the CDN. [slotWidth]
/// is the logical width the media will be shown at (default: the screen's).
Future<void> precacheMedia(
  BuildContext context,
  Iterable<Media> media, {
  double? slotWidth,
  MediaImageFor imageFor = _network,
}) {
  final app = mediaAppAxes(context);
  final minWidth = (slotWidth ?? MediaQuery.sizeOf(context).width) * MediaQuery.devicePixelRatioOf(context);
  final urls = <String>{
    for (final m in media)
      for (final values in MediaSelector.everyUserContext(m, app: app))
        if (MediaSelector.rendition(m, values, minWidth: minWidth) case final r?) ...[
          r.file.url,
          if (r.thumbnail case final t?) t.url,
        ],
  };
  return Future.wait([
    for (final url in urls) precacheImage(imageFor(url), context, onError: (_, __) {}),
  ]);
}
