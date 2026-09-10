import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fluster/fluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../care/care_clustering.dart';
import '../care/care_entity.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';

/// Nearby health entities (map.jsx `MapScreen`): a stylized Cairo map with
/// entity pins, a searchable/filterable list, and a per-entity detail card.
/// Data comes from [careDirectoryProvider] (a placeholder until the
/// care-directory backend exists); no PHI is involved.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _searchCtrl = TextEditingController();
  final _mapController = MapController();
  String _query = '';

  /// Types the patient is filtering to. Empty means "All" — the same result
  /// as every type ticked, so clearing the last one falls back to all rather
  /// than stranding the map with nothing to plot.
  final Set<CareEntityType> _activeTypes = {};
  bool _mapView = true; // map | list
  CareEntity? _selected;

  /// Debounce for anything that triggers a network query. Typing and panning
  /// both fire continuously; without this every keystroke and every frame of a
  /// drag would hit the directory.
  Timer? _debounce;
  static const _debounceDelay = Duration(milliseconds: 400);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Pushes the current UI state into the query the directory provider watches.
  /// [immediate] skips the debounce for discrete actions — ticking a type, or
  /// clearing filters — where waiting would feel broken.
  void _pushSearch({bool immediate = false, LatLng? focus, double? radiusKm}) {
    void apply() {
      if (!mounted) return;
      final notifier = ref.read(careSearchProvider.notifier);
      notifier.state = notifier.state.copyWith(
        text: _query,
        types: Set<CareEntityType>.from(_activeTypes),
        focus: focus,
        radiusKm: radiusKm,
      );
    }

    _debounce?.cancel();
    if (immediate) {
      apply();
    } else {
      _debounce = Timer(_debounceDelay, apply);
    }
  }

  /// Re-queries around wherever the user has panned to.
  ///
  /// "Nearby" has to mean the area being looked at, not only the device's own
  /// position — someone planning a trip across Cairo needs results where they
  /// are heading. The radius follows the visible bounds so zooming out widens
  /// the search instead of showing a sparse patch in the middle.
  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _pushSearch(focus: camera.center, radiusKm: _radiusForBounds(camera));
  }

  static double _radiusForBounds(MapCamera camera) {
    final bounds = camera.visibleBounds;
    final km = const Distance().as(LengthUnit.Kilometer, bounds.center, bounds.northEast);
    // Floor keeps a deep zoom from querying a radius so small it returns
    // nothing; the cap keeps a zoomed-out view from asking for the whole country.
    return km.clamp(1.0, 50.0);
  }

  /// Center the map on the user's current position (recenter button).
  Future<void> _recenter() async {
    final loc = await ref.read(userLatLngProvider.future);
    _mapController.move(loc, 14);
  }

  List<CareEntity> _filter(List<CareEntity> all) => filterCareEntities(all, query: _query, types: _activeTypes);

  void _select(CareEntity e) => setState(() => _selected = _selected?.id == e.id ? null : e);

  void _clearFilters() => setState(() {
        _query = '';
        _searchCtrl.clear();
        _activeTypes.clear();
        _pushSearch(immediate: true);
      });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final entities = ref.watch(careDirectoryProvider).valueOrNull ?? const <CareEntity>[];
    final filtered = _filter(entities);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        const PadTop(),
        // Controls (title, search, filters) stay text-width even on tablet/desktop —
        // only the map/list body below goes edge-to-edge.
        ContentColumn(
          maxWidth: 720,
          child: Column(children: [
            // App bar — title + list/map toggle.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(children: [
                Expanded(
                    child: Text(s.strings.care.map_nearby, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
                _softButton(
                  icon: _mapView ? LucideIcons.list : LucideIcons.map,
                  label: _mapView ? s.strings.care.map_list : s.strings.care.map_map,
                  onTap: () => setState(() {
                    _mapView = !_mapView;
                    _selected = null;
                  }),
                ),
              ]),
            ),
            // Search.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() {
                  _query = v;
                  _pushSearch();
                  _selected = null;
                }),
                style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.lg, color: T.fg1),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  hintText: s.strings.care.map_search_ph,
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: T.fg4),
                  suffixIcon: _query.isEmpty
                      ? null
                      : Center(
                          widthFactor: 1,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _query = '';
                              _searchCtrl.clear();
                              _pushSearch(immediate: true);
                              _selected = null;
                            }),
                            child: Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              margin: const EdgeInsetsDirectional.only(end: 10),
                              decoration: const BoxDecoration(color: T.ink200, shape: BoxShape.circle),
                              child: const Icon(LucideIcons.x, size: 11, color: T.fg2),
                            ),
                          ),
                        ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(T.rMd),
                      borderSide: const BorderSide(color: T.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(T.rMd),
                      borderSide: BorderSide(color: s.accent.main, width: 1.5)),
                ),
              ),
            ),
            // Category filter — a dropdown selector (the design replaced the
            // scrolling chip row with one, matching the Trends metrics
            // pattern): a single trigger showing the active category, opening
            // a checklist-style panel that closes on an outside tap.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _TypeDropdown(
                  active: _activeTypes,
                  onToggle: (t) => setState(() {
                    // Null is the "All" row: clear the set rather than tick
                    // every box, so "All" and all-ticked stay one state.
                    if (t == null) {
                      _activeTypes.clear();
                    } else if (!_activeTypes.remove(t)) {
                      _activeTypes.add(t);
                    }
                    _selected = null;
                    // A single ticked type is pushed server-side; several stay
                    // client-side because the endpoint filters on one type.
                    _pushSearch(immediate: true);
                  }),
                ),
              ),
            ),
          ]),
        ),
        // The map itself stays full-bleed (real map UX never letterboxes); only
        // the list view — a column of cards — gets the same width cap as the
        // controls above.
        Expanded(
          child: _mapView
              ? _mapBody(s, filtered, ref.watch(userLatLngProvider).valueOrNull)
              : ContentColumn(maxWidth: 720, child: _listBody(s, filtered)),
        ),
      ]),
    );
  }

  // ── Map view ──────────────────────────────────────────────
  Widget _mapBody(PatientAppState s, List<CareEntity> filtered, LatLng? userLocation) {
    // The map stays mounted even with no results. Replacing it with an empty
    // panel strands the user: _TileMap is what reports panning, so with it gone
    // they cannot move to an area that HAS results — the only way out is
    // clearing the search. Now the message overlays a live map instead.
    return Stack(children: [
      Positioned.fill(
          child: _TileMap(
              controller: _mapController,
              entities: filtered,
              selectedId: _selected?.id,
              onPin: _select,
              onMoved: _onMapMoved,
              userLocation: userLocation)),
      if (filtered.isEmpty) Positioned.fill(child: Center(child: _emptyOverlay(s))),
      // Count badge.
      PositionedDirectional(
        top: 12,
        end: 14,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(
              color: const Color(0xF0FFFFFF), borderRadius: BorderRadius.circular(T.rPill), boxShadow: T.shadowSm),
          child: Text('${filtered.length} ${s.strings.care.map_found}',
              style: Typo.num(size: FS.xs, weight: FontWeight.w700, color: T.fg2)),
        ),
      ),
      // Recenter — decorative (real geolocation lands with the backend).
      PositionedDirectional(
        bottom: _selected != null ? 220 : 20,
        end: 14,
        child: RoundBtn(icon: LucideIcons.locateFixed, bg: Colors.white, fg: s.accent.main, onTap: _recenter),
      ),
      if (_selected != null) _entityCard(s, _selected!),
    ]);
  }

  // ── List view ─────────────────────────────────────────────
  Widget _listBody(PatientAppState s, List<CareEntity> filtered) {
    if (filtered.isEmpty) return _emptyList(s);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final e = filtered[i];
        final active = _selected?.id == e.id;
        return Pressable(
          onTap: () => _select(e),
          scale: 0.99,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: active ? e.type.bg : Colors.white,
              borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(color: active ? e.type.color : T.border, width: 1.5),
              boxShadow: T.shadowSm,
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _typeIcon(e.type, 46),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pick(e.name, ar: s.rtl),
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                  const SizedBox(height: 2),
                  Text(pick(e.addr, ar: s.rtl), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                  const SizedBox(height: 8),
                  // Directory data has real gaps: no source supplies opening
                  // hours or ratings, and ~8% of places have no phone. Omit the
                  // row rather than rendering an empty icon or a bare "/ 5".
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    if (e.distance.isNotEmpty) _metaBit(LucideIcons.navigation, e.distance, s),
                    if (e.hours.isNotEmpty) _metaBit(LucideIcons.clock, e.hours, s),
                    if (e.rating.isNotEmpty) _metaBit(LucideIcons.star, e.rating, s, star: true),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  // ── Entity detail card (bottom sheet look) ────────────────
  Widget _entityCard(PatientAppState s, CareEntity e) => Positioned.fill(
        child: Stack(children: [
          GestureDetector(onTap: () => setState(() => _selected = null), child: const SizedBox.expand()),
          Align(
            alignment: Alignment.bottomCenter,
            child: RiseIn(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
                    boxShadow: [BoxShadow(color: Color(0x2414202B), blurRadius: 32, offset: Offset(0, -4))]),
                padding: EdgeInsets.fromLTRB(18, 10, 18, 24 + MediaQuery.paddingOf(context).bottom),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(
                      child: Container(
                          width: 38,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999)))),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _typeIcon(e.type, 50),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(pick(e.name, ar: s.rtl),
                            style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: e.type.bg, borderRadius: BorderRadius.circular(T.rPill)),
                          child: Text(pick(e.type.label, ar: s.rtl),
                              style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: e.type.color)),
                        ),
                      ]),
                    ),
                    RoundBtn(
                        icon: LucideIcons.x, ghost: true, iconSize: 16, onTap: () => setState(() => _selected = null)),
                  ]),
                  const SizedBox(height: 14),
                  if (pick(e.addr, ar: s.rtl).isNotEmpty) _detailRow(LucideIcons.mapPin, pick(e.addr, ar: s.rtl), s),
                  if (e.hours.isNotEmpty) _detailRow(LucideIcons.clock, e.hours, s),
                  if (e.distance.isNotEmpty)
                    _detailRow(LucideIcons.navigation, '${e.distance} ${s.strings.care.map_distance}', s),
                  if (e.rating.isNotEmpty) _detailRow(LucideIcons.star, '${e.rating} / 5', s, star: true),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      child: PButton(s.strings.care.map_call,
                          icon: LucideIcons.phone,
                          variant: BtnVariant.primary,
                          large: true,
                          block: true,
                          accent: s.accent,
                          ar: s.rtl,
                          onTap: () => _launch('tel:${e.phone.replaceAll(' ', '')}')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PButton(s.strings.care.map_directions,
                          icon: LucideIcons.navigation,
                          variant: BtnVariant.secondary,
                          large: true,
                          block: true,
                          ar: s.rtl,
                          onTap: () => _launch(
                              'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(e.name.en)}')),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
      );

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Small pieces ──────────────────────────────────────────
  /// Map view with nothing to plot — `map-x` over the cream stage, with the
  /// clear-search action (map.jsx). The list view uses a different empty
  /// state; the two are deliberately not shared.
  /// No-results card, floated over a still-live map.
  ///
  /// Only the card itself takes hits — the map around it stays pannable, which
  /// is the point: with server-side search an empty result is common, and the
  /// user needs to be able to move somewhere that HAS results without first
  /// clearing what they typed.
  Widget _emptyOverlay(PatientAppState s) => Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xF7FFFFFF),
          borderRadius: BorderRadius.circular(T.rLg),
          boxShadow: T.shadowSm,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.mapPinOff, size: 40, color: T.fg4),
          const SizedBox(height: 12),
          Text(s.strings.care.map_no_results,
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
          const SizedBox(height: 6),
          SizedBox(
            width: 200,
            child: Text(s.strings.care.map_no_res_h,
                textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3)),
          ),
          const SizedBox(height: 16),
          _softButton(label: s.strings.care.map_clear, onTap: _clearFilters),
        ]),
      );

  /// List view with nothing to show — a plain card, no action (map.jsx).
  Widget _emptyList(PatientAppState s) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          PCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(children: [
              const Icon(LucideIcons.mapPinOff, size: 32, color: T.fg4),
              const SizedBox(height: 12),
              Text(s.strings.care.map_no_results,
                  textAlign: TextAlign.center,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
              const SizedBox(height: 6),
              Text(s.strings.care.map_no_res_h,
                  textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
        ],
      );

  Widget _softButton({required String label, required VoidCallback onTap, IconData? icon}) {
    final s = AppScope.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rMd)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: s.accent.d),
            const SizedBox(width: 9),
          ],
          Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d)),
        ]),
      ),
    );
  }

  Widget _typeIcon(CareEntityType type, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: type.bg, borderRadius: BorderRadius.circular(T.rMd)),
        child: Icon(type.icon, size: size * 0.47, color: type.color),
      );

  Widget _metaBit(IconData icon, String text, PatientAppState s, {bool star = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: star ? T.sun500 : T.fg4),
          const SizedBox(width: 4),
          Text(text,
              style:
                  Typo.num(size: FS.xs, weight: star ? FontWeight.w700 : FontWeight.w400, color: star ? T.fg2 : T.fg3)),
        ],
      );

  Widget _detailRow(IconData icon, String text, PatientAppState s, {bool star = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Icon(icon, size: 16, color: star ? T.sun500 : T.fg4),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: Typo.bodySm(ar: s.rtl)
                      .copyWith(color: T.fg2, fontWeight: star ? FontWeight.w600 : FontWeight.w400))),
        ]),
      );
}

/// Real OpenStreetMap tile map with a marker per entity. Centers on the first
/// result (falls back to the market center); pins anchor at their lat/lng.
class _TileMap extends StatefulWidget {
  const _TileMap({
    required this.controller,
    required this.entities,
    required this.selectedId,
    required this.onPin,
    required this.onMoved,
    this.userLocation,
  });
  final MapController controller;
  final List<CareEntity> entities;
  final String? selectedId;
  final void Function(CareEntity) onPin;

  /// Fired when the user pans or zooms, so the directory can be re-queried
  /// around wherever they are now looking.
  final void Function(MapCamera camera, bool hasGesture) onMoved;

  /// "You are here" — null until the location resolves.
  final LatLng? userLocation;

  @override
  State<_TileMap> createState() => _TileMapState();
}

class _TileMapState extends State<_TileMap> {
  late Fluster<CarePoint> _clusters;
  MapCamera? _camera;

  @override
  void initState() {
    super.initState();
    _clusters = buildCareClusters(widget.entities);
  }

  @override
  void didUpdateWidget(_TileMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Indexing is the expensive half; only redo it when the places change.
    if (!identical(oldWidget.entities, widget.entities)) {
      _clusters = buildCareClusters(widget.entities);
    }
  }

  void _handleMove(MapCamera camera, bool hasGesture) {
    setState(() => _camera = camera);
    widget.onMoved(camera, hasGesture);
  }

  List<CarePoint> get _visiblePoints {
    final camera = _camera;
    if (camera == null) {
      // Before the first frame reports a camera, cluster at the initial zoom
      // over everything rather than drawing 19k raw pins.
      return careClustersFor(_clusters, const LatLng(-90, -180), const LatLng(90, 180), 13);
    }
    final bounds = camera.visibleBounds;
    return careClustersFor(_clusters, bounds.southWest, bounds.northEast, camera.zoom);
  }

  /// Zooming into a cluster is how a user drills down; tapping one should feel
  /// like opening it, not like a dead pin.
  void _expand(CarePoint cluster) {
    final target = (_camera?.zoom ?? 13) + 2;
    widget.controller.move(cluster.position, target.clamp(3, 18));
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.entities.isNotEmpty ? widget.entities.first.position : kCareFallbackCenter;
    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        minZoom: 3,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onPositionChanged: (camera, hasGesture) => _handleMove(camera, hasGesture),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'health.balsm.app',
        ),
        // ODbL requires attributing the tile source; place data is Overture's,
        // under CDLA-Permissive. Both notices are owed wherever the map renders.
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
            TextSourceAttribution('Overture Maps Foundation'),
          ],
        ),
        // Own-position dot sits under the entity pins, as in the design.
        if (widget.userLocation != null)
          MarkerLayer(markers: [
            Marker(
              point: widget.userLocation!,
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: const _UserDot(),
            ),
          ]),
        MarkerLayer(
          markers: _visiblePoints.map((point) {
            if (point.isCluster == true) {
              return Marker(
                point: point.position,
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => _expand(point),
                  child: _ClusterPin(count: point.count),
                ),
              );
            }

            final e = point.entity!;
            final sel = e.id == widget.selectedId;
            final pinW = sel ? 40.0 : 32.0;
            return Marker(
              point: e.position,
              width: pinW,
              height: pinW + 7,
              alignment: Alignment.topCenter, // tail tip sits on the coordinate
              child: GestureDetector(
                onTap: () => widget.onPin(e),
                child: _Pin(type: e.type, selected: sel, size: pinW),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// A cluster marker: one dot standing in for several places, labelled with how
/// many. Tapping zooms in rather than opening anything — the count is a promise
/// that there is more underneath.
class _ClusterPin extends StatelessWidget {
  const _ClusterPin({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    // Large clusters read as denser; the step keeps the scale legible without
    // letting a 5,000-place cluster dwarf the map.
    final size = count >= 1000 ? 48.0 : (count >= 100 ? 44.0 : 38.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: T.petalBlue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: T.shadowSm,
      ),
      alignment: Alignment.center,
      child: Text(
        count >= 1000 ? '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}k' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          height: 1,
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0x1A1283FF), shape: BoxShape.circle),
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0x381283FF), shape: BoxShape.circle),
            child: Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const DecoratedBox(
                decoration: BoxDecoration(color: T.petalBlue, shape: BoxShape.circle),
                child: SizedBox(width: 12, height: 12),
              ),
            ),
          ),
        ),
      );
}

class _Pin extends StatelessWidget {
  const _Pin({required this.type, required this.selected, required this.size});
  final CareEntityType type;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: selected ? type.color : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: type.color, width: 2.5),
          boxShadow: [
            BoxShadow(
                color: selected ? type.color.withValues(alpha: 0.53) : const Color(0x3814202B),
                blurRadius: selected ? 10 : 5,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(type.icon, size: selected ? 18 : 15, color: selected ? Colors.white : type.color),
      ),
      // Downward tail.
      CustomPaint(size: const Size(10, 7), painter: _TailPainter(type.color)),
    ]);
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

/// Category filter dropdown — trigger + checklist panel, replacing the old
/// horizontal chip row. Mirrors the Trends metrics selector.
/// Nearby-care search + type filter.
///
/// An empty [types] means "All": the type dropdown multi-selects, and treating
/// "nothing ticked" as "everything" keeps All and all-ticked a single state,
/// so unticking the last type can never leave the map with nothing to plot.
List<CareEntity> filterCareEntities(
  List<CareEntity> all, {
  required String query,
  required Set<CareEntityType> types,
}) {
  final raw = query.trim();
  final q = raw.toLowerCase();
  return all.where((e) {
    final matchType = types.isEmpty || types.contains(e.type);
    final matchQ = q.isEmpty ||
        e.name.en.toLowerCase().contains(q) ||
        e.name.ar.contains(raw) ||
        e.addr.en.toLowerCase().contains(q);
    return matchType && matchQ;
  }).toList();
}

class _TypeDropdown extends StatelessWidget {
  const _TypeDropdown({required this.active, required this.onToggle});

  /// Empty = "All". Multi-select is a product change from map.jsx, which
  /// single-selects; the checkbox chrome mirrors the Trends metrics dropdown
  /// so the app's two filter menus read the same.
  final Set<CareEntityType> active;

  /// Null toggles the "All" row.
  final ValueChanged<CareEntityType?> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = active.isEmpty;
    // One type reads better as its own name than as "1 types".
    final only = active.length == 1 ? active.first : null;
    final label = all
        ? s.strings.care.map_all
        : only != null
            ? pick(only.label, ar: s.rtl)
            : s.strings.care.map_n_types('${active.length}');

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: const WidgetStatePropertyAll(Color(0x2414202B)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        minimumSize: const WidgetStatePropertyAll(Size(210, 0)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(T.rLg),
          side: const BorderSide(color: T.border),
        )),
      ),
      builder: (context, controller, _) => Pressable(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        scale: 0.99,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (only != null) ...[
              Icon(only.icon, size: 13, color: only.color),
              const SizedBox(width: 8),
            ],
            Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: controller.isOpen ? 0.5 : 0,
              duration: Motion.base,
              curve: Motion.easeOut,
              child: const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
            ),
          ]),
        ),
      ),
      menuChildren: [
        _row(context, null, s.strings.care.map_all, s.accent.main, LucideIcons.layoutGrid, checked: all),
        ...CareEntityType.values.map((t) => _row(
              context,
              t,
              pick(t.label, ar: s.rtl),
              t.color,
              t.icon,
              checked: active.contains(t),
            )),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    CareEntityType? type,
    String label,
    Color color,
    IconData icon, {
    required bool checked,
  }) {
    final s = AppScope.of(context);
    return MenuItemButton(
      // Ticking a type must not dismiss the menu — the point is picking several.
      closeOnActivate: false,
      onPressed: () => onToggle(type),
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
        minimumSize: const WidgetStatePropertyAll(Size(198, 0)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rSm))),
      ),
      child: Row(children: [
        // 18px checkbox: accent fill + white tick when on, else outline.
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: checked ? s.accent.main : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: checked ? null : Border.all(color: T.borderStrong, width: 1.5),
          ),
          child: checked ? const Icon(LucideIcons.check, size: 12, color: Colors.white) : null,
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: Typo.bodySm(ar: s.rtl)
                  .copyWith(fontWeight: checked ? FontWeight.w700 : FontWeight.w500, color: T.fg1)),
        ),
      ]),
    );
  }
}
