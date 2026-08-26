// ignore_for_file: constant_identifier_names

import 'package:core/core.dart';

import '../../i18n/strings.dart';
import 'body_tissue.dart';

/// Which anatomical view a [BodyRegion] belongs to.
enum BodyView { front, back }

/// A selectable hotspot on the body figure. Closed catalog — adding a region
/// is a product decision, not free-form input.
///
/// One subclass per tissue layer ([Muscle], [Bone], [Organ], …), so the layer a
/// spot was marked on is carried by its runtime type. Identity is the persist
/// id **and** the tissue: `Muscle.chest != Bone.chest`, which is what lets a
/// single check-in hold chest pain on two layers at once.
///
/// Const access: [Muscle.chest], [Organ.liver], [Joint.l_knee].
sealed class BodyRegion extends BaseEnum<String, BodyRegion> {
  const BodyRegion(this.view, this.cx, this.cy, super.value);

  final BodyView view;
  final double cx;
  final double cy;

  /// Layer this instance sits on. Fixed per subclass.
  BodyTissue get tissue;

  /// Stable persistence / i69n key (hyphenated stored form).
  String get id => value;

  /// Named viscus. Only ever a hotspot on the organ layer.
  bool get isOrgan => _viscera.contains(value);

  /// Eye, ear, sinus, jaw — smaller than the generic head hotspot. These sit
  /// on the surface layers *and* the organ layer, so they are not [isOrgan].
  bool get isHeadExtra => _headExtras.contains(value);

  static const _viscera = <String>{
    'heart',
    'l-lung',
    'r-lung',
    'stomach',
    'liver',
    'intestines',
    'bladder',
    'l-kidney',
    'r-kidney',
  };

  static const _headExtras = <String>{
    'sinuses',
    'l-eye',
    'r-eye',
    'l-ear',
    'r-ear',
    'jaw',
    'bk-l-ear',
    'bk-r-ear',
  };

  /// Label in [messages]' locale (module i69n `body.*`).
  String label(Messages messages) => messages.body[id.replaceAll('-', '_')] as String;

  /// Label for a language code (`en` / `ar`).
  String labelForLang(String lang) => label(selfReportMessagesOf(lang));

  /// Same location on a different layer, or null if not a hotspot there.
  BodyRegion? on(BodyTissue other) => fromId(value, other);

  /// Persist id **and** tissue — `Muscle.chest` and `Bone.chest` are
  /// different sites, and a check-in may hold both.
  @override
  List<Object?> get props => [value, tissue];

  /// Every hotspot on every layer.
  static const all = <BodyRegion>[
    ...Skin.values,
    ...Muscle.values,
    ...Bone.values,
    ...Joint.values,
    ...Tendon.values,
    ...Nerve.values,
    ...Organ.values,
  ];

  static final Map<(String, BodyTissue), BodyRegion> _byKey = {
    for (final r in all) (r.value, r.tissue): r,
  };

  /// Resolve a stored `(region_id, tissue_id)` pair, or null if the location
  /// is not a hotspot on that layer (unknown / retired / wrong layer).
  static BodyRegion? fromId(String id, BodyTissue tissue) => _byKey[(id, tissue)];
}

/// Skin-layer hotspots — every surface location.
///
/// Every member is a hotspot on the skin layer; [tissue] is fixed.
final class Skin extends BodyRegion {
  const Skin._(super.view, super.cx, super.cy, super.value);

  @override
  BodyTissue get tissue => BodyTissue.skin;

  static const sinuses = Skin._(BodyView.front, 100, 22, 'sinuses');
  static const l_eye = Skin._(BodyView.front, 89, 28, 'l-eye');
  static const r_eye = Skin._(BodyView.front, 111, 28, 'r-eye');
  static const l_ear = Skin._(BodyView.front, 79, 32, 'l-ear');
  static const r_ear = Skin._(BodyView.front, 121, 32, 'r-ear');
  static const jaw = Skin._(BodyView.front, 100, 44, 'jaw');
  static const bk_l_ear = Skin._(BodyView.back, 79, 32, 'bk-l-ear');
  static const bk_r_ear = Skin._(BodyView.back, 121, 32, 'bk-r-ear');
  static const head = Skin._(BodyView.front, 100, 32, 'head');
  static const neck = Skin._(BodyView.front, 100, 62, 'neck');
  static const l_shoulder = Skin._(BodyView.front, 52, 89, 'l-shoulder');
  static const r_shoulder = Skin._(BodyView.front, 148, 89, 'r-shoulder');
  static const chest = Skin._(BodyView.front, 100, 106, 'chest');
  static const l_upper_arm = Skin._(BodyView.front, 58, 120, 'l-upper-arm');
  static const r_upper_arm = Skin._(BodyView.front, 142, 120, 'r-upper-arm');
  static const abdomen = Skin._(BodyView.front, 100, 150, 'abdomen');
  static const l_elbow = Skin._(BodyView.front, 56, 168, 'l-elbow');
  static const r_elbow = Skin._(BodyView.front, 144, 168, 'r-elbow');
  static const l_forearm = Skin._(BodyView.front, 56, 196, 'l-forearm');
  static const r_forearm = Skin._(BodyView.front, 144, 196, 'r-forearm');
  static const pelvis = Skin._(BodyView.front, 100, 197, 'pelvis');
  static const l_hand = Skin._(BodyView.front, 58, 212, 'l-hand');
  static const r_hand = Skin._(BodyView.front, 142, 212, 'r-hand');
  static const l_thigh = Skin._(BodyView.front, 80, 256, 'l-thigh');
  static const r_thigh = Skin._(BodyView.front, 120, 256, 'r-thigh');
  static const l_knee = Skin._(BodyView.front, 80, 298, 'l-knee');
  static const r_knee = Skin._(BodyView.front, 120, 298, 'r-knee');
  static const l_shin = Skin._(BodyView.front, 80, 330, 'l-shin');
  static const r_shin = Skin._(BodyView.front, 120, 330, 'r-shin');
  static const l_foot = Skin._(BodyView.front, 80, 372, 'l-foot');
  static const r_foot = Skin._(BodyView.front, 120, 372, 'r-foot');
  static const bk_head = Skin._(BodyView.back, 100, 32, 'bk-head');
  static const bk_neck = Skin._(BodyView.back, 100, 62, 'bk-neck');
  static const bk_l_shoulder = Skin._(BodyView.back, 52, 89, 'bk-l-shoulder');
  static const bk_r_shoulder = Skin._(BodyView.back, 148, 89, 'bk-r-shoulder');
  static const bk_upper = Skin._(BodyView.back, 100, 110, 'bk-upper');
  static const bk_mid = Skin._(BodyView.back, 100, 140, 'bk-mid');
  static const bk_lower = Skin._(BodyView.back, 100, 166, 'bk-lower');
  static const bk_l_glute = Skin._(BodyView.back, 82, 206, 'bk-l-glute');
  static const bk_r_glute = Skin._(BodyView.back, 118, 206, 'bk-r-glute');
  static const bk_l_hamstr = Skin._(BodyView.back, 80, 256, 'bk-l-hamstr');
  static const bk_r_hamstr = Skin._(BodyView.back, 120, 256, 'bk-r-hamstr');
  static const bk_l_calf = Skin._(BodyView.back, 80, 330, 'bk-l-calf');
  static const bk_r_calf = Skin._(BodyView.back, 120, 330, 'bk-r-calf');
  static const bk_l_heel = Skin._(BodyView.back, 80, 358, 'bk-l-heel');
  static const bk_r_heel = Skin._(BodyView.back, 120, 358, 'bk-r-heel');

  static const values = <Skin>[
    sinuses,
    l_eye,
    r_eye,
    l_ear,
    r_ear,
    jaw,
    bk_l_ear,
    bk_r_ear,
    head,
    neck,
    l_shoulder,
    r_shoulder,
    chest,
    l_upper_arm,
    r_upper_arm,
    abdomen,
    l_elbow,
    r_elbow,
    l_forearm,
    r_forearm,
    pelvis,
    l_hand,
    r_hand,
    l_thigh,
    r_thigh,
    l_knee,
    r_knee,
    l_shin,
    r_shin,
    l_foot,
    r_foot,
    bk_head,
    bk_neck,
    bk_l_shoulder,
    bk_r_shoulder,
    bk_upper,
    bk_mid,
    bk_lower,
    bk_l_glute,
    bk_r_glute,
    bk_l_hamstr,
    bk_r_hamstr,
    bk_l_calf,
    bk_r_calf,
    bk_l_heel,
    bk_r_heel,
  ];
}

/// Muscle-layer hotspots — every surface location.
///
/// Every member is a hotspot on the muscle layer; [tissue] is fixed.
final class Muscle extends BodyRegion {
  const Muscle._(super.view, super.cx, super.cy, super.value);

  @override
  BodyTissue get tissue => BodyTissue.muscle;

  static const sinuses = Muscle._(BodyView.front, 100, 22, 'sinuses');
  static const l_eye = Muscle._(BodyView.front, 89, 28, 'l-eye');
  static const r_eye = Muscle._(BodyView.front, 111, 28, 'r-eye');
  static const l_ear = Muscle._(BodyView.front, 79, 32, 'l-ear');
  static const r_ear = Muscle._(BodyView.front, 121, 32, 'r-ear');
  static const jaw = Muscle._(BodyView.front, 100, 44, 'jaw');
  static const bk_l_ear = Muscle._(BodyView.back, 79, 32, 'bk-l-ear');
  static const bk_r_ear = Muscle._(BodyView.back, 121, 32, 'bk-r-ear');
  static const head = Muscle._(BodyView.front, 100, 32, 'head');
  static const neck = Muscle._(BodyView.front, 100, 62, 'neck');
  static const l_shoulder = Muscle._(BodyView.front, 52, 89, 'l-shoulder');
  static const r_shoulder = Muscle._(BodyView.front, 148, 89, 'r-shoulder');
  static const chest = Muscle._(BodyView.front, 100, 106, 'chest');
  static const l_upper_arm = Muscle._(BodyView.front, 58, 120, 'l-upper-arm');
  static const r_upper_arm = Muscle._(BodyView.front, 142, 120, 'r-upper-arm');
  static const abdomen = Muscle._(BodyView.front, 100, 150, 'abdomen');
  static const l_elbow = Muscle._(BodyView.front, 56, 168, 'l-elbow');
  static const r_elbow = Muscle._(BodyView.front, 144, 168, 'r-elbow');
  static const l_forearm = Muscle._(BodyView.front, 56, 196, 'l-forearm');
  static const r_forearm = Muscle._(BodyView.front, 144, 196, 'r-forearm');
  static const pelvis = Muscle._(BodyView.front, 100, 197, 'pelvis');
  static const l_hand = Muscle._(BodyView.front, 58, 212, 'l-hand');
  static const r_hand = Muscle._(BodyView.front, 142, 212, 'r-hand');
  static const l_thigh = Muscle._(BodyView.front, 80, 256, 'l-thigh');
  static const r_thigh = Muscle._(BodyView.front, 120, 256, 'r-thigh');
  static const l_knee = Muscle._(BodyView.front, 80, 298, 'l-knee');
  static const r_knee = Muscle._(BodyView.front, 120, 298, 'r-knee');
  static const l_shin = Muscle._(BodyView.front, 80, 330, 'l-shin');
  static const r_shin = Muscle._(BodyView.front, 120, 330, 'r-shin');
  static const l_foot = Muscle._(BodyView.front, 80, 372, 'l-foot');
  static const r_foot = Muscle._(BodyView.front, 120, 372, 'r-foot');
  static const bk_head = Muscle._(BodyView.back, 100, 32, 'bk-head');
  static const bk_neck = Muscle._(BodyView.back, 100, 62, 'bk-neck');
  static const bk_l_shoulder = Muscle._(BodyView.back, 52, 89, 'bk-l-shoulder');
  static const bk_r_shoulder = Muscle._(BodyView.back, 148, 89, 'bk-r-shoulder');
  static const bk_upper = Muscle._(BodyView.back, 100, 110, 'bk-upper');
  static const bk_mid = Muscle._(BodyView.back, 100, 140, 'bk-mid');
  static const bk_lower = Muscle._(BodyView.back, 100, 166, 'bk-lower');
  static const bk_l_glute = Muscle._(BodyView.back, 82, 206, 'bk-l-glute');
  static const bk_r_glute = Muscle._(BodyView.back, 118, 206, 'bk-r-glute');
  static const bk_l_hamstr = Muscle._(BodyView.back, 80, 256, 'bk-l-hamstr');
  static const bk_r_hamstr = Muscle._(BodyView.back, 120, 256, 'bk-r-hamstr');
  static const bk_l_calf = Muscle._(BodyView.back, 80, 330, 'bk-l-calf');
  static const bk_r_calf = Muscle._(BodyView.back, 120, 330, 'bk-r-calf');
  static const bk_l_heel = Muscle._(BodyView.back, 80, 358, 'bk-l-heel');
  static const bk_r_heel = Muscle._(BodyView.back, 120, 358, 'bk-r-heel');

  static const values = <Muscle>[
    sinuses,
    l_eye,
    r_eye,
    l_ear,
    r_ear,
    jaw,
    bk_l_ear,
    bk_r_ear,
    head,
    neck,
    l_shoulder,
    r_shoulder,
    chest,
    l_upper_arm,
    r_upper_arm,
    abdomen,
    l_elbow,
    r_elbow,
    l_forearm,
    r_forearm,
    pelvis,
    l_hand,
    r_hand,
    l_thigh,
    r_thigh,
    l_knee,
    r_knee,
    l_shin,
    r_shin,
    l_foot,
    r_foot,
    bk_head,
    bk_neck,
    bk_l_shoulder,
    bk_r_shoulder,
    bk_upper,
    bk_mid,
    bk_lower,
    bk_l_glute,
    bk_r_glute,
    bk_l_hamstr,
    bk_r_hamstr,
    bk_l_calf,
    bk_r_calf,
    bk_l_heel,
    bk_r_heel,
  ];
}

/// Bone-layer hotspots — no sinuses, eyes, or abdomen.
///
/// Every member is a hotspot on the bone layer; [tissue] is fixed.
final class Bone extends BodyRegion {
  const Bone._(super.view, super.cx, super.cy, super.value);

  @override
  BodyTissue get tissue => BodyTissue.bone;

  static const l_ear = Bone._(BodyView.front, 79, 32, 'l-ear');
  static const r_ear = Bone._(BodyView.front, 121, 32, 'r-ear');
  static const jaw = Bone._(BodyView.front, 100, 44, 'jaw');
  static const bk_l_ear = Bone._(BodyView.back, 79, 32, 'bk-l-ear');
  static const bk_r_ear = Bone._(BodyView.back, 121, 32, 'bk-r-ear');
  static const head = Bone._(BodyView.front, 100, 32, 'head');
  static const neck = Bone._(BodyView.front, 100, 62, 'neck');
  static const l_shoulder = Bone._(BodyView.front, 52, 89, 'l-shoulder');
  static const r_shoulder = Bone._(BodyView.front, 148, 89, 'r-shoulder');
  static const chest = Bone._(BodyView.front, 100, 106, 'chest');
  static const l_upper_arm = Bone._(BodyView.front, 58, 120, 'l-upper-arm');
  static const r_upper_arm = Bone._(BodyView.front, 142, 120, 'r-upper-arm');
  static const l_elbow = Bone._(BodyView.front, 56, 168, 'l-elbow');
  static const r_elbow = Bone._(BodyView.front, 144, 168, 'r-elbow');
  static const l_forearm = Bone._(BodyView.front, 56, 196, 'l-forearm');
  static const r_forearm = Bone._(BodyView.front, 144, 196, 'r-forearm');
  static const pelvis = Bone._(BodyView.front, 100, 197, 'pelvis');
  static const l_hand = Bone._(BodyView.front, 58, 212, 'l-hand');
  static const r_hand = Bone._(BodyView.front, 142, 212, 'r-hand');
  static const l_thigh = Bone._(BodyView.front, 80, 256, 'l-thigh');
  static const r_thigh = Bone._(BodyView.front, 120, 256, 'r-thigh');
  static const l_knee = Bone._(BodyView.front, 80, 298, 'l-knee');
  static const r_knee = Bone._(BodyView.front, 120, 298, 'r-knee');
  static const l_shin = Bone._(BodyView.front, 80, 330, 'l-shin');
  static const r_shin = Bone._(BodyView.front, 120, 330, 'r-shin');
  static const l_foot = Bone._(BodyView.front, 80, 372, 'l-foot');
  static const r_foot = Bone._(BodyView.front, 120, 372, 'r-foot');
  static const bk_head = Bone._(BodyView.back, 100, 32, 'bk-head');
  static const bk_neck = Bone._(BodyView.back, 100, 62, 'bk-neck');
  static const bk_l_shoulder = Bone._(BodyView.back, 52, 89, 'bk-l-shoulder');
  static const bk_r_shoulder = Bone._(BodyView.back, 148, 89, 'bk-r-shoulder');
  static const bk_upper = Bone._(BodyView.back, 100, 110, 'bk-upper');
  static const bk_mid = Bone._(BodyView.back, 100, 140, 'bk-mid');
  static const bk_lower = Bone._(BodyView.back, 100, 166, 'bk-lower');
  static const bk_l_glute = Bone._(BodyView.back, 82, 206, 'bk-l-glute');
  static const bk_r_glute = Bone._(BodyView.back, 118, 206, 'bk-r-glute');
  static const bk_l_hamstr = Bone._(BodyView.back, 80, 256, 'bk-l-hamstr');
  static const bk_r_hamstr = Bone._(BodyView.back, 120, 256, 'bk-r-hamstr');
  static const bk_l_calf = Bone._(BodyView.back, 80, 330, 'bk-l-calf');
  static const bk_r_calf = Bone._(BodyView.back, 120, 330, 'bk-r-calf');
  static const bk_l_heel = Bone._(BodyView.back, 80, 358, 'bk-l-heel');
  static const bk_r_heel = Bone._(BodyView.back, 120, 358, 'bk-r-heel');

  static const values = <Bone>[
    l_ear,
    r_ear,
    jaw,
    bk_l_ear,
    bk_r_ear,
    head,
    neck,
    l_shoulder,
    r_shoulder,
    chest,
    l_upper_arm,
    r_upper_arm,
    l_elbow,
    r_elbow,
    l_forearm,
    r_forearm,
    pelvis,
    l_hand,
    r_hand,
    l_thigh,
    r_thigh,
    l_knee,
    r_knee,
    l_shin,
    r_shin,
    l_foot,
    r_foot,
    bk_head,
    bk_neck,
    bk_l_shoulder,
    bk_r_shoulder,
    bk_upper,
    bk_mid,
    bk_lower,
    bk_l_glute,
    bk_r_glute,
    bk_l_hamstr,
    bk_r_hamstr,
    bk_l_calf,
    bk_r_calf,
    bk_l_heel,
    bk_r_heel,
  ];
}

/// Joint-layer hotspots — articulating locations only.
///
/// Every member is a hotspot on the joint layer; [tissue] is fixed.
final class Joint extends BodyRegion {
  const Joint._(super.view, super.cx, super.cy, super.value);

  @override
  BodyTissue get tissue => BodyTissue.joint;

  static const jaw = Joint._(BodyView.front, 100, 44, 'jaw');
  static const neck = Joint._(BodyView.front, 100, 62, 'neck');
  static const l_shoulder = Joint._(BodyView.front, 52, 89, 'l-shoulder');
  static const r_shoulder = Joint._(BodyView.front, 148, 89, 'r-shoulder');
  static const l_elbow = Joint._(BodyView.front, 56, 168, 'l-elbow');
  static const r_elbow = Joint._(BodyView.front, 144, 168, 'r-elbow');
  static const pelvis = Joint._(BodyView.front, 100, 197, 'pelvis');
  static const l_hand = Joint._(BodyView.front, 58, 212, 'l-hand');
  static const r_hand = Joint._(BodyView.front, 142, 212, 'r-hand');
  static const l_knee = Joint._(BodyView.front, 80, 298, 'l-knee');
  static const r_knee = Joint._(BodyView.front, 120, 298, 'r-knee');
  static const l_foot = Joint._(BodyView.front, 80, 372, 'l-foot');
  static const r_foot = Joint._(BodyView.front, 120, 372, 'r-foot');
  static const bk_neck = Joint._(BodyView.back, 100, 62, 'bk-neck');
  static const bk_l_shoulder = Joint._(BodyView.back, 52, 89, 'bk-l-shoulder');
  static const bk_r_shoulder = Joint._(BodyView.back, 148, 89, 'bk-r-shoulder');
  static const bk_upper = Joint._(BodyView.back, 100, 110, 'bk-upper');
  static const bk_mid = Joint._(BodyView.back, 100, 140, 'bk-mid');
  static const bk_lower = Joint._(BodyView.back, 100, 166, 'bk-lower');
  static const bk_l_glute = Joint._(BodyView.back, 82, 206, 'bk-l-glute');
  static const bk_r_glute = Joint._(BodyView.back, 118, 206, 'bk-r-glute');

  static const values = <Joint>[
    jaw,
    neck,
    l_shoulder,
    r_shoulder,
    l_elbow,
    r_elbow,
    pelvis,
    l_hand,
    r_hand,
    l_knee,
    r_knee,
    l_foot,
    r_foot,
    bk_neck,
    bk_l_shoulder,
    bk_r_shoulder,
    bk_upper,
    bk_mid,
    bk_lower,
    bk_l_glute,
    bk_r_glute,
  ];
}

/// Tendon-layer hotspots — tendon insertions only.
///
/// Every member is a hotspot on the tendon layer; [tissue] is fixed.
final class Tendon extends BodyRegion {
  const Tendon._(super.view, super.cx, super.cy, super.value);

  @override
  BodyTissue get tissue => BodyTissue.tendon;

  static const l_shoulder = Tendon._(BodyView.front, 52, 89, 'l-shoulder');
  static const r_shoulder = Tendon._(BodyView.front, 148, 89, 'r-shoulder');
  static const l_elbow = Tendon._(BodyView.front, 56, 168, 'l-elbow');
  static const r_elbow = Tendon._(BodyView.front, 144, 168, 'r-elbow');
  static const pelvis = Tendon._(BodyView.front, 100, 197, 'pelvis');
  static const l_hand = Tendon._(BodyView.front, 58, 212, 'l-hand');
  static const r_hand = Tendon._(BodyView.front, 142, 212, 'r-hand');
  static const l_knee = Tendon._(BodyView.front, 80, 298, 'l-knee');
  static const r_knee = Tendon._(BodyView.front, 120, 298, 'r-knee');
  static const bk_l_shoulder = Tendon._(BodyView.back, 52, 89, 'bk-l-shoulder');
  static const bk_r_shoulder = Tendon._(BodyView.back, 148, 89, 'bk-r-shoulder');
  static const bk_l_heel = Tendon._(BodyView.back, 80, 358, 'bk-l-heel');
  static const bk_r_heel = Tendon._(BodyView.back, 120, 358, 'bk-r-heel');

  static const values = <Tendon>[
    l_shoulder,
    r_shoulder,
    l_elbow,
    r_elbow,
    pelvis,
    l_hand,
    r_hand,
    l_knee,
    r_knee,
    bk_l_shoulder,
    bk_r_shoulder,
    bk_l_heel,
    bk_r_heel,
  ];
}

/// Nerve-layer hotspots — every surface location.
///
/// Every member is a hotspot on the nerve layer; [tissue] is fixed.
final class Nerve extends BodyRegion {
  const Nerve._(super.view, super.cx, super.cy, super.value);

  @override
  BodyTissue get tissue => BodyTissue.nerve;

  static const sinuses = Nerve._(BodyView.front, 100, 22, 'sinuses');
  static const l_eye = Nerve._(BodyView.front, 89, 28, 'l-eye');
  static const r_eye = Nerve._(BodyView.front, 111, 28, 'r-eye');
  static const l_ear = Nerve._(BodyView.front, 79, 32, 'l-ear');
  static const r_ear = Nerve._(BodyView.front, 121, 32, 'r-ear');
  static const jaw = Nerve._(BodyView.front, 100, 44, 'jaw');
  static const bk_l_ear = Nerve._(BodyView.back, 79, 32, 'bk-l-ear');
  static const bk_r_ear = Nerve._(BodyView.back, 121, 32, 'bk-r-ear');
  static const head = Nerve._(BodyView.front, 100, 32, 'head');
  static const neck = Nerve._(BodyView.front, 100, 62, 'neck');
  static const l_shoulder = Nerve._(BodyView.front, 52, 89, 'l-shoulder');
  static const r_shoulder = Nerve._(BodyView.front, 148, 89, 'r-shoulder');
  static const chest = Nerve._(BodyView.front, 100, 106, 'chest');
  static const l_upper_arm = Nerve._(BodyView.front, 58, 120, 'l-upper-arm');
  static const r_upper_arm = Nerve._(BodyView.front, 142, 120, 'r-upper-arm');
  static const abdomen = Nerve._(BodyView.front, 100, 150, 'abdomen');
  static const l_elbow = Nerve._(BodyView.front, 56, 168, 'l-elbow');
  static const r_elbow = Nerve._(BodyView.front, 144, 168, 'r-elbow');
  static const l_forearm = Nerve._(BodyView.front, 56, 196, 'l-forearm');
  static const r_forearm = Nerve._(BodyView.front, 144, 196, 'r-forearm');
  static const pelvis = Nerve._(BodyView.front, 100, 197, 'pelvis');
  static const l_hand = Nerve._(BodyView.front, 58, 212, 'l-hand');
  static const r_hand = Nerve._(BodyView.front, 142, 212, 'r-hand');
  static const l_thigh = Nerve._(BodyView.front, 80, 256, 'l-thigh');
  static const r_thigh = Nerve._(BodyView.front, 120, 256, 'r-thigh');
  static const l_knee = Nerve._(BodyView.front, 80, 298, 'l-knee');
  static const r_knee = Nerve._(BodyView.front, 120, 298, 'r-knee');
  static const l_shin = Nerve._(BodyView.front, 80, 330, 'l-shin');
  static const r_shin = Nerve._(BodyView.front, 120, 330, 'r-shin');
  static const l_foot = Nerve._(BodyView.front, 80, 372, 'l-foot');
  static const r_foot = Nerve._(BodyView.front, 120, 372, 'r-foot');
  static const bk_head = Nerve._(BodyView.back, 100, 32, 'bk-head');
  static const bk_neck = Nerve._(BodyView.back, 100, 62, 'bk-neck');
  static const bk_l_shoulder = Nerve._(BodyView.back, 52, 89, 'bk-l-shoulder');
  static const bk_r_shoulder = Nerve._(BodyView.back, 148, 89, 'bk-r-shoulder');
  static const bk_upper = Nerve._(BodyView.back, 100, 110, 'bk-upper');
  static const bk_mid = Nerve._(BodyView.back, 100, 140, 'bk-mid');
  static const bk_lower = Nerve._(BodyView.back, 100, 166, 'bk-lower');
  static const bk_l_glute = Nerve._(BodyView.back, 82, 206, 'bk-l-glute');
  static const bk_r_glute = Nerve._(BodyView.back, 118, 206, 'bk-r-glute');
  static const bk_l_hamstr = Nerve._(BodyView.back, 80, 256, 'bk-l-hamstr');
  static const bk_r_hamstr = Nerve._(BodyView.back, 120, 256, 'bk-r-hamstr');
  static const bk_l_calf = Nerve._(BodyView.back, 80, 330, 'bk-l-calf');
  static const bk_r_calf = Nerve._(BodyView.back, 120, 330, 'bk-r-calf');
  static const bk_l_heel = Nerve._(BodyView.back, 80, 358, 'bk-l-heel');
  static const bk_r_heel = Nerve._(BodyView.back, 120, 358, 'bk-r-heel');

  static const values = <Nerve>[
    sinuses,
    l_eye,
    r_eye,
    l_ear,
    r_ear,
    jaw,
    bk_l_ear,
    bk_r_ear,
    head,
    neck,
    l_shoulder,
    r_shoulder,
    chest,
    l_upper_arm,
    r_upper_arm,
    abdomen,
    l_elbow,
    r_elbow,
    l_forearm,
    r_forearm,
    pelvis,
    l_hand,
    r_hand,
    l_thigh,
    r_thigh,
    l_knee,
    r_knee,
    l_shin,
    r_shin,
    l_foot,
    r_foot,
    bk_head,
    bk_neck,
    bk_l_shoulder,
    bk_r_shoulder,
    bk_upper,
    bk_mid,
    bk_lower,
    bk_l_glute,
    bk_r_glute,
    bk_l_hamstr,
    bk_r_hamstr,
    bk_l_calf,
    bk_r_calf,
    bk_l_heel,
    bk_r_heel,
  ];
}

/// Organ-layer hotspots — viscera plus head extras.
///
/// Every member is a hotspot on the organ layer; [tissue] is fixed.
final class Organ extends BodyRegion {
  const Organ._(super.view, super.cx, super.cy, super.value);

  @override
  BodyTissue get tissue => BodyTissue.organ;

  static const sinuses = Organ._(BodyView.front, 100, 22, 'sinuses');
  static const l_eye = Organ._(BodyView.front, 89, 28, 'l-eye');
  static const r_eye = Organ._(BodyView.front, 111, 28, 'r-eye');
  static const l_ear = Organ._(BodyView.front, 79, 32, 'l-ear');
  static const r_ear = Organ._(BodyView.front, 121, 32, 'r-ear');
  static const jaw = Organ._(BodyView.front, 100, 44, 'jaw');
  static const bk_l_ear = Organ._(BodyView.back, 79, 32, 'bk-l-ear');
  static const bk_r_ear = Organ._(BodyView.back, 121, 32, 'bk-r-ear');
  static const heart = Organ._(BodyView.front, 92, 108, 'heart');
  static const l_lung = Organ._(BodyView.front, 80, 102, 'l-lung');
  static const r_lung = Organ._(BodyView.front, 120, 102, 'r-lung');
  static const stomach = Organ._(BodyView.front, 95, 148, 'stomach');
  static const liver = Organ._(BodyView.front, 118, 140, 'liver');
  static const intestines = Organ._(BodyView.front, 100, 168, 'intestines');
  static const bladder = Organ._(BodyView.front, 100, 198, 'bladder');
  static const l_kidney = Organ._(BodyView.back, 82, 158, 'l-kidney');
  static const r_kidney = Organ._(BodyView.back, 118, 158, 'r-kidney');

  static const values = <Organ>[
    sinuses,
    l_eye,
    r_eye,
    l_ear,
    r_ear,
    jaw,
    bk_l_ear,
    bk_r_ear,
    heart,
    l_lung,
    r_lung,
    stomach,
    liver,
    intestines,
    bladder,
    l_kidney,
    r_kidney,
  ];
}
