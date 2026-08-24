import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:core/core.dart' show Gender;
import 'package:self_report/self_report.dart'
    show BodyRegion, BodyTissue, BodyView, PainSite, selfReportMessagesOf;
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
          for (final t in BodyTissue.values)
            _chip(s, t.label(messages), tissue == t, () => setState(() => tissue = t)),
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
                  if (region != null) widget.onToggle(PainSite(region: region, tissue: tissue));
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

  /// Skeleton plates have slightly shorter limb proportions than the muscle
  /// atlas. Align bone/joint hit targets with what is visibly drawn.
  Offset _hitCenter(BodyRegion region) {
    if (tissue != BodyTissue.bone && tissue != BodyTissue.joint) {
      return Offset(region.cx, region.cy);
    }
    return switch (region) {
      BodyRegion.l_shoulder || BodyRegion.bk_l_shoulder => const Offset(53, 78),
      BodyRegion.r_shoulder || BodyRegion.bk_r_shoulder => const Offset(140, 78),
      BodyRegion.chest || BodyRegion.bk_upper => const Offset(100, 103),
      BodyRegion.l_upper_arm => const Offset(52, 110),
      BodyRegion.r_upper_arm => const Offset(148, 110),
      BodyRegion.l_elbow => const Offset(44, 145),
      BodyRegion.r_elbow => const Offset(146, 145),
      BodyRegion.l_forearm => const Offset(49, 169),
      BodyRegion.r_forearm => const Offset(151, 169),
      BodyRegion.l_hand => const Offset(43, 192),
      BodyRegion.r_hand => const Offset(153, 192),
      BodyRegion.pelvis => const Offset(100, 181),
      BodyRegion.l_thigh || BodyRegion.bk_l_hamstr => const Offset(82, 231),
      BodyRegion.r_thigh || BodyRegion.bk_r_hamstr => const Offset(118, 231),
      BodyRegion.l_knee => const Offset(82, 277),
      BodyRegion.r_knee => const Offset(118, 277),
      BodyRegion.l_shin || BodyRegion.bk_l_calf => const Offset(82, 322),
      BodyRegion.r_shin || BodyRegion.bk_r_calf => const Offset(118, 322),
      BodyRegion.l_foot || BodyRegion.bk_l_heel => const Offset(85, 362),
      BodyRegion.r_foot || BodyRegion.bk_r_heel => const Offset(115, 362),
      BodyRegion.bk_mid => const Offset(100, 124),
      BodyRegion.bk_lower => const Offset(100, 150),
      BodyRegion.bk_l_glute => const Offset(82, 181),
      BodyRegion.bk_r_glute => const Offset(118, 181),
      _ => Offset(region.cx, region.cy),
    };
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

  Size _hitSize(BodyRegion region) => switch (region) {
        BodyRegion.sinuses => const Size(28, 14),
        BodyRegion.l_eye || BodyRegion.r_eye => const Size(14, 12),
        BodyRegion.l_ear || BodyRegion.r_ear || BodyRegion.bk_l_ear || BodyRegion.bk_r_ear => const Size(12, 16),
        BodyRegion.jaw => const Size(28, 16),
        BodyRegion.heart => const Size(22, 22),
        BodyRegion.l_lung || BodyRegion.r_lung => const Size(24, 32),
        BodyRegion.stomach || BodyRegion.liver => const Size(26, 22),
        BodyRegion.intestines => const Size(36, 28),
        BodyRegion.bladder => const Size(22, 18),
        BodyRegion.l_kidney || BodyRegion.r_kidney => const Size(18, 24),
        BodyRegion.head || BodyRegion.bk_head => const Size(42, 48),
        BodyRegion.neck || BodyRegion.bk_neck => const Size(24, 22),
        BodyRegion.l_shoulder ||
        BodyRegion.r_shoulder ||
        BodyRegion.bk_l_shoulder ||
        BodyRegion.bk_r_shoulder =>
          const Size(38, 32),
        BodyRegion.chest || BodyRegion.bk_upper => const Size(52, 42),
        BodyRegion.abdomen || BodyRegion.bk_mid || BodyRegion.bk_lower => const Size(48, 34),
        BodyRegion.l_upper_arm || BodyRegion.r_upper_arm => const Size(24, 48),
        BodyRegion.l_elbow || BodyRegion.r_elbow => const Size(24, 30),
        BodyRegion.l_forearm || BodyRegion.r_forearm => const Size(22, 38),
        BodyRegion.l_hand || BodyRegion.r_hand => const Size(20, 26),
        BodyRegion.pelvis || BodyRegion.bk_l_glute || BodyRegion.bk_r_glute => const Size(34, 42),
        BodyRegion.l_thigh ||
        BodyRegion.r_thigh ||
        BodyRegion.bk_l_hamstr ||
        BodyRegion.bk_r_hamstr =>
          const Size(30, 68),
        BodyRegion.l_knee || BodyRegion.r_knee => const Size(26, 28),
        BodyRegion.l_shin || BodyRegion.r_shin || BodyRegion.bk_l_calf || BodyRegion.bk_r_calf => const Size(26, 48),
        BodyRegion.l_foot || BodyRegion.r_foot || BodyRegion.bk_l_heel || BodyRegion.bk_r_heel => const Size(28, 30),
      };
}

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
