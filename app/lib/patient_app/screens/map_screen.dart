import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';


/// Nearby care (map.jsx MapScreen): search + filters + painted map / list.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String query = '';
  String activeType = 'all';
  String viewMode = 'map';
  HealthEntity? selected;

  final MapController _map = MapController();
  LatLng? _userLoc;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  /// GPS with graceful fallback: request permission, fetch position, recenter.
  /// On denial / disabled / error, stays on the Cairo default.
  Future<void> _resolveLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLoc = loc);
      _map.move(loc, 14);
    } catch (_) {/* keep Cairo fallback */}
  }

  LatLng get _center => _userLoc ?? const LatLng(kCairoLat, kCairoLng);

  List<HealthEntity> get _filtered {
    final q = query.trim().toLowerCase();
    return kHealthEntities.where((e) {
      final matchType = activeType == 'all' || e.type == activeType;
      final matchQ = q.isEmpty ||
          e.name['en']!.toLowerCase().contains(q) ||
          e.name['ar']!.contains(query.trim()) ||
          e.addr['en']!.toLowerCase().contains(q);
      return matchType && matchQ;
    }).toList();
  }

  void _select(HealthEntity e) {
    setState(() => selected = e);
    showEntityCard(context, e).then((_) { if (mounted) setState(() => selected = null); });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final filtered = _filtered;
    return Column(children: [
      const PadTop(),
      // App bar + view toggle
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: Row(children: [
          Expanded(child: Text(s.t('map_nearby'), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
          GestureDetector(
            onTap: () => setState(() { viewMode = viewMode == 'map' ? 'list' : 'map'; selected = null; }),
            child: Container(
              height: 40, padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rMd)),
              child: Row(children: [
                Icon(viewMode == 'map' ? LucideIcons.list : LucideIcons.map, size: 16, color: s.accent.d),
                const SizedBox(width: 8),
                Text(viewMode == 'map' ? s.t('map_list') : s.t('map_map'),
                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d)),
              ]),
            ),
          ),
        ]),
      ),
      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: _SearchField(value: query, onChanged: (v) => setState(() { query = v; selected = null; }), accent: s.accent, hint: s.t('map_search_ph'), ar: s.rtl),
      ),
      // Filter chips
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            _FilterChip(label: s.t('map_all'), active: activeType == 'all', color: s.accent.main, bg: s.accent.bg, ar: s.rtl, onTap: () => setState(() { activeType = 'all'; selected = null; })),
            for (final e in kEntityTypes.entries)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _FilterChip(label: e.value.label.of(s.lang), icon: e.value.icon, active: activeType == e.key, color: e.value.color, bg: e.value.bg, ar: s.rtl, onTap: () => setState(() { activeType = e.key; selected = null; })),
              ),
          ],
        ),
      ),
      const SizedBox(height: 2),
      Expanded(child: LayoutBuilder(builder: (context, c) {
        // Tablet/desktop: list + map side by side (master/detail). Phone keeps
        // the map/list toggle.
        if (c.maxWidth >= Bp.md) {
          return Row(children: [
            SizedBox(width: 360, child: _listView(s, filtered)),
            const VerticalDivider(width: 1, color: T.border),
            Expanded(child: _mapView(s, filtered)),
          ]);
        }
        return viewMode == 'map' ? _mapView(s, filtered) : _listView(s, filtered);
      })),
    ]);
  }

  Widget _mapView(PatientAppState s, List<HealthEntity> filtered) {
    return Stack(children: [
      Positioned.fill(
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 13,
            minZoom: 10,
            maxZoom: 18,
            onTap: (_, __) { if (selected != null) setState(() => selected = null); },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'health.balsm.app',
              tileProvider: NetworkTileProvider(),
            ),
            MarkerLayer(markers: [
              if (_userLoc != null)
                Marker(
                  point: _userLoc!, width: 22, height: 22,
                  child: const _UserDot(),
                ),
              for (final e in filtered)
                Marker(
                  point: LatLng(e.lat, e.lng),
                  width: 44, height: 52,
                  alignment: Alignment.topCenter,
                  child: _MapPin(entity: e, selected: selected?.id == e.id, onTap: () => _select(e)),
                ),
            ]),
          ],
        ),
      ),
      // OSM attribution (required by tile usage policy)
      Positioned(
        bottom: 2, left: 4,
        child: Container(
          color: const Color(0xB3FFFFFF),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('© OpenStreetMap', style: Typo.meta(ar: s.rtl).copyWith(fontSize: 9, color: T.fg3)),
        ),
      ),
      Positioned(
        top: 12, right: s.rtl ? null : 14, left: s.rtl ? 14 : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xF0FFFFFF), borderRadius: BorderRadius.circular(T.rPill), boxShadow: T.shadowSm),
          child: Text('${filtered.length} ${s.t('map_found')}', style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        ),
      ),
      Positioned(
        bottom: 20, right: s.rtl ? null : 14, left: s.rtl ? 14 : null,
        child: Container(
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: T.shadowMd),
          child: RoundBtn(
            icon: LucideIcons.locateFixed, bg: Colors.white, fg: s.accent.main,
            onTap: () => _map.move(_center, _userLoc != null ? 14 : 13),
          ),
        ),
      ),
    ]);
  }

  Widget _listView(PatientAppState s, List<HealthEntity> filtered) {
    if (filtered.isEmpty) {
      return ListView(children: [Padding(padding: const EdgeInsets.all(20), child: _emptyCard(s))]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        for (final e in filtered) Padding(padding: const EdgeInsets.only(bottom: 10), child: _EntityListCard(entity: e, selected: selected?.id == e.id, onTap: () => _select(e))),
      ],
    );
  }

  Widget _emptyCard(PatientAppState s) => PCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(children: [
          const Icon(LucideIcons.mapPin, size: 32, color: T.fg4),
          const SizedBox(height: 12),
          Text(s.t('map_no_results'), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        ]),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.value, required this.onChanged, required this.accent, required this.hint, required this.ar});
  final String value;
  final ValueChanged<String> onChanged;
  final Accent accent;
  final String hint;
  final bool ar;
  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        style: Typo.body(ar: ar).copyWith(fontSize: FS.lg, color: T.fg1),
        decoration: InputDecoration(
          hintText: hint, hintStyle: Typo.body(ar: ar).copyWith(color: T.fg4),
          prefixIcon: const Icon(LucideIcons.search, size: 18, color: T.fg4),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: accent.main, width: 1.5)),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.icon, required this.active, required this.color, required this.bg, required this.ar, required this.onTap});
  final String label;
  final IconData? icon;
  final bool active;
  final Color color;
  final Color bg;
  final bool ar;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: active ? color : T.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 13, color: active ? color : T.fg2), const SizedBox(width: 6)],
            Text(label, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: active ? color : T.fg2)),
          ]),
        ),
      );
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.entity, required this.selected, required this.onTap});
  final HealthEntity entity;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cfg = kEntityTypes[entity.type]!;
    final w = selected ? 40.0 : 32.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: w, height: w, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? cfg.color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: cfg.color, width: 2.5),
            boxShadow: [BoxShadow(color: selected ? cfg.color.withValues(alpha: 0.5) : const Color(0x382B2B25), blurRadius: selected ? 10 : 5, offset: const Offset(0, 3))],
          ),
          child: Icon(cfg.icon, size: selected ? 18 : 15, color: selected ? Colors.white : cfg.color),
        ),
        CustomPaint(size: const Size(10, 7), painter: _TrianglePainter(cfg.color)),
      ]),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width / 2, size.height)..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// Pulsing-style "you are here" dot.
class _UserDot extends StatelessWidget {
  const _UserDot();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0x331283FF), shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: T.petalBlue, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      );
}

class _EntityListCard extends StatelessWidget {
  const _EntityListCard({required this.entity, required this.selected, required this.onTap});
  final HealthEntity entity;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cfg = kEntityTypes[entity.type]!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? cfg.bg : Colors.white,
          borderRadius: BorderRadius.circular(T.rLg),
          border: Border.all(color: selected ? cfg.color : T.border, width: 1.5),
          boxShadow: selected ? null : T.shadowSm,
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconSquare(cfg.icon, bg: cfg.bg, fg: cfg.color, size: 46, iconSize: 22),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entity.name.of(s.lang), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            Text(entity.addr.of(s.lang), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            const SizedBox(height: 8),
            Wrap(spacing: 14, children: [
              _meta(LucideIcons.navigation, entity.distance, s),
              _meta(LucideIcons.clock, entity.hours, s),
              _meta(LucideIcons.star, entity.rating, s, star: true),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _meta(IconData icon, String text, PatientAppState s, {bool star = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: star ? T.sun500 : T.fg4),
        const SizedBox(width: 4),
        Text(text, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: star ? FontWeight.w700 : FontWeight.w400, color: star ? T.fg2 : T.fg3)),
      ]);
}

// ── Entity detail bottom card ────────────────────────────────
Future<void> showEntityCard(BuildContext context, HealthEntity e) {
  final s = AppScope.of(context);
  final cfg = kEntityTypes[e.type]!;
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x002B2B25),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
            boxShadow: [BoxShadow(color: Color(0x242B2B25), blurRadius: 32, offset: Offset(0, -4))]),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconSquare(cfg.icon, bg: cfg.bg, fg: cfg.color, size: 50, iconSize: 24),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.name.of(s.lang), style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: cfg.bg, borderRadius: BorderRadius.circular(T.rPill)),
                    child: Text(cfg.label.of(s.lang), style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: cfg.color)),
                  ),
                ])),
                RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 16, onTap: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 14),
              _detailRow(s, LucideIcons.mapPin, e.addr.of(s.lang)),
              _detailRow(s, LucideIcons.clock, e.hours),
              _detailRow(s, LucideIcons.navigation, '${e.distance} ${s.t('map_distance')}'),
              _detailRow(s, LucideIcons.star, '${e.rating} / 5', star: true),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: PButton(s.t('map_call'), icon: LucideIcons.phone, variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: () => Navigator.pop(ctx))),
                const SizedBox(width: 10),
                Expanded(child: PButton(s.t('map_directions'), icon: LucideIcons.navigation, variant: BtnVariant.secondary, large: true, block: true, ar: s.rtl, onTap: () => Navigator.pop(ctx))),
              ]),
            ]),
          ),
        ]),
      ),
    ),
  );
}

Widget _detailRow(PatientAppState s, IconData icon, String text, {bool star = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Icon(icon, size: 16, color: star ? T.sun500 : T.fg4),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: star ? FontWeight.w600 : FontWeight.w400, color: T.fg2))),
      ]),
    );

