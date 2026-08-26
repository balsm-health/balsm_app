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

  /// Catalog for this layer. Every entry is the matching [BodyRegion] subclass.
  List<BodyRegion> get catalog => switch (this) {
        skin => Skin.values,
        muscle => Muscle.values,
        bone => Bone.values,
        joint => Joint.values,
        tendon => Tendon.values,
        nerve => Nerve.values,
        organ => Organ.values,
      };

  static final Map<(BodyTissue, BodyView), List<BodyRegion>> _byView = {
    for (final t in values)
      for (final v in BodyView.values)
        (t, v): List.unmodifiable([
          for (final r in t.catalog)
            if (r.view == v) r,
        ]),
  };

  /// Regions selectable on this layer for [view]. Built once, safe to call
  /// from `build` — no per-frame allocation.
  List<BodyRegion> regions(BodyView view) => _byView[(this, view)]!;

  /// Whether that *location* is a hotspot on this layer. Takes any layer's
  /// instance — `bone.allows(Skin.chest)` asks about the chest, not the skin.
  bool allows(BodyRegion region) => BodyRegion.fromId(region.value, this) != null;

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
