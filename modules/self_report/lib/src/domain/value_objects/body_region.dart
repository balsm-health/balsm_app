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
  l_shoulder(BodyView.front, 52, 89, 'l-shoulder'),
  r_shoulder(BodyView.front, 148, 89, 'r-shoulder'),
  chest(BodyView.front, 100, 106),
  l_upper_arm(BodyView.front, 58, 120, 'l-upper-arm'),
  r_upper_arm(BodyView.front, 142, 120, 'r-upper-arm'),
  abdomen(BodyView.front, 100, 150),
  l_elbow(BodyView.front, 56, 168, 'l-elbow'),
  r_elbow(BodyView.front, 144, 168, 'r-elbow'),
  l_forearm(BodyView.front, 56, 196, 'l-forearm'),
  r_forearm(BodyView.front, 144, 196, 'r-forearm'),
  pelvis(BodyView.front, 100, 197),
  l_hand(BodyView.front, 58, 212, 'l-hand'),
  r_hand(BodyView.front, 142, 212, 'r-hand'),
  l_thigh(BodyView.front, 80, 256, 'l-thigh'),
  r_thigh(BodyView.front, 120, 256, 'r-thigh'),
  l_knee(BodyView.front, 80, 298, 'l-knee'),
  r_knee(BodyView.front, 120, 298, 'r-knee'),
  l_shin(BodyView.front, 80, 330, 'l-shin'),
  r_shin(BodyView.front, 120, 330, 'r-shin'),
  l_foot(BodyView.front, 80, 372, 'l-foot'),
  r_foot(BodyView.front, 120, 372, 'r-foot'),
  bk_head(BodyView.back, 100, 32, 'bk-head'),
  bk_neck(BodyView.back, 100, 62, 'bk-neck'),
  bk_l_shoulder(BodyView.back, 52, 89, 'bk-l-shoulder'),
  bk_r_shoulder(BodyView.back, 148, 89, 'bk-r-shoulder'),
  bk_upper(BodyView.back, 100, 110, 'bk-upper'),
  bk_mid(BodyView.back, 100, 140, 'bk-mid'),
  bk_lower(BodyView.back, 100, 166, 'bk-lower'),
  bk_l_glute(BodyView.back, 82, 206, 'bk-l-glute'),
  bk_r_glute(BodyView.back, 118, 206, 'bk-r-glute'),
  bk_l_hamstr(BodyView.back, 80, 256, 'bk-l-hamstr'),
  bk_r_hamstr(BodyView.back, 120, 256, 'bk-r-hamstr'),
  bk_l_calf(BodyView.back, 80, 330, 'bk-l-calf'),
  bk_r_calf(BodyView.back, 120, 330, 'bk-r-calf'),
  bk_l_heel(BodyView.back, 80, 358, 'bk-l-heel'),
  bk_r_heel(BodyView.back, 120, 358, 'bk-r-heel');

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
  ];

  /// Back-view regions, in render order.
  static const back = <BodyRegion>[
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
      l_shoulder => b.l_shoulder,
      r_shoulder => b.r_shoulder,
      chest => b.chest,
      l_upper_arm => b.l_upper_arm,
      r_upper_arm => b.r_upper_arm,
      abdomen => b.abdomen,
      l_elbow => b.l_elbow,
      r_elbow => b.r_elbow,
      l_forearm => b.l_forearm,
      r_forearm => b.r_forearm,
      pelvis => b.pelvis,
      l_hand => b.l_hand,
      r_hand => b.r_hand,
      l_thigh => b.l_thigh,
      r_thigh => b.r_thigh,
      l_knee => b.l_knee,
      r_knee => b.r_knee,
      l_shin => b.l_shin,
      r_shin => b.r_shin,
      l_foot => b.l_foot,
      r_foot => b.r_foot,
      bk_head => b.bk_head,
      bk_neck => b.bk_neck,
      bk_l_shoulder => b.bk_l_shoulder,
      bk_r_shoulder => b.bk_r_shoulder,
      bk_upper => b.bk_upper,
      bk_mid => b.bk_mid,
      bk_lower => b.bk_lower,
      bk_l_glute => b.bk_l_glute,
      bk_r_glute => b.bk_r_glute,
      bk_l_hamstr => b.bk_l_hamstr,
      bk_r_hamstr => b.bk_r_hamstr,
      bk_l_calf => b.bk_l_calf,
      bk_r_calf => b.bk_r_calf,
      bk_l_heel => b.bk_l_heel,
      bk_r_heel => b.bk_r_heel,
    };
  }

  /// Label for a language code (`en` / `ar`).
  String labelForLang(String lang) => label(selfReportMessagesOf(lang));
}
