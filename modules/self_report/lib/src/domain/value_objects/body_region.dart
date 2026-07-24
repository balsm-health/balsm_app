/// Which anatomical view a [BodyRegion] belongs to.
enum BodyView { front, back }

/// A selectable region on the body figure (body-map hotspot). Structural facts
/// only: stable [id], [view], and figure coordinates ([cx]/[cy] in the 200×400
/// body-figure space). The localized label resolves from the i69n bundle
/// (`bodyRegion.<id>`); it is intentionally NOT stored here.
class BodyRegion {
  const BodyRegion(this.id, this.view, this.cx, this.cy);

  final String id;
  final BodyView view;
  final double cx;
  final double cy;

  /// Front-view regions, in render order.
  static const front = <BodyRegion>[
    BodyRegion('head', BodyView.front, 100, 32),
    BodyRegion('neck', BodyView.front, 100, 62),
    BodyRegion('l-shoulder', BodyView.front, 52, 89),
    BodyRegion('r-shoulder', BodyView.front, 148, 89),
    BodyRegion('chest', BodyView.front, 100, 106),
    BodyRegion('l-upper-arm', BodyView.front, 58, 120),
    BodyRegion('r-upper-arm', BodyView.front, 142, 120),
    BodyRegion('abdomen', BodyView.front, 100, 150),
    BodyRegion('l-elbow', BodyView.front, 56, 168),
    BodyRegion('r-elbow', BodyView.front, 144, 168),
    BodyRegion('l-forearm', BodyView.front, 56, 196),
    BodyRegion('r-forearm', BodyView.front, 144, 196),
    BodyRegion('pelvis', BodyView.front, 100, 197),
    BodyRegion('l-hand', BodyView.front, 58, 212),
    BodyRegion('r-hand', BodyView.front, 142, 212),
    BodyRegion('l-thigh', BodyView.front, 80, 256),
    BodyRegion('r-thigh', BodyView.front, 120, 256),
    BodyRegion('l-knee', BodyView.front, 80, 298),
    BodyRegion('r-knee', BodyView.front, 120, 298),
    BodyRegion('l-shin', BodyView.front, 80, 330),
    BodyRegion('r-shin', BodyView.front, 120, 330),
    BodyRegion('l-foot', BodyView.front, 80, 372),
    BodyRegion('r-foot', BodyView.front, 120, 372),
  ];

  /// Back-view regions, in render order.
  static const back = <BodyRegion>[
    BodyRegion('bk-head', BodyView.back, 100, 32),
    BodyRegion('bk-neck', BodyView.back, 100, 62),
    BodyRegion('bk-l-shoulder', BodyView.back, 52, 89),
    BodyRegion('bk-r-shoulder', BodyView.back, 148, 89),
    BodyRegion('bk-upper', BodyView.back, 100, 110),
    BodyRegion('bk-mid', BodyView.back, 100, 140),
    BodyRegion('bk-lower', BodyView.back, 100, 166),
    BodyRegion('bk-l-glute', BodyView.back, 82, 206),
    BodyRegion('bk-r-glute', BodyView.back, 118, 206),
    BodyRegion('bk-l-hamstr', BodyView.back, 80, 256),
    BodyRegion('bk-r-hamstr', BodyView.back, 120, 256),
    BodyRegion('bk-l-calf', BodyView.back, 80, 330),
    BodyRegion('bk-r-calf', BodyView.back, 120, 330),
    BodyRegion('bk-l-heel', BodyView.back, 80, 358),
    BodyRegion('bk-r-heel', BodyView.back, 120, 358),
  ];

  /// Every region across both views.
  static const all = [...front, ...back];

  static final Map<String, BodyRegion> _byId = {
    for (final r in all) r.id: r,
  };

  /// Resolve a stored region id, or null if unknown.
  static BodyRegion? fromId(String id) => _byId[id];

  @override
  bool operator ==(Object other) => other is BodyRegion && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
