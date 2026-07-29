/// Query for `GET /care/entities` — nearby health places around a point.
/// [lat]/[lng] are required (the user's position); the rest narrow results.
class NearbyCareQuery {
  const NearbyCareQuery({
    required this.lat,
    required this.lng,
    this.radiusKm,
    this.type,
    this.query,
  });

  final double lat;
  final double lng;

  /// Search radius in km (server default applies when null).
  final double? radiusKm;

  /// Entity type filter: hospital | clinic | pharmacy | lab | scan | store.
  final String? type;

  /// Free-text name/address search.
  final String? query;

  Map<String, dynamic> toQueryParameters() => {
        'lat': lat,
        'lng': lng,
        if (radiusKm != null) 'radius_km': radiusKm,
        if (type != null) 'type': type,
        if (query != null && query!.trim().isNotEmpty) 'q': query!.trim(),
      };
}
