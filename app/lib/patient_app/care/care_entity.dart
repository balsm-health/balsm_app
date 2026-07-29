import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart' show careDirectoryApiProvider;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons/lucide_icons.dart';

/// A bilingual label carried by directory data (names/addresses come from the
/// care-directory API, not the i69n bundle). Resolve with [pick].
typedef L10nText = ({String en, String ar});

String pick(L10nText t, {required bool ar}) => ar ? t.ar : t.en;

/// Kind of nearby health place. Icon/colour/label are presentation config that
/// mirrors the design's `ENTITY_TYPES`. [wire] is the API `type` value.
enum CareEntityType {
  hospital('hospital', LucideIcons.building2, 0xFFD44A3C, 0xFFFAEAE8, (en: 'Hospitals', ar: 'مستشفيات')),
  clinic('clinic', LucideIcons.stethoscope, 0xFF1283FF, 0xFFE4F0FF, (en: 'Clinics', ar: 'عيادات')),
  pharmacy('pharmacy', LucideIcons.pill, 0xFF01C4A2, 0xFFE1F8F1, (en: 'Pharmacies', ar: 'صيدليات')),
  lab('lab', LucideIcons.flaskConical, 0xFF724DD0, 0xFFECE6FA, (en: 'Labs', ar: 'مختبرات')),
  scan('scan', LucideIcons.scanLine, 0xFF02BBB5, 0xFFE2F8F6, (en: 'Scan centers', ar: 'مراكز أشعة')),
  store('store', LucideIcons.shoppingBag, 0xFFD97A20, 0xFFFDF0E0, (en: 'Med. stores', ar: 'أدوات طبية'));

  const CareEntityType(this.wire, this.icon, this._color, this._bg, this.label);

  final String wire;
  final IconData icon;
  final int _color;
  final int _bg;
  final L10nText label;

  Color get color => Color(_color);
  Color get bg => Color(_bg);

  /// Maps the API `type` string to a type; unknown values fall back to clinic.
  static CareEntityType fromWire(String value) =>
      values.firstWhere((t) => t.wire == value, orElse: () => CareEntityType.clinic);
}

/// A nearby health place shown on the care map. Backed by the care-directory
/// API; [position] is a real lat/lng.
class CareEntity {
  const CareEntity({
    required this.id,
    required this.type,
    required this.position,
    required this.name,
    required this.addr,
    required this.hours,
    required this.distance,
    required this.rating,
    required this.phone,
  });

  final String id;
  final CareEntityType type;
  final LatLng position;
  final L10nText name;
  final L10nText addr;
  final String hours;

  /// Human-readable distance (e.g. "0.8 km"); empty when the server omitted it.
  final String distance;

  /// Rating out of 5 (e.g. "4.2"); empty when unrated.
  final String rating;
  final String phone;

  factory CareEntity.fromResponse(CareEntityResponse r) => CareEntity(
        id: r.id,
        type: CareEntityType.fromWire(r.type),
        position: LatLng(r.lat, r.lng),
        name: (en: r.nameEn, ar: r.nameAr),
        addr: (en: r.addressEn, ar: r.addressAr),
        hours: r.hours,
        distance: r.distanceKm == null ? '' : '${r.distanceKm!.toStringAsFixed(1)} km',
        rating: r.rating == null ? '' : r.rating!.toStringAsFixed(1),
        phone: r.phone,
      );
}

/// Home market fallback center (Cairo) when the device location is unavailable
/// or permission is denied — the directory still returns nearby-to-Cairo data.
const kCareFallbackCenter = LatLng(30.0444, 31.2357);

/// The user's current position for directory queries, or [kCareFallbackCenter]
/// when location services/permission are unavailable. Never throws.
final userLatLngProvider = FutureProvider.autoDispose<LatLng>((ref) async {
  try {
    if (await Geolocator.isLocationServiceEnabled()) {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition();
        return LatLng(pos.latitude, pos.longitude);
      }
    }
  } catch (_) {
    // Fall through to the market-center fallback.
  }
  return kCareFallbackCenter;
});

/// Nearby health places from the care-directory API, keyed on the user's
/// position. Distance-sorted server-side; the map/list just render it.
final careDirectoryProvider = FutureProvider.autoDispose<List<CareEntity>>((ref) async {
  final loc = await ref.watch(userLatLngProvider.future);
  final res = await ref.watch(careDirectoryApiProvider).nearby(
        NearbyCareQuery(lat: loc.latitude, lng: loc.longitude),
      );
  return res.map(CareEntity.fromResponse).toList(growable: false);
});
