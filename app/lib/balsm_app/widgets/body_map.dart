import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show Gender;
import 'package:self_report/self_report.dart' show BodyRegion, BodyTissue, BodyView, PainSite, selfReportMessagesOf;
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import 'body_hit_map.dart';

/// Localized label for a [BodyRegion]. Copy lives on the enum (module i69n).
String regionLabel(PatientAppState s, BodyRegion region) => region.labelForLang(s.lang.value);

/// Localized `"Chest · Muscle"` for a marked [PainSite].
String siteLabel(PatientAppState s, PainSite site) =>
    site.label(selfReportMessagesOf(s.lang.value), mid: s.strings.checkin.list_mid);

/// Recolors every path tagged `region-{BodyRegion.id}` / `region-{id}-{n}`.
class _BodyRegionColorMapper extends ColorMapper {
  _BodyRegionColorMapper(Set<BodyRegion> selected, this.selectedColor)
      : selectedIds = Set.unmodifiable(selected.map((region) => region.id));

  final Set<String> selectedIds;
  final Color selectedColor;

  /// Once anything on this layer is marked, everything else recedes.
  /// Stand-in for `.bm-has-sel [id^="region-"]:not([data-sel="1"]) { opacity: .32 }`
  /// — SVG element opacity is not reachable from a [ColorMapper], so the
  /// region's own colors are faded instead.
  static const _dimOpacity = 0.32;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    final regionId = svgRegionId(id);
    if (regionId == null) return color;
    if (!selectedIds.contains(regionId)) {
      if (selectedIds.isEmpty) return color;
      return color.withValues(alpha: color.a * _dimOpacity);
    }
    return attributeName == 'stroke' ? selectedColor.withValues(alpha: 1) : selectedColor;
  }

  @override
  bool operator ==(Object other) =>
      other is _BodyRegionColorMapper &&
      other.selectedColor == selectedColor &&
      setEquals(other.selectedIds, selectedIds);

  @override
  int get hashCode => Object.hash(selectedColor, Object.hashAllUnordered(selectedIds));
}

/// Tappable anatomical body figure. Front/back + tissue chips; tap toggles a
/// [PainSite] on the current tissue layer.
class BodyMap extends StatefulWidget {
  const BodyMap({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.gender,
  });
  final Set<PainSite> selected;
  final ValueChanged<PainSite> onToggle;

  /// Skin layer uses the gendered silhouette; other layers are unisex.
  final Gender gender;
  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  BodyView view = BodyView.front;
  BodyTissue tissue = BodyTissue.skin;

  /// Artwork tap targets for the asset on screen. Empty until it parses, and
  /// for any shape we could not map — [_catalogHit] covers both cases.
  BodyHitMap _hits = BodyHitMap.empty;
  String? _hitsAsset;

  /// Parses [asset] on first use and caches it. No-op once loaded.
  void _ensureHits(String asset) {
    if (_hitsAsset == asset) return;
    _hitsAsset = asset;
    _hits = BodyHitMap.empty;
    BodyHitMap.forAsset(asset).then((map) {
      if (mounted && _hitsAsset == asset) setState(() => _hits = map);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final messages = selfReportMessagesOf(s.lang.value);
    final regions = tissue.regions(view);
    final asset = _asset(tissue, view, widget.gender);
    _ensureHits(asset);
    final c = s.strings.checkin;
    final selectedOnTissue = widget.selected.where((site) => site.tissue == tissue).map((site) => site.region).toSet();
    final selectedLabels = widget.selected.map((site) => site.label(messages, mid: c.list_mid)).toList();
    return Column(children: [
      Row(children: [
        _chip(s, c.body_view_front, view == BodyView.front, () => setState(() => view = BodyView.front)),
        const SizedBox(width: 5),
        _chip(s, c.body_view_back, view == BodyView.back, () => setState(() => view = BodyView.back)),
      ]),
      const SizedBox(height: 8),
      // One scrolling row, never wrapping — the layer strip is a shelf.
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          for (final (i, t) in BodyTissue.values.indexed) ...[
            if (i > 0) const SizedBox(width: 5),
            _chip(s, t.label(messages), tissue == t, () => setState(() => tissue = t), icon: _tissueIcon(t)),
          ],
        ]),
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 16),
        child: Text(
          widget.selected.isEmpty ? c.body_tap : selectedLabels.join(c.list_sep),
          textAlign: TextAlign.center,
          style: Typo.meta(ar: s.rtl).copyWith(
              fontSize: FS.xs,
              fontWeight: FontWeight.w700,
              height: 1.4,
              letterSpacing: s.rtl ? 0 : FS.xs * 0.08,
              color: widget.selected.isEmpty ? T.fg4 : T.fg2),
        ),
      ),
      const SizedBox(height: 8),
      // `.bm-host` centres the plate; design caps height at min(320px, 40vh).
      Center(
        child: SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.40).clamp(220.0, 320.0),
          child: AspectRatio(
            aspectRatio: 200 / 384,
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final region = _hitRegion(details.localPosition, constraints.biggest, regions);
                  if (region != null) widget.onToggle(PainSite(region));
                },
                child: SvgPicture.asset(
                  asset,
                  fit: BoxFit.contain,
                  colorMapper: _BodyRegionColorMapper(
                    selectedOnTissue,
                    s.accent.main.withValues(alpha: _selectionAlpha(tissue)),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ]);
  }

  /// Region under [local] on the current layer, or null.
  ///
  /// Tries the artwork the user actually tapped, then forgives a near miss by
  /// reaching for the closest artwork, then — only while the asset is still
  /// parsing — falls back to catalog positions.
  BodyRegion? _hitRegion(Offset local, Size size, List<BodyRegion> regions) {
    if (size.width <= 0 || size.height <= 0) return null;
    final point = Offset(local.dx / size.width * 200, local.dy / size.height * 384);

    // Assets draw more than a layer exposes — the organ plate paints the whole
    // silhouette, the skeleton plate keeps eyes and abdomen. A shape with no
    // region on this tissue is scenery; keep looking underneath it.
    for (final id in _hits.regionsAt(point)) {
      final region = BodyRegion.fromId(id, tissue);
      if (region != null) return region;
    }
    for (final id in _hits.regionsNear(point)) {
      final region = BodyRegion.fromId(id, tissue);
      if (region != null) return region;
    }
    return _hits.isEmpty ? _catalogHit(point, regions) : null;
  }

  /// Coarse stand-in for the frames before [BodyHitMap] finishes parsing:
  /// nearest catalog position within a fingertip. No tuning table — the
  /// artwork is the source of truth once it is available.
  BodyRegion? _catalogHit(Offset point, List<BodyRegion> regions) {
    const reach = 16.0;
    BodyRegion? best;
    var bestDistance = double.infinity;
    for (final region in regions) {
      final distance = (Offset(region.cx, region.cy) - point).distance;
      if (distance > reach || distance >= bestDistance) continue;
      bestDistance = distance;
      best = region;
    }
    return best;
  }

  Widget _chip(PatientAppState s, String label, bool active, VoidCallback onTap, {IconData? icon}) {
    final on = active;
    final fg = on ? s.accent.d : T.fg2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? s.accent.bg : Colors.white,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: on ? s.accent.main : T.border, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
          ],
          Text(label,
              softWrap: false,
              style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w600, color: fg)),
        ]),
      ),
    );
  }
}

/// Layer glyphs, matching the design's lucide set on `BODY_LAYERS`.
IconData _tissueIcon(BodyTissue tissue) => switch (tissue) {
      BodyTissue.skin => LucideIcons.user,
      BodyTissue.muscle => LucideIcons.dumbbell,
      BodyTissue.bone => LucideIcons.bone,
      BodyTissue.joint => LucideIcons.target,
      BodyTissue.tendon => LucideIcons.link2,
      BodyTissue.nerve => LucideIcons.zap,
      BodyTissue.organ => LucideIcons.heartPulse,
    };

double _selectionAlpha(BodyTissue tissue) => switch (tissue) {
      BodyTissue.skin => .55,
      BodyTissue.muscle => .88,
      BodyTissue.bone => .35,
      BodyTissue.joint => .78,
      BodyTissue.tendon => .58,
      BodyTissue.nerve => .30,
      BodyTissue.organ => .72,
    };

String _asset(BodyTissue tissue, BodyView view, Gender gender) {
  final side = view == BodyView.front ? 'front' : 'back';
  return switch (tissue) {
    BodyTissue.skin => 'assets/body/${gender == Gender.female ? 'female' : 'male'}_$side.svg',
    BodyTissue.muscle => 'assets/body/muscles_$side.svg',
    BodyTissue.bone => 'assets/body/bones_$side.svg',
    BodyTissue.joint => 'assets/body/joints_$side.svg',
    BodyTissue.tendon => 'assets/body/tendons_$side.svg',
    BodyTissue.nerve => 'assets/body/nerves_$side.svg',
    BodyTissue.organ => 'assets/body/organs_$side.svg',
  };
}
