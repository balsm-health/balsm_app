/// One nearby health place from `GET /care/entities`. Non-PHI public directory
/// data. Wire format is snake_case; [distanceKm] is computed server-side from
/// the query point.
///
/// Most fields are nullable because no lawful source supplies them for every
/// place: Overture carries ONE name per listing rather than a bilingual pair,
/// has no opening-hours field and no ratings field at all, and omits a phone
/// for roughly 8% of rows. The server sends JSON null rather than an empty
/// string so "absent" stays distinguishable from "empty" — casting these with
/// `as String` throws.
class CareEntityResponse {
  const CareEntityResponse({
    required this.id,
    required this.type,
    this.nameEn,
    this.nameAr,
    this.addressEn,
    this.addressAr,
    required this.lat,
    required this.lng,
    this.hours,
    this.phone,
    this.distanceKm,
    this.rating,
  });

  final String id;
  final String type; // hospital | clinic | pharmacy | lab | scan | store
  final String? nameEn;
  final String? nameAr;
  final String? addressEn;
  final String? addressAr;
  final double lat;
  final double lng;
  final String? hours;
  final String? phone;
  final double? distanceKm;
  final double? rating;

  factory CareEntityResponse.fromJson(Map<String, dynamic> json) => CareEntityResponse(
        id: json['id'] as String,
        type: json['type'] as String,
        nameEn: json['name_en'] as String?,
        nameAr: json['name_ar'] as String?,
        addressEn: json['address_en'] as String?,
        addressAr: json['address_ar'] as String?,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        hours: json['hours'] as String?,
        phone: json['phone'] as String?,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        rating: (json['rating'] as num?)?.toDouble(),
      );
}

/// One map pin from `GET /care/pins`.
///
/// Deliberately minimal — a pin is a dot at a coordinate coloured by type. Name,
/// address, phone and hours come from `GET /care/entities/{id}` when one is
/// tapped, so they are not paid for on every pin in the viewport.
class CarePinResponse {
  const CarePinResponse({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String type;
  final double lat;
  final double lng;

  factory CarePinResponse.fromJson(Map<String, dynamic> json) => CarePinResponse(
        id: json['id'] as String,
        type: json['type'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}

/// One downloadable artifact (basemap or places) from `GET /care/packs`.
/// Versioned independently of its sibling — refreshing places never
/// invalidates a basemap already on disk.
class MapPackArtifactResponse {
  const MapPackArtifactResponse({
    required this.version,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
    this.count,
  });

  /// YYYYMMDD.
  final String version;
  final int sizeBytes;
  final String sha256;
  final String url;

  /// Places only — null for a basemap.
  final int? count;

  factory MapPackArtifactResponse.fromJson(Map<String, dynamic> json) => MapPackArtifactResponse(
        version: json['version'] as String,
        sizeBytes: (json['size_bytes'] as num).toInt(),
        sha256: json['sha256'] as String,
        url: json['url'] as String,
        count: (json['count'] as num?)?.toInt(),
      );
}

/// One governorate's offline pack from `GET /care/packs`. `name` comes back
/// in whatever language the request's `lang` asked for.
class MapPackResponse {
  const MapPackResponse({
    required this.id,
    required this.name,
    required this.bounds,
    required this.basemap,
    required this.places,
  });

  /// Stable governorate slug ("cairo").
  final String id;
  final String name;

  /// [west, south, east, north].
  final List<double> bounds;
  final MapPackArtifactResponse basemap;
  final MapPackArtifactResponse places;

  factory MapPackResponse.fromJson(Map<String, dynamic> json) => MapPackResponse(
        id: json['id'] as String,
        name: json['name'] as String,
        bounds: (json['bounds'] as List).map((e) => (e as num).toDouble()).toList(growable: false),
        basemap: MapPackArtifactResponse.fromJson(json['basemap'] as Map<String, dynamic>),
        places: MapPackArtifactResponse.fromJson(json['places'] as Map<String, dynamic>),
      );
}
