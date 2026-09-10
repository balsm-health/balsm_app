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

/// Resolves a bilingual label, falling back to the other language when the
/// requested one is absent.
///
/// Directory data carries ONE name per place — Overture has no bilingual pair —
/// so an Arabic-only pharmacy must still render in the English UI under its real
/// name. Showing the name we have beats showing a blank row.
String pick(L10nText t, {required bool ar}) {
  final want = ar ? t.ar : t.en;
  if (want.isNotEmpty) return want;
  return ar ? t.en : t.ar;
}

/// Kind of nearby health place. Icon/colour/label are presentation config that
/// mirrors the design's `ENTITY_TYPES`. [wire] is the API `type` value.
enum CareEntityType {
  hospital('hospital', LucideIcons.building2, 0xFFD44A3C, 0xFFFAEAE8, (en: 'Hospitals', ar: 'مستشفيات')),
  clinic('clinic', LucideIcons.stethoscope, 0xFF1283FF, 0xFFE4F0FF, (en: 'Clinics', ar: 'عيادات')),
  dentist('dentist', LucideIcons.smile, 0xFFE0568F, 0xFFFCE9F1, (en: 'Dentists', ar: 'أطباء أسنان')),
  pharmacy('pharmacy', LucideIcons.pill, 0xFF01C4A2, 0xFFE1F8F1, (en: 'Pharmacies', ar: 'صيدليات')),
  lab('lab', LucideIcons.flaskConical, 0xFF8350DE, 0xFFEEE7FB, (en: 'Labs', ar: 'مختبرات')),
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
        name: (en: r.nameEn ?? '', ar: r.nameAr ?? ''),
        addr: (en: r.addressEn ?? '', ar: r.addressAr ?? ''),
        hours: r.hours ?? '',
        distance: r.distanceKm == null ? '' : '${r.distanceKm!.toStringAsFixed(1)} km',
        rating: r.rating == null ? '' : r.rating!.toStringAsFixed(1),
        phone: r.phone ?? '',
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

/// Default search radius. The directory holds ~19k Egyptian places, so an
/// unbounded query would return the entire country distance-sorted — the server
/// applies no default cutoff of its own.
const double kCareDefaultRadiusKm = 10;

/// Cap on places fetched per query. A 10 km radius around central Cairo matches
/// ~3,900 places and 50 km matches ~9,000; fetching those whole is megabytes of
/// JSON on mobile data. Nearest-N keeps the ones a patient could actually reach.
const int kCareResultLimit = 200;

/// What the directory is currently being asked for.
///
/// [focus] is the map's centre once the user pans; until then it is null and the
/// query centres on the device position. That is the difference between "near
/// me" and "near what I am looking at", and both have to work.
class CareSearch {
  const CareSearch({
    this.text = '',
    this.types = const {},
    this.focus,
    this.radiusKm = kCareDefaultRadiusKm,
  });

  final String text;
  final Set<CareEntityType> types;
  final LatLng? focus;
  final double radiusKm;

  CareSearch copyWith({
    String? text,
    Set<CareEntityType>? types,
    LatLng? focus,
    double? radiusKm,
    bool clearFocus = false,
  }) =>
      CareSearch(
        text: text ?? this.text,
        types: types ?? this.types,
        focus: clearFocus ? null : (focus ?? this.focus),
        radiusKm: radiusKm ?? this.radiusKm,
      );

  /// The single type to push server-side. Only sent when exactly one is ticked —
  /// the API filters on one type, and an empty set means "all".
  String? get wireType => types.length == 1 ? types.first.wire : null;
}

final careSearchProvider = StateProvider<CareSearch>((ref) => const CareSearch());

/// Nearby health places from the care-directory API.
///
/// Text and radius are applied SERVER-side: the directory is far too large to
/// ship whole and filter on the device, and the server's Arabic search folds
/// hamza spellings (أشعة/اشعة) that a naive client `contains` would miss.
/// Multi-type selection stays client-side because the endpoint takes one type.
final careDirectoryProvider = FutureProvider.autoDispose<List<CareEntity>>((ref) async {
  final search = ref.watch(careSearchProvider);
  // "Near me" until the user pans the map, "near what I am looking at" after.
  final focus = search.focus;
  final LatLng center = focus ?? (await ref.watch(userLatLngProvider.future));

  final res = await ref.watch(careDirectoryApiProvider).nearby(
        NearbyCareQuery(
          lat: center.latitude,
          lng: center.longitude,
          radiusKm: search.radiusKm,
          type: search.wireType,
          query: search.text.trim().isEmpty ? null : search.text.trim(),
          limit: kCareResultLimit,
        ),
      );
  return res.map(CareEntity.fromResponse).toList(growable: false);
});
