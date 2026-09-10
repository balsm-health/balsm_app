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
