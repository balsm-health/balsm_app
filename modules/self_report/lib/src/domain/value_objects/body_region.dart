import '../../i18n/strings.dart';

/// Which anatomical view a [BodyRegion] belongs to.
enum BodyView { front, back }

/// A selectable region on the body figure (body-map hotspot). Closed catalog —
/// adding a region is a product decision, not free-form input.
///
/// Structural facts: [view], figure coordinates ([cx]/[cy] in the 200×400
/// body-figure space), persist [id]. Localized copy lives in the module i69n
/// bundle; resolve via [label] / [labelForLang].
enum BodyRegion {
  head(BodyView.front, 100, 32),
  neck(BodyView.front, 100, 62),
  lShoulder(BodyView.front, 52, 89, 'l-shoulder'),
  rShoulder(BodyView.front, 148, 89, 'r-shoulder'),
  chest(BodyView.front, 100, 106),
  lUpperArm(BodyView.front, 58, 120, 'l-upper-arm'),
  rUpperArm(BodyView.front, 142, 120, 'r-upper-arm'),
  abdomen(BodyView.front, 100, 150),
  lElbow(BodyView.front, 56, 168, 'l-elbow'),
  rElbow(BodyView.front, 144, 168, 'r-elbow'),
  lForearm(BodyView.front, 56, 196, 'l-forearm'),
  rForearm(BodyView.front, 144, 196, 'r-forearm'),
  pelvis(BodyView.front, 100, 197),
  lHand(BodyView.front, 58, 212, 'l-hand'),
  rHand(BodyView.front, 142, 212, 'r-hand'),
  lThigh(BodyView.front, 80, 256, 'l-thigh'),
  rThigh(BodyView.front, 120, 256, 'r-thigh'),
  lKnee(BodyView.front, 80, 298, 'l-knee'),
  rKnee(BodyView.front, 120, 298, 'r-knee'),
  lShin(BodyView.front, 80, 330, 'l-shin'),
  rShin(BodyView.front, 120, 330, 'r-shin'),
  lFoot(BodyView.front, 80, 372, 'l-foot'),
  rFoot(BodyView.front, 120, 372, 'r-foot'),
  bkHead(BodyView.back, 100, 32, 'bk-head'),
  bkNeck(BodyView.back, 100, 62, 'bk-neck'),
  bkLShoulder(BodyView.back, 52, 89, 'bk-l-shoulder'),
  bkRShoulder(BodyView.back, 148, 89, 'bk-r-shoulder'),
  bkUpper(BodyView.back, 100, 110, 'bk-upper'),
  bkMid(BodyView.back, 100, 140, 'bk-mid'),
  bkLower(BodyView.back, 100, 166, 'bk-lower'),
  bkLGlute(BodyView.back, 82, 206, 'bk-l-glute'),
  bkRGlute(BodyView.back, 118, 206, 'bk-r-glute'),
  bkLHamstr(BodyView.back, 80, 256, 'bk-l-hamstr'),
  bkRHamstr(BodyView.back, 120, 256, 'bk-r-hamstr'),
  bkLCalf(BodyView.back, 80, 330, 'bk-l-calf'),
  bkRCalf(BodyView.back, 120, 330, 'bk-r-calf'),
  bkLHeel(BodyView.back, 80, 358, 'bk-l-heel'),
  bkRHeel(BodyView.back, 120, 358, 'bk-r-heel');

  const BodyRegion(this.view, this.cx, this.cy, [this._id]);

  final BodyView view;
  final double cx;
  final double cy;
  final String? _id;

  /// Stable persistence / i69n key. Hyphenated stored form, or [name] when
  /// that already matches (head, chest, abdomen, …).
  String get id => _id ?? name;

  /// Front-view regions, in render order.
  static const front = <BodyRegion>[
    head,
    neck,
    lShoulder,
    rShoulder,
    chest,
    lUpperArm,
    rUpperArm,
    abdomen,
    lElbow,
    rElbow,
    lForearm,
    rForearm,
    pelvis,
    lHand,
    rHand,
    lThigh,
    rThigh,
    lKnee,
    rKnee,
    lShin,
    rShin,
    lFoot,
    rFoot,
  ];

  /// Back-view regions, in render order.
  static const back = <BodyRegion>[
    bkHead,
    bkNeck,
    bkLShoulder,
    bkRShoulder,
    bkUpper,
    bkMid,
    bkLower,
    bkLGlute,
    bkRGlute,
    bkLHamstr,
    bkRHamstr,
    bkLCalf,
    bkRCalf,
    bkLHeel,
    bkRHeel,
  ];

  /// Every region across both views.
  static const all = [...front, ...back];

  static final Map<String, BodyRegion> _byId = {
    for (final r in values) r.id: r,
  };

  /// Resolve a stored region id, or null if unknown / retired.
  static BodyRegion? fromId(String id) => _byId[id];

  /// Label in [messages]' locale (module i69n `body.*`).
  String label(Messages messages) {
    final b = messages.body;
    return switch (this) {
      head => b.head,
      neck => b.neck,
      lShoulder => b.l_shoulder,
      rShoulder => b.r_shoulder,
      chest => b.chest,
      lUpperArm => b.l_upper_arm,
      rUpperArm => b.r_upper_arm,
      abdomen => b.abdomen,
      lElbow => b.l_elbow,
      rElbow => b.r_elbow,
      lForearm => b.l_forearm,
      rForearm => b.r_forearm,
      pelvis => b.pelvis,
      lHand => b.l_hand,
      rHand => b.r_hand,
      lThigh => b.l_thigh,
      rThigh => b.r_thigh,
      lKnee => b.l_knee,
      rKnee => b.r_knee,
      lShin => b.l_shin,
      rShin => b.r_shin,
      lFoot => b.l_foot,
      rFoot => b.r_foot,
      bkHead => b.bk_head,
      bkNeck => b.bk_neck,
      bkLShoulder => b.bk_l_shoulder,
      bkRShoulder => b.bk_r_shoulder,
      bkUpper => b.bk_upper,
      bkMid => b.bk_mid,
      bkLower => b.bk_lower,
      bkLGlute => b.bk_l_glute,
      bkRGlute => b.bk_r_glute,
      bkLHamstr => b.bk_l_hamstr,
      bkRHamstr => b.bk_r_hamstr,
      bkLCalf => b.bk_l_calf,
      bkRCalf => b.bk_r_calf,
      bkLHeel => b.bk_l_heel,
      bkRHeel => b.bk_r_heel,
    };
  }

  /// Label for a language code (`en` / `ar`).
  String labelForLang(String lang) => label(selfReportMessagesOf(lang));
}
