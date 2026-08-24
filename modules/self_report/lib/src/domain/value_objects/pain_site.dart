import '../../i18n/strings.dart';
import 'body_region.dart';
import 'body_tissue.dart';

/// One marked spot on the body map: a [BodyRegion] at a [BodyTissue] depth.
/// The same region may appear twice in a check-in with different tissues.
class PainSite {
  const PainSite({required this.region, required this.tissue});

  final BodyRegion region;
  final BodyTissue tissue;

  /// `"Chest · Muscle"` using [mid] (app `list_mid`) between the two labels.
  String label(Messages messages, {required String mid}) => '${region.label(messages)}$mid${tissue.label(messages)}';

  @override
  bool operator ==(Object other) => other is PainSite && other.region == region && other.tissue == tissue;

  @override
  int get hashCode => Object.hash(region, tissue);
}
