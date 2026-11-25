import 'media.dart';

/// Picks the file to show for a [Media]. Pure: the caller supplies the
/// app's axis values and the user's remembered choices.
abstract final class MediaSelector {
  /// The axis values [media] is shown with: each app axis from [app] (an
  /// app axis [app] does not know stays unset), each user axis from
  /// [choices] or else its default.
  static Map<String, String> contextFor(
    Media media, {
    required Map<String, String> app,
    Map<String, String> choices = const {},
  }) =>
      {
        for (final axis in media.axes)
          if (axis.source == MediaAxisSource.user)
            axis.id: axis.resolve(choices[axis.id])
          else if (app[axis.id] case final value?)
            axis.id: value,
      };

  /// The rendition for [context]: those whose `when` it satisfies, the most
  /// specific of them, then the smallest at least [minWidth] pixels wide
  /// (else the widest). Null when none matches.
  static MediaRendition? rendition(Media media, Map<String, String> context, {double minWidth = 0}) {
    final matching = [
      for (final r in media.renditions)
        if (r.when.entries.every((e) => context[e.key] == e.value)) r,
    ];
    if (matching.isEmpty) return null;
    final specificity = matching.map((r) => r.when.length).reduce((a, b) => a > b ? a : b);
    final best = matching.where((r) => r.when.length == specificity).toList();
    final wideEnough = best.where((r) => r.file.width >= minWidth).toList();
    if (wideEnough.isNotEmpty) {
      return wideEnough.reduce((a, b) => b.file.width < a.file.width ? b : a);
    }
    return best.reduce((a, b) => b.file.width > a.file.width ? b : a);
  }

  /// The file to show: the [rendition]'s thumbnail when [compact] and it
  /// has one, else its full file. Null when no rendition matches.
  static MediaFile? file(Media media, Map<String, String> context, {double minWidth = 0, bool compact = false}) {
    final r = rendition(media, context, minWidth: minWidth);
    if (r == null) return null;
    return compact ? (r.thumbnail ?? r.file) : r.file;
  }

  /// Every context a user could switch [media] to: [app] values plus each
  /// combination of the user axes' options. Fetching all of them keeps the
  /// user's choice from the CDN.
  static List<Map<String, String>> everyUserContext(Media media, {required Map<String, String> app}) {
    var contexts = [contextFor(media, app: app)];
    for (final axis in media.userAxes) {
      contexts = [
        for (final c in contexts)
          for (final o in axis.options) {...c, axis.id: o.value},
      ];
    }
    return contexts;
  }
}
