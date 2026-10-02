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

/// The tissue a [PainSite] selection is locked to — the first marked site's
/// tissue — or null while [sites] is empty and any layer may still be
/// chosen.
///
/// A check-in holds regions of one tissue only (approved behaviour rule):
/// once locked, every site in [sites] is expected to share it, but a legacy
/// record that already mixed tissues still resolves predictably — it defers
/// to the first site rather than throwing.
BodyTissue? lockedBodyTissue(Set<PainSite> sites) => sites.isEmpty ? null : sites.first.tissue;

/// Whether [site] may be toggled into/out of [sites] under the one-tissue
/// rule. Removing an already-marked site is always allowed; marking a new
/// one is allowed only while [sites] is empty or [site] shares
/// [lockedBodyTissue]. Shared by the body map's tap/add path and the
/// check-in screens that own the `Set<PainSite>` being built, so the rule
/// lives in exactly one place.
bool canToggleSite(Set<PainSite> sites, PainSite site) {
  if (sites.contains(site)) return true;
  final tissue = lockedBodyTissue(sites);
  return tissue == null || site.tissue == tissue;
}
