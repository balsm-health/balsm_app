import '../../core.dart' show Typo;
import 'balsm_kit.dart' show Typo;
import 'tokens.dart' show Typo;
import 'typo.dart' show Typo;

/// The type scale (`app.css --pt-*` at scale 1), named for the text role each size serves, the same vocabulary as
/// the [Typo] styles built from them. Use these for any font size; never a bare number.
class FontSizes {
  FontSizes._();

  /// Micro labels that must fit a fixed slot: the beta ribbon, a one-line label under a 44pt swatch.
  static const micro = 10.0;

  /// Eyebrow labels and the smallest captions.
  static const eyebrow = 11.0;

  /// Meta lines: timestamps, hints, secondary captions.
  static const meta = 12.0;

  /// Compact body copy and form labels.
  static const bodySm = 13.0;

  /// Supporting copy under a title, form errors and checkbox labels.
  static const description = 14.0;

  /// Body copy one step up from [bodySm], where [body] is too large.
  static const bodyLg = 15.0;

  /// Default body copy.
  static const body = 16.0;

  /// Titles of dialogs, pickers and list sections, one step under [subhead].
  static const subheadSm = 17.0;

  /// Sub-headings and emphasised rows.
  static const subhead = 18.0;

  /// Section headings.
  static const heading = 21.0;

  /// The headline of a shared-kernel or module screen, and the sidebar wordmark.
  static const headline = 22.0;

  /// Screen titles.
  static const title = 26.0;

  /// Large display numerals and headlines.
  static const display = 32.0;

  /// The largest size: a single hero figure.
  static const hero = 40.0;
}
