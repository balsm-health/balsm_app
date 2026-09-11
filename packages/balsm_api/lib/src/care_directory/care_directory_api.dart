import 'package:dio/dio.dart' show CancelToken;

import 'requests.dart';
import 'responses.dart';

/// Nearby health-place directory (hospitals, clinics, pharmacies, labs, scan
/// centers, medical stores). Non-PHI, Balsm-owned reference data.
abstract class CareDirectoryApi {
  /// GET /care/entities — places near [query].lat/lng, distance-sorted.
  Future<List<CareEntityResponse>> nearby(NearbyCareQuery query, {CancelToken? cancelToken});

  /// GET /care/pins — the same search projected to map pins. ~99 bytes a pin
  /// against ~340 a full row, so the viewport can be covered rather than a knot
  /// around its centre.
  Future<List<CarePinResponse>> pins(CarePinsQuery query, {CancelToken? cancelToken});

  /// GET /care/entities/{id} — one place, for a tapped pin. [lat]/[lng] are the
  /// viewer's position and only affect the returned distance. Null when the id
  /// is unknown (the server answers 404).
  Future<CareEntityResponse?> byId(String id, {double? lat, double? lng, CancelToken? cancelToken});
}
