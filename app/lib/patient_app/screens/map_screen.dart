import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../care/care_entity.dart';
import '../kit.dart';
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
  CareEntityType? _activeType; // null → "all"
  bool _mapView = true; // map | list
  CareEntity? _selected;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Center the map on the user's current position (recenter button).
  Future<void> _recenter() async {
    final loc = await ref.read(userLatLngProvider.future);
    _mapController.move(loc, 14);
  }

  List<CareEntity> _filter(List<CareEntity> all) {
    final q = _query.trim().toLowerCase();
    return all.where((e) {
      final matchType = _activeType == null || e.type == _activeType;
      final matchQ = q.isEmpty ||
          e.name.en.toLowerCase().contains(q) ||
          e.name.ar.contains(_query.trim()) ||
          e.addr.en.toLowerCase().contains(q);
      return matchType && matchQ;
    }).toList();
  }

  void _select(CareEntity e) => setState(() => _selected = _selected?.id == e.id ? null : e);

  void _clearFilters() => setState(() {
        _query = '';
        _searchCtrl.clear();
        _activeType = null;
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
        // App bar — title + list/map toggle.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(children: [
            Expanded(child: Text(s.strings.care.map_nearby, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
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
              _selected = null;
            }),
            style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.md),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: T.ink50,
              hintText: s.strings.care.map_search_ph,
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: T.fg4),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 14, color: T.fg2),
                      onPressed: () => setState(() {
                        _query = '';
                        _searchCtrl.clear();
                        _selected = null;
                      }),
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
            ),
          ),
        ),
        // Filter chips (all + each type).
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _filterChip(null, s.strings.care.map_all, s.accent.main, s.accent.bg),
              ...CareEntityType.values.map((t) => _filterChip(t, pick(t.label, ar: s.rtl), t.color, t.bg)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _mapView ? _mapBody(s, filtered) : _listBody(s, filtered)),
      ]),
    );
  }

  // ── Map view ──────────────────────────────────────────────
  Widget _mapBody(PatientAppState s, List<CareEntity> filtered) {
    if (filtered.isEmpty) return _emptyState(s);
    return Stack(children: [
      Positioned.fill(
          child: _TileMap(controller: _mapController, entities: filtered, selectedId: _selected?.id, onPin: _select)),
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
        child: RoundBtn(icon: LucideIcons.locateFixed, fg: s.accent.main, onTap: _recenter),
      ),
      if (_selected != null) _entityCard(s, _selected!),
    ]);
  }

  // ── List view ─────────────────────────────────────────────
  Widget _listBody(PatientAppState s, List<CareEntity> filtered) {
    if (filtered.isEmpty) return _emptyState(s);
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
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    _metaBit(LucideIcons.navigation, e.distance, s),
                    _metaBit(LucideIcons.clock, e.hours, s),
                    _metaBit(LucideIcons.star, e.rating, s, star: true),
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
                    boxShadow: [BoxShadow(color: Color(0x242B2B25), blurRadius: 32, offset: Offset(0, -4))]),
                padding: EdgeInsets.fromLTRB(18, 10, 18, 24 + MediaQuery.of(context).padding.bottom),
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
                  _detailRow(LucideIcons.mapPin, pick(e.addr, ar: s.rtl), s),
                  _detailRow(LucideIcons.clock, e.hours, s),
                  _detailRow(LucideIcons.navigation, '${e.distance} ${s.strings.care.map_distance}', s),
                  _detailRow(LucideIcons.star, '${e.rating} / 5', s, star: true),
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
  Widget _emptyState(PatientAppState s) => Container(
        color: T.cream50,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.mapPinOff, size: 40, color: T.fg4),
          const SizedBox(height: 12),
          Text(s.strings.care.map_no_results,
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
          const SizedBox(height: 6),
          SizedBox(
            width: 220,
            child: Text(s.strings.care.map_no_res_h,
                textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3)),
          ),
          const SizedBox(height: 16),
          _softButton(icon: LucideIcons.rotateCcw, label: s.strings.care.map_all, onTap: _clearFilters),
        ]),
      );

  Widget _softButton({required IconData icon, required String label, required VoidCallback onTap}) {
    final s = AppScope.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: T.fg2),
          const SizedBox(width: 6),
          Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
        ]),
      ),
    );
  }

  Widget _filterChip(CareEntityType? type, String label, Color color, Color bg) {
    final s = AppScope.of(context);
    final active = _activeType == type;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Pressable(
        onTap: () => setState(() {
          _activeType = type;
          _selected = null;
        }),
        scale: 0.97,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: active ? color : T.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (type != null) ...[Icon(type.icon, size: 13, color: active ? color : T.fg3), const SizedBox(width: 6)],
            Text(label,
                style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: active ? color : T.fg2)),
          ]),
        ),
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
class _TileMap extends StatelessWidget {
  const _TileMap({
    required this.controller,
    required this.entities,
    required this.selectedId,
    required this.onPin,
  });
  final MapController controller;
  final List<CareEntity> entities;
  final String? selectedId;
  final void Function(CareEntity) onPin;

  @override
  Widget build(BuildContext context) {
    final center = entities.isNotEmpty ? entities.first.position : kCareFallbackCenter;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        minZoom: 3,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'health.balsm.app',
        ),
        MarkerLayer(
          markers: entities.map((e) {
            final sel = e.id == selectedId;
            final pinW = sel ? 40.0 : 32.0;
            return Marker(
              point: e.position,
              width: pinW,
              height: pinW + 7,
              alignment: Alignment.topCenter, // tail tip sits on the coordinate
              child: GestureDetector(
                onTap: () => onPin(e),
                child: _Pin(type: e.type, selected: sel, size: pinW),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
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
                color: selected ? type.color.withValues(alpha: 0.53) : const Color(0x382B2B25),
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
