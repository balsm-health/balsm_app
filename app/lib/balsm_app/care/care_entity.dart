import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'infrastructure/api_care_directory_data_source.dart';
import 'infrastructure/caching_care_directory_repository.dart';
import 'infrastructure/drift_care_directory_data_source.dart';
import 'ports/care_directory_data_source.dart';
import 'ports/care_directory_repository.dart';

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
  // Mint is the one brand petal no other care type claims, and the 600 shade
  // (not the base #55D77F) because the pin puts a white glyph on this colour
  // when selected — the design system itself sets dark text on base mint.
  // Icon: the DS iconography card is Lucide at stroke 1.75 and has no tooth
  // glyph, nor does lucide_icons 0.257.0; `smile` is the documented stand-in.
  dentist('dentist', LucideIcons.smile, 0xFF3FC366, 0xFFE8F9EE, (en: 'Dentists', ar: 'أطباء أسنان')),
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

  /// Round-trip for the retained-results cache. Every field the UI reads is
  /// carried; a field omitted here would come back empty after a relaunch,
  /// which is worse than not retaining at all.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wire,
        'lat': position.latitude,
        'lng': position.longitude,
        'name_en': name.en,
        'name_ar': name.ar,
        'addr_en': addr.en,
        'addr_ar': addr.ar,
        'hours': hours,
        'distance': distance,
        'rating': rating,
        'phone': phone,
      };

  factory CareEntity.fromJson(Map<String, dynamic> j) => CareEntity(
        id: j['id'] as String,
        type: CareEntityType.fromWire(j['type'] as String),
        position: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        name: (en: j['name_en'] as String? ?? '', ar: j['name_ar'] as String? ?? ''),
        addr: (en: j['addr_en'] as String? ?? '', ar: j['addr_ar'] as String? ?? ''),
        hours: j['hours'] as String? ?? '',
        distance: j['distance'] as String? ?? '',
        rating: j['rating'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
      );
}

/// A map pin: a place reduced to what a dot on the map needs.
///
/// The directory is far too dense to ship whole rows for a whole viewport —
/// ~99 bytes a pin against ~340 a row — so the map plots these and fetches the
/// full [CareEntity] only when one is tapped.
class CarePin {
  const CarePin({required this.id, required this.type, required this.position});

  final String id;
  final CareEntityType type;
  final LatLng position;

  factory CarePin.fromResponse(CarePinResponse r) => CarePin(
        id: r.id,
        type: CareEntityType.fromWire(r.type),
        position: LatLng(r.lat, r.lng),
      );

  /// A pin for an already-loaded place, so the list and the map agree without a
  /// second fetch.
  factory CarePin.of(CareEntity e) => CarePin(id: e.id, type: e.type, position: e.position);

  /// Round-trip for the retained-pins cache.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wire,
        'lat': position.latitude,
        'lng': position.longitude,
      };

  factory CarePin.fromJson(Map<String, dynamic> j) => CarePin(
        id: j['id'] as String,
        type: CareEntityType.fromWire(j['type'] as String),
        position: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
      );
}

/// The area the directory covers.
///
/// The map is constrained to this rather than left free to roam: the directory
/// holds Egyptian places only, so panning beyond it can only ever produce an
/// empty map. A user in Dubai or London would otherwise see a Cairo-looking
/// basemap with no pins and nothing explaining why.
///
/// It is a RECTANGLE, not the border. Egypt's land boundary is not axis-aligned,
/// so any box that covers Rafah in the north-east and Halayib in the south-east
/// necessarily also covers Gaza, part of southern Israel and a sliver of
/// north-west Saudi. That is acceptable for the purpose — the point is to keep a
/// user from wandering to another continent and finding nothing, not to assert a
/// border. The north edge sits at Egypt's northernmost land rather than being
/// rounded up, which keeps Jerusalem and Amman out for free.
final LatLngBounds kCareCoverage = LatLngBounds(
  const LatLng(21.5, 24.5), // south-west, below Halayib
  const LatLng(31.72, 37.0), // north-east: Egypt's northern coast, past Halayib
);

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

/// Cap on places fetched per query, matching the server default.
///
/// Nearest-N, because a wide radius around Cairo matches thousands and fetching
/// those whole is megabytes on mobile data. But too tight a cap becomes the
/// thing users notice: at 200 it bound at ~1.4 km in central Cairo, so a 25 km
/// search drew a dense knot ringed by empty map, and smaller cities with real
/// coverage looked deserted. 500 costs ~166 KB and returns everything most
/// cities have.
const int kCareResultLimit = 500;

/// Cap on map pins per query, matching the server default.
///
/// Three times the row cap for fewer bytes: 1,500 pins measure ~145 KB against
/// ~166 KB for 500 full rows. That is what lets the map cover a viewport rather
/// than a dense knot around its centre.
const int kCarePinLimit = 1500;

/// The server's pin ceiling, used only when a debug build lifts the zoom floor.
const int kCarePinLimitMax = 3000;

/// Radius that covers Egypt end to end, for the same debug case.
const double kCareMaxRadiusKm = 1200;

/// Below this zoom the directory is not queried at all.
///
/// Two caps fight the viewport when zoomed out: the radius is clamped to 50 km
/// while a country-wide view spans ~1,000 km, and nearest-200 then collapses the
/// result into a knot a kilometre or two across. The map ends up showing one
/// cluster over Cairo and an empty Egypt — which reads as "Alexandria and Aswan
/// have no pharmacies" rather than "you are zoomed too far out". Saying nothing
/// is better than saying something false.
///
/// At this zoom a phone viewport is roughly 50 km across, which is the widest
/// the clamped radius can honestly cover.
const double kCareMinQueryZoom = 10;

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
    this.tooZoomedOut = false,
  });

  final String text;
  final Set<CareEntityType> types;
  final LatLng? focus;
  final double radiusKm;

  /// Set when the map is zoomed out past [kCareMinQueryZoom]. The query is
  /// skipped entirely rather than returning a result that misrepresents the
  /// country.
  final bool tooZoomedOut;

  CareSearch copyWith({
    String? text,
    Set<CareEntityType>? types,
    LatLng? focus,
    double? radiusKm,
    bool? tooZoomedOut,
    bool clearFocus = false,
  }) =>
      CareSearch(
        text: text ?? this.text,
        types: types ?? this.types,
        focus: clearFocus ? null : (focus ?? this.focus),
        radiusKm: radiusKm ?? this.radiusKm,
        tooZoomedOut: tooZoomedOut ?? this.tooZoomedOut,
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
/// Decimal places the query centre is rounded to before it is sent.
///
/// Three places is ~110m — far below the radius the directory is searched with,
/// so rounding changes no result a user could notice. It makes small pans reuse
/// the same cache entry, on the device AND in the server's output cache, which
/// varies by query string. Without it every pixel of drift is a fresh key and
/// neither cache ever hits.
const int kCareCenterPrecision = 3;

/// Falls back to the market centre for a position outside the covered area.
///
/// A device abroad — a traveller, a diaspora user, anyone testing from another
/// country — would otherwise query a point the directory has nothing near and
/// get a blank map. Showing Cairo is a truthful answer to "where does this app
/// have data", and the map's own constraint keeps them there.
LatLng _withinCoverage(LatLng c) => kCareCoverage.contains(c) ? c : kCareFallbackCenter;

LatLng _roundCenter(LatLng c) => LatLng(
      double.parse(c.latitude.toStringAsFixed(kCareCenterPrecision)),
      double.parse(c.longitude.toStringAsFixed(kCareCenterPrecision)),
    );

final remoteCareDirectoryDataSourceProvider = Provider<RemoteCareDirectoryDataSource>(
  (ref) => ApiCareDirectoryDataSource(ref.watch(careDirectoryApiProvider)),
);

final careDirectoryRepositoryProvider = Provider<CareDirectoryRepository>(
  (ref) => CachingCareDirectoryRepository(
    remote: ref.watch(remoteCareDirectoryDataSourceProvider),
    local: ref.watch(localCareDirectoryDataSourceProvider),
  ),
);

/// Nearby health places for the current search.
///
/// Deliberately thin: it resolves the query centre, hands off to the
/// repository, and cancels on rebuild. Where the answer comes from — retained
/// locally or fetched — is the repository's decision, so the map screen stays
/// ignorant of caching entirely.
final careDirectoryProvider = FutureProvider.autoDispose<CareResults>((ref) async {
  final search = ref.watch(careSearchProvider);
  // Zoomed too far out to answer honestly — see kCareMinQueryZoom.
  if (search.tooZoomedOut) return const CareResults.fresh([]);

  // "Near me" until the user pans the map, "near what I am looking at" after.
  final focus = search.focus;
  final center = _roundCenter(focus ?? (await ref.watch(userLatLngProvider.future)));

  // Panning fires a query per settled gesture, so a slow response is routinely
  // superseded before it lands. onDispose fires on rebuild as well as teardown.
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);

  return ref.watch(careDirectoryRepositoryProvider).nearby(center, search, cancelToken: cancel);
});

/// Map pins for the current search.
///
/// Separate from [careDirectoryProvider] because the map and the list want
/// different things: the map wants everything in view and needs only
/// coordinates, the list wants names and details for the nearest handful.
final carePinsProvider = FutureProvider.autoDispose<CarePinResults>((ref) async {
  final search = ref.watch(careSearchProvider);

  // Lifting the floor also lifts the radius and pin caps to their ceilings:
  // the point of inspecting coverage at country zoom is to see everything the
  // API will return, not a nearest-N slice of it. It is part of the cache key
  // for the same reason.
  final noFloor = ref.watch(devFlagProvider(kFlagMapNoZoomFloor));
  if (search.tooZoomedOut && !noFloor) return const CarePinResults.fresh([]);

  final focus = search.focus;
  final center = _roundCenter(_withinCoverage(focus ?? (await ref.watch(userLatLngProvider.future))));

  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);

  return ref.watch(careDirectoryRepositoryProvider).pins(center, search, noFloor: noFloor, cancelToken: cancel);
});

/// Full detail for one place, fetched when its pin is tapped.
///
/// Pins carry no name or contact details, so this is where the detail sheet gets
/// them. Null means the place has left the directory since the pin was drawn.
final careEntityProvider = FutureProvider.autoDispose.family<CareEntity?, String>((ref, id) async {
  final search = ref.watch(careSearchProvider);
  final focus = search.focus;
  final LatLng center = focus ?? (await ref.watch(userLatLngProvider.future));

  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);

  return ref.watch(careDirectoryRepositoryProvider).byId(id, center, cancelToken: cancel);
});
