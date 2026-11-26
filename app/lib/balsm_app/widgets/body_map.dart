import 'package:account/account.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:self_report/self_report.dart';

import '../app_state.dart';
import '../assets.dart';
import 'body_hit_map.dart';
import 'select_field.dart';

/// Localized label for a [BodyRegion]. Copy lives on the enum (module i69n).
String regionLabel(PatientAppState s, BodyRegion region) => region.labelForLang(s.lang.value);

/// Localized `"Chest · Muscle"` for a marked [PainSite].
String siteLabel(PatientAppState s, PainSite site) =>
    site.label(selfReportMessagesOf(s.lang.value), mid: s.strings.checkin.list_mid);

/// Signed-in profile's gender, for the skin layer's silhouette. Null while
/// signed out or before the profile loads — callers fall back to
/// [PatientAppState.gender].
final FutureProvider<Gender?> currentProfileGenderProvider = FutureProvider.autoDispose<Gender?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  return (await ref.watch(accountProfileUseCaseProvider).load())?.gender;
});

/// Artwork tap targets for one body asset, parsed once per asset and kept for
/// the session (static artwork, no PHI).
final FutureProviderFamily<BodyHitMap, String> bodyHitMapProvider =
    FutureProvider.family<BodyHitMap, String>((ref, asset) => BodyHitMap.forAsset(asset));

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
class BodyMap extends ConsumerStatefulWidget {
  const BodyMap({
    required this.selected,
    required this.onToggle,
    required this.gender,
    super.key,
  });
  final Set<PainSite> selected;
  final ValueChanged<PainSite> onToggle;

  /// Skin layer uses the gendered silhouette; other layers are unisex.
  final Gender gender;
  @override
  ConsumerState<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends ConsumerState<BodyMap> {
  BodyView view = BodyView.front;

  /// Free choice while nothing is selected. Once the selection locks the
  /// layer (see [lockedBodyTissue]), this is kept in sync with it so a
  /// later "Clear all" reopens the dropdown on the layer that was in use
  /// instead of resetting to skin.
  BodyTissue _tissue = BodyTissue.skin;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final messages = selfReportMessagesOf(s.lang.value);
    // One tissue per record: once ≥1 region is marked, the layer the
    // selection is already on wins over whatever the dropdown last showed —
    // the map can never display a layer other than the one in use.
    final lockedTissue = lockedBodyTissue(widget.selected);
    if (lockedTissue != null) _tissue = lockedTissue;
    final tissue = _tissue;
    final locked = lockedTissue != null;
    final regions = tissue.regions(view);
    final asset = _asset(tissue, view, widget.gender);
    // Artwork tap targets: empty until the asset parses, and for any shape we
    // could not map — [_catalogHit] covers both cases.
    final hits = ref.watch(bodyHitMapProvider(asset)).value ?? BodyHitMap.empty;
    final c = s.strings.checkin;
    final selectedOnTissue = widget.selected.where((site) => site.tissue == tissue).map((site) => site.region).toSet();
    return Column(
      children: [
        // `display:flex; gap:5; align-items:center` — chips keep their natural
        // size, the layer select is the only flexible (`flex:1, min-width:0`)
        // child, so it is the one that shrinks at narrow widths or large text
        // scales instead of the row overflowing sideways (unrecoverable inside
        // a vertically-scrolling sheet).
        Row(
          spacing: 5,
          children: [
            _Chip(s, c.body_view_front, view == BodyView.front, () => setState(() => view = BodyView.front)),
            _Chip(s, c.body_view_back, view == BodyView.back, () => setState(() => view = BodyView.back)),
            if (BodyTissue.values.length > 1)
              Expanded(
                child: SelectField<BodyTissue>(
                  dense: true,
                  value: tissue,
                  enabled: !locked,
                  semanticsLabel: c.body_layer,
                  items: [for (final t in BodyTissue.values) (t, t.label(messages))],
                  onChanged: (t) => setState(() => _tissue = t),
                ),
              ),
          ],
        ),
        if (locked) ...[
          const SizedBox(height: 4),
          Text(
            c.body_layer_locked(s.gender),
            textAlign: TextAlign.center,
            style: Typo.meta(ar: s.rtl)
                .copyWith(fontSize: FontSizes.meta, fontWeight: FontWeight.w600, color: AppColors.textHint),
          ),
        ],
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 16),
          child: widget.selected.isEmpty
              ? Text(
                  c.body_tap(s.gender),
                  textAlign: TextAlign.center,
                  style: Typo.meta(ar: s.rtl).copyWith(
                    fontSize: FontSizes.meta,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    letterSpacing: s.rtl ? 0 : FontSizes.meta * 0.08,
                    color: AppColors.textHint,
                  ),
                )
              : Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final site in widget.selected)
                        _SelectedChip(
                          label: site.label(messages, mid: c.list_mid),
                          onRemove: () => widget.onToggle(site),
                          removeLabel: c.body_remove(site.label(messages, mid: c.list_mid)),
                        ),
                      if (widget.selected.length > 1)
                        _ClearAllButton(
                          label: c.body_clear_all,
                          onTap: () => widget.selected.toList().forEach(widget.onToggle),
                        ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 8),
        // `.bm-host` centres the plate; design caps height at min(320px, 40vh).
        Center(
          // Cap the height only. Pinning it makes AspectRatio derive a width the
          // column may not have, and a horizontal overflow is exactly the kind a
          // vertically-scrolling sheet can never reveal.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height * 0.40).clamp(220.0, 320.0),
            ),
            child: AspectRatio(
              aspectRatio: 200 / 384,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final region = _hitRegion(hits, details.localPosition, constraints.biggest, regions, tissue);
                      if (region == null) return;
                      final site = PainSite(region);
                      // One tissue per record: a tap that would add a different
                      // tissue than the locked selection is dropped silently —
                      // removing an already-marked site is always allowed.
                      if (canToggleSite(widget.selected, site)) widget.onToggle(site);
                    },
                    child: SvgPicture.asset(
                      asset,
                      colorMapper: _BodyRegionColorMapper(
                        selectedOnTissue,
                        s.accent.main.withValues(alpha: _selectionAlpha(tissue)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Region under [local] on the current layer, or null.
  ///
  /// Tries the artwork the user actually tapped, then forgives a near miss by
  /// reaching for the closest artwork, then — only while the asset is still
  /// parsing — falls back to catalog positions.
  BodyRegion? _hitRegion(BodyHitMap hits, Offset local, Size size, List<BodyRegion> regions, BodyTissue tissue) {
    if (size.width <= 0 || size.height <= 0) return null;
    final point = Offset(local.dx / size.width * 200, local.dy / size.height * 384);

    // Assets draw more than a layer exposes — the organ plate paints the whole
    // silhouette, the skeleton plate keeps eyes and abdomen. A shape with no
    // region on this tissue is scenery; keep looking underneath it.
    for (final id in hits.regionsAt(point)) {
      final region = BodyRegion.fromId(id, tissue);
      if (region != null) return region;
    }
    for (final id in hits.regionsNear(point)) {
      final region = BodyRegion.fromId(id, tissue);
      if (region != null) return region;
    }
    return hits.isEmpty ? _catalogHit(point, regions) : null;
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
}

/// A selected [PainSite], rendered as an "on" chip with a trailing remove
/// button — `widget.onToggle(site)` un-marks it.
class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.label, required this.removeLabel, required this.onRemove});
  final String label;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      decoration: BoxDecoration(
        color: s.accent.bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: s.accent.main, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            softWrap: false,
            style:
                Typo.meta(ar: s.rtl).copyWith(fontSize: FontSizes.meta, fontWeight: FontWeight.w600, color: s.accent.d),
          ),
          const SizedBox(width: 2),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: SizedBox(
                width: 24,
                height: 24,
                child: Semantics(
                  label: removeLabel,
                  child: Icon(LucideIcons.x, size: 14, color: s.accent.d),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Clear all" — toggles every currently-selected site off.
class _ClearAllButton extends StatelessWidget {
  const _ClearAllButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Typo.meta(ar: s.rtl).copyWith(
            fontSize: FontSizes.meta,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

/// Read-only body map for a saved record: one plate per view that holds a
/// marked site, highlighted exactly as it was on the input [BodyMap], with the
/// site labels underneath. No tissue/view controls and no tap targets.
class BodyMapPreview extends ConsumerWidget {
  const BodyMapPreview({required this.sites, super.key});
  final Set<PainSite> sites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    if (sites.isEmpty) return const SizedBox.shrink();
    final gender = ref.watch(currentProfileGenderProvider).value ?? s.gender;
    final messages = selfReportMessagesOf(s.lang.value);
    final c = s.strings.checkin;
    // One tissue per record is enforced on input, but older records may mix
    // layers — each tissue/view pair that holds a site gets its own plate.
    final plates = <(BodyTissue, BodyView)>[
      for (final tissue in BodyTissue.values)
        for (final view in BodyView.values)
          if (sites.any((site) => site.tissue == tissue && site.region.view == view)) (tissue, view),
    ];
    final multiTissue = plates.map((p) => p.$1).toSet().length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (tissue, view) in plates)
              SizedBox(
                width: 120,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 200 / 384,
                      child: SvgPicture.asset(
                        _asset(tissue, view, gender),
                        excludeFromSemantics: true,
                        colorMapper: _BodyRegionColorMapper(
                          {
                            for (final site in sites)
                              if (site.tissue == tissue) site.region,
                          },
                          s.accent.main.withValues(alpha: _selectionAlpha(tissue)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (view == BodyView.front) c.body_view_front else c.body_view_back,
                        if (multiTissue) tissue.label(messages),
                      ].join(c.list_mid),
                      textAlign: TextAlign.center,
                      style: Typo.meta(ar: s.rtl).copyWith(
                        fontSize: FontSizes.meta,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final site in sites)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: s.accent.bg,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: s.accent.main, width: 1.5),
                ),
                child: Text(
                  site.label(messages, mid: c.list_mid),
                  style: Typo.meta(ar: s.rtl)
                      .copyWith(fontSize: FontSizes.meta, fontWeight: FontWeight.w600, color: s.accent.d),
                ),
              ),
          ],
        ),
      ],
    );
  }
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
    BodyTissue.skin => Assets.bodyFigure(gender == Gender.female ? 'female' : 'male', side),
    BodyTissue.muscle => Assets.bodyLayer('muscles', side),
    BodyTissue.bone => Assets.bodyLayer('bones', side),
    BodyTissue.joint => Assets.bodyLayer('joints', side),
    BodyTissue.tendon => Assets.bodyLayer('tendons', side),
    BodyTissue.nerve => Assets.bodyLayer('nerves', side),
    BodyTissue.organ => Assets.bodyLayer('organs', side),
  };
}

class _Chip extends StatelessWidget {
  const _Chip(this.s, this.label, this.active, this.onTap);
  final PatientAppState s;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = active;
    final fg = on ? s.accent.d : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? s.accent.bg : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: on ? s.accent.main : AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          softWrap: false,
          style: Typo.meta(ar: s.rtl).copyWith(fontSize: FontSizes.meta, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }
}
