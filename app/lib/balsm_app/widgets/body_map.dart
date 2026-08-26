import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:core/core.dart' show Gender;
import 'package:self_report/self_report.dart' show BodyRegion, BodyTissue, BodyView, PainSite, selfReportMessagesOf;
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Localized label for a [BodyRegion]. Copy lives on the enum (module i69n).
String regionLabel(PatientAppState s, BodyRegion region) => region.labelForLang(s.lang.value);

/// Localized `"Chest · Muscle"` for a marked [PainSite].
String siteLabel(PatientAppState s, PainSite site) =>
    site.label(selfReportMessagesOf(s.lang.value), mid: s.strings.checkin.list_mid);

/// Persist id encoded in `region-{id}` or `region-{id}-{n}` path ids.
String? _svgRegionId(String? id) {
  if (id == null || !id.startsWith('region-')) return null;
  final rest = id.substring('region-'.length);
  final last = rest.lastIndexOf('-');
  if (last <= 0) return rest;
  if (int.tryParse(rest.substring(last + 1)) == null) return rest;
  return rest.substring(0, last);
}

/// Recolors every path tagged `region-{BodyRegion.id}` / `region-{id}-{n}`.
class _BodyRegionColorMapper extends ColorMapper {
  _BodyRegionColorMapper(Set<BodyRegion> selected, this.selectedColor)
      : selectedIds = Set.unmodifiable(selected.map((region) => region.id));

  final Set<String> selectedIds;
  final Color selectedColor;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    final regionId = _svgRegionId(id);
    if (regionId == null || !selectedIds.contains(regionId)) return color;
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
  BodyTissue tissue = BodyTissue.muscle;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final messages = selfReportMessagesOf(s.lang.value);
    final regions = tissue.regions(view);
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
      Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final t in BodyTissue.values) _chip(s, t.label(messages), tissue == t, () => setState(() => tissue = t)),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        widget.selected.isEmpty ? c.body_tap : selectedLabels.join(c.list_sep),
        textAlign: TextAlign.center,
        style: Typo.meta(ar: s.rtl).copyWith(
            fontSize: FS.xs,
            fontWeight: FontWeight.w700,
            letterSpacing: s.rtl ? 0 : 0.8,
            color: widget.selected.isEmpty ? T.fg4 : T.fg2),
      ),
      const SizedBox(height: 8),
      Center(
        child: SizedBox(
          width: 190,
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
                  _asset(tissue, view, widget.gender),
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

  BodyRegion? _hitRegion(Offset local, Size size, List<BodyRegion> regions) {
    if (size.width <= 0 || size.height <= 0) return null;
    final x = local.dx / size.width * 200;
    final y = local.dy / size.height * 384;
    BodyRegion? best;
    var bestScore = double.infinity;
    for (final region in regions) {
      final hit = _hitSize(region);
      final center = _hitCenter(region);
      final dx = (x - center.dx).abs() / (hit.width / 2);
      final dy = (y - center.dy).abs() / (hit.height / 2);
      if (dx > 1.2 || dy > 1.2) continue;
      final score = dx * dx + dy * dy;
      if (score < bestScore) {
        bestScore = score;
        best = region;
      }
    }
    return best;
  }

  /// Where to aim a tap for [region] on the layer currently shown.
  ///
  /// Skeleton plates draw limbs shorter and higher than the muscle atlas, so
  /// those layers override the catalog position; everything else taps where the
  /// region says it is.
  Offset _hitCenter(BodyRegion region) {
    final catalog = Offset(region.cx, region.cy);
    if (!_skeletonLayers.contains(tissue)) return catalog;
    return _skeletonCenters[region.id] ?? catalog;
  }

  Widget _chip(PatientAppState s, String label, bool active, VoidCallback onTap) {
    final on = active;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? s.accent.bg : Colors.white,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: on ? s.accent.main : T.border, width: 1.5),
        ),
        child: Text(label,
            style: Typo.meta(ar: s.rtl)
                .copyWith(fontSize: FS.xs, fontWeight: FontWeight.w600, color: on ? s.accent.d : T.fg3)),
      ),
    );
  }

  Size _hitSize(BodyRegion region) => switch (region.id) {
        'sinuses' => const Size(28, 14),
        'l-eye' || 'r-eye' => const Size(14, 12),
        'l-ear' || 'r-ear' || 'bk-l-ear' || 'bk-r-ear' => const Size(12, 16),
        'jaw' => const Size(28, 16),
        'heart' => const Size(22, 22),
        'l-lung' || 'r-lung' => const Size(24, 32),
        'stomach' || 'liver' => const Size(26, 22),
        'intestines' => const Size(36, 28),
        'bladder' => const Size(22, 18),
        'l-kidney' || 'r-kidney' => const Size(18, 24),
        'head' || 'bk-head' => const Size(42, 48),
        'neck' || 'bk-neck' => const Size(24, 22),
        'l-shoulder' || 'r-shoulder' || 'bk-l-shoulder' || 'bk-r-shoulder' => const Size(38, 32),
        'chest' || 'bk-upper' => const Size(52, 42),
        'abdomen' || 'bk-mid' || 'bk-lower' => const Size(48, 34),
        'l-upper-arm' || 'r-upper-arm' => const Size(24, 48),
        'l-elbow' || 'r-elbow' => const Size(24, 30),
        'l-forearm' || 'r-forearm' => const Size(22, 38),
        'l-hand' || 'r-hand' => const Size(20, 26),
        'pelvis' || 'bk-l-glute' || 'bk-r-glute' => const Size(34, 42),
        'l-thigh' || 'r-thigh' || 'bk-l-hamstr' || 'bk-r-hamstr' => const Size(30, 68),
        'l-knee' || 'r-knee' => const Size(26, 28),
        'l-shin' || 'r-shin' || 'bk-l-calf' || 'bk-r-calf' => const Size(26, 48),
        'l-foot' || 'r-foot' || 'bk-l-heel' || 'bk-r-heel' => const Size(28, 30),
        _ => const Size(28, 30),
      };
}

/// Layers rendered on the skeleton plates rather than the muscle atlas.
const _skeletonLayers = <BodyTissue>{BodyTissue.bone, BodyTissue.joint};

/// Hit centers for [_skeletonLayers], in SVG units on the 200×384 viewBox.
/// A location absent here is tapped at its catalog `(cx, cy)`.
///
/// Front and back entries are tuned independently — they coincide only where
/// the two plates happen to align.
const _skeletonCenters = <String, Offset>{
  // Shoulders and torso.
  'l-shoulder': Offset(53, 78),
  'r-shoulder': Offset(140, 78),
  'bk-l-shoulder': Offset(53, 78),
  'bk-r-shoulder': Offset(140, 78),
  'chest': Offset(100, 103),
  'bk-upper': Offset(100, 103),
  'bk-mid': Offset(100, 124),
  'bk-lower': Offset(100, 150),
  // Arms.
  'l-upper-arm': Offset(52, 110),
  'r-upper-arm': Offset(148, 110),
  'l-elbow': Offset(44, 145),
  'r-elbow': Offset(146, 145),
  'l-forearm': Offset(49, 169),
  'r-forearm': Offset(151, 169),
  'l-hand': Offset(43, 192),
  'r-hand': Offset(153, 192),
  // Pelvis and glutes.
  'pelvis': Offset(100, 181),
  'bk-l-glute': Offset(82, 181),
  'bk-r-glute': Offset(118, 181),
  // Legs.
  'l-thigh': Offset(82, 231),
  'r-thigh': Offset(118, 231),
  'bk-l-hamstr': Offset(82, 231),
  'bk-r-hamstr': Offset(118, 231),
  'l-knee': Offset(82, 277),
  'r-knee': Offset(118, 277),
  'l-shin': Offset(82, 322),
  'r-shin': Offset(118, 322),
  'bk-l-calf': Offset(82, 322),
  'bk-r-calf': Offset(118, 322),
  'l-foot': Offset(85, 362),
  'r-foot': Offset(115, 362),
  'bk-l-heel': Offset(85, 362),
  'bk-r-heel': Offset(115, 362),
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
