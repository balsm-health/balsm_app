import '../../i18n/strings.dart';
import 'body_region.dart';
import 'body_tissue.dart';

/// One marked spot on the body map. The layer rides on [region]'s subclass
/// ([Muscle.chest] is a [Muscle]), so a site cannot claim a tissue its region
/// is not on. The same location may appear twice in a check-in on two layers.
class PainSite {
  const PainSite(this.region);

  final BodyRegion region;

  /// Layer this spot was marked on — [BodyRegion.tissue] of [region].
  BodyTissue get tissue => region.tissue;

  /// `"Chest · Muscle"` using [mid] (app `list_mid`) between the two labels.
  String label(Messages messages, {required String mid}) => '${region.label(messages)}$mid${tissue.label(messages)}';

  @override
  bool operator ==(Object other) => other is PainSite && other.region == region;

  @override
  int get hashCode => region.hashCode;
}
