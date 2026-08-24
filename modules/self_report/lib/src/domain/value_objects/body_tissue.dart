import '../../i18n/strings.dart';
import 'body_region.dart';

/// Tissue / depth layer on the body map. Same [BodyRegion] can be marked on
/// more than one layer in a single check-in (chest × muscle and chest × joint).
enum BodyTissue {
  skin,
  muscle,
  bone,
  joint,
  tendon,
  nerve,
  organ;

  /// Stable persistence id — [name] (skin, muscle, …).
  String get id => name;

  static final Map<String, BodyTissue> _byId = {
    for (final t in values) t.id: t,
  };

  /// Resolve a stored tissue id, or null if unknown / retired.
  static BodyTissue? fromId(String id) => _byId[id];

  /// Regions selectable on this layer for [view].
  List<BodyRegion> regions(BodyView view) {
    final surface = view == BodyView.front ? BodyRegion.front : BodyRegion.back;
    final viscera = view == BodyView.front ? BodyRegion.organFront : BodyRegion.organBack;
    return [
      ...surface.where(allows),
      if (this == organ) ...viscera,
    ];
  }

  /// Whether [region] is a hotspot on this layer (viscera gated by [organ]).
  bool allows(BodyRegion region) {
    if (region.isOrgan) return this == organ;
    return switch (this) {
      skin || muscle || nerve => true,
      bone => region != BodyRegion.sinuses &&
          region != BodyRegion.l_eye &&
          region != BodyRegion.r_eye &&
          region != BodyRegion.abdomen,
      joint => _joints.contains(region),
      tendon => _tendons.contains(region),
      organ => region.isHeadExtra,
    };
  }

  /// Label in [messages]' locale (module i69n `tissue.*`).
  String label(Messages messages) {
    final t = messages.tissue;
    return switch (this) {
      skin => t.skin,
      muscle => t.muscle,
      bone => t.bone,
      joint => t.joint,
      tendon => t.tendon,
      nerve => t.nerve,
      organ => t.organ,
    };
  }

  /// Label for a language code (`en` / `ar`).
  String labelForLang(String lang) => label(selfReportMessagesOf(lang));
}

const _joints = <BodyRegion>{
  BodyRegion.jaw,
  BodyRegion.neck,
  BodyRegion.l_shoulder,
  BodyRegion.r_shoulder,
  BodyRegion.l_elbow,
  BodyRegion.r_elbow,
  BodyRegion.l_hand,
  BodyRegion.r_hand,
  BodyRegion.pelvis,
  BodyRegion.l_knee,
  BodyRegion.r_knee,
  BodyRegion.l_foot,
  BodyRegion.r_foot,
  BodyRegion.bk_neck,
  BodyRegion.bk_l_shoulder,
  BodyRegion.bk_r_shoulder,
  BodyRegion.bk_upper,
  BodyRegion.bk_mid,
  BodyRegion.bk_lower,
  BodyRegion.bk_l_glute,
  BodyRegion.bk_r_glute,
};

const _tendons = <BodyRegion>{
  BodyRegion.l_shoulder,
  BodyRegion.r_shoulder,
  BodyRegion.l_elbow,
  BodyRegion.r_elbow,
  BodyRegion.l_hand,
  BodyRegion.r_hand,
  BodyRegion.pelvis,
  BodyRegion.l_knee,
  BodyRegion.r_knee,
  BodyRegion.bk_l_shoulder,
  BodyRegion.bk_r_shoulder,
  BodyRegion.bk_l_heel,
  BodyRegion.bk_r_heel,
};
